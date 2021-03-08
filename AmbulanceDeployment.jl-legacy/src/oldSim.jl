#=
Author : Ng Yeesian
Modified : Guy Farmer / Zander Tedjo / Will Worthington
defines and runs the simulation engine for ems dispatch and deployment
=#

include("dispatch/closestdispatch.jl")
include("redeployment/assignment.jl")
include("model.jl")
#include("problem.jl")
Pkg.add("Query")
Pkg.add("CPLEX")
using Query, DataStructures, Dates

mutable struct EMSEngine{T}
    eventlog::DataFrame
    eventqueue::PriorityQueue{T,Int,Base.Order.ForwardOrdering}
    guiArray::Array{Any, 1}
    # num_ambulance_update::Array{Any, 1}
end

struct gui_event
    #call made / call responded / ambulance arrived
    event_type::String
    #neighborhood where call is made from
    neighborhood_id::Int
    # station where call is made from
    deployment_id::Int
    # id of the event generated
    event_id::Int
    ambulance_id::Int
    arrival_time::Int
    remaining_amb::Int
    # current timestamp of event
    timestamp::DateTime

end

function EMSEngine(problem::DispatchProblem)
    ncalls = nrow(problem.emergency_calls)
    eventlog = DataFrame(
        id = 1:ncalls,
        dispatch_from = zeros(Int, ncalls),
        waittime = fill(0.0, ncalls),
        responsetime = fill(Inf, ncalls),
        scenetime = fill(Inf, ncalls),
        conveytime = fill(Inf, ncalls),
        returntime = fill(Inf, ncalls),
        return_to = zeros(Int, ncalls),
        return_type = fill(:station, ncalls),
        hospital = zeros(Int, ncalls),
        ambulance = zeros(Int, ncalls)
    )
    eventqueue = PriorityQueue{Tuple{Symbol,Int,Int,Int},Int}()
    guiArray = Any[]
    for i in 1:nrow(problem.emergency_calls)
        t = problem.emergency_calls[i, :arrival_seconds]
        enqueue!(eventqueue, (:call, i, t, problem.emergency_calls[i, :neighborhood]), t)
    end
    EMSEngine{Tuple{Symbol,Int,Int,Int}}(eventlog, eventqueue,guiArray)
end

function cal_event!(
        ems::EMSEngine,
        problem::DispatchProblem,
        dispatch::DispatchModel,
        redeploy::RedeployModel,
        id::Int, # the id of the emergency call
        t::Int, # the time of the emergency call
        nbhd::Int; # the neighborhood the call is from
        verbose::Bool = false
    )

    #check if there is an ambulance within the coverage matrix
    if sum(problem.deployment[problem.coverage[nbhd,:]]) == 0
        @assert false "$id: no ambulance reachable for call at $nbhd"
    #check if one of the ambulances within the coverage is available
    elseif sum(problem.available[problem.coverage[nbhd,:]]) > 0
        i = available_for(dispatch, id, problem)
        @assert i > 0 "$id: dispatch from $i to nbhd $nbhd" # assume valid i (enforced by <if> condition)
        update_ambulances!(dispatch, i, -1)
        ems.eventlog[id, :dispatch_from] = i
        @assert problem.available[i] > 0
        problem.available[i] -= 1

        travel_time = ceil(Int, 60*2*problem.emergency_calls[id, Symbol("stn$(i)_min")])
        @assert travel_time >= 0
        ems.eventlog[id, :responsetime] = travel_time / 60 # minutes

        amb = respond_to!(redeploy, i, t)
        ems.eventlog[id, :ambulance] = amb

        event = gui_event("call responded", problem.emergency_calls[id, :neighborhood], i, id, amb,-1, problem.available[i] ,Dates.now())
        num_ambulances_array = Array{Integer}(undef, size(problem.available, 1))
        for i in 1:size(problem.available, 1)
            num_ambulances_array[i] = problem.available[i]
        end
        push!(ems.guiArray,event)
        push!(ems.guiArray,num_ambulances_array)
        enqueue!(ems.eventqueue, (:arrive, id, t + travel_time, amb), t + travel_time)
    #else queue it
    else
        println(id, ": call from ", nbhd, " queued behind ", problem.wait_queue[nbhd])
        event = gui_event("call made", nbhd, -1, id, -1,-1,-1,Dates.now())
        push!(ems.guiArray,event)
        problem.shortfalls = problem.shortfalls + 1
        #push!(problem.shortfalls) # count shortfalls
        push!(problem.wait_queue[nbhd], id) # queue the emergency call
    end
end

function arr_event!(
        ems::EMSEngine,
        problem::DispatchProblem,
        redeploy::RedeployModel,
        id::Int, # the id of the emergency call
        t::Int, # the time of the emergency call
        amb::Int
    )
    arriveatscene!(redeploy, amb, t)
    # time the ambulance spends at the scene
    scene_time = ceil(Int,60*0.4*rand(problem.turnaround)) # 60sec*0.4*mean(40minutes) ~ 15minutes
    ems.eventlog[id, :scenetime] = scene_time / 60 # minutes
    @assert scene_time > 0
    enqueue!(ems.eventqueue, (:convey, id, t + scene_time, amb), t + scene_time)
end

#"determine the hospital to convey the patient to (currently it's based on the closest hospital)"
function con_event!(
        ems::EMSEngine,
        problem::DispatchProblem,
        redeploy::RedeployModel,
        id::Int, # the id of the emergency call
        t::Int, # the time of the emergency call
        amb::Int
    )
    h = let mintime = Inf, minindex = 0
        for h in 1:nrow(problem.hospitals)
            traveltime = problem.emergency_calls[id, Symbol("hosp$(h)_min")]
            if !isna(traveltime) && !(traveltime=="NA") && traveltime < mintime
                @assert traveltime >= 0
                minindex = h; mintime = traveltime
            end
        end
        minindex
    end
    @assert h != 0
    redeploy.hospital[amb] = ems.eventlog[id, :hospital] = h
    conveytime = 60*15 + ceil(Int, 60*problem.emergency_calls[id, Symbol("hosp$(h)_min")]) # ~20minutes
    ems.eventlog[id, :conveytime] = conveytime / 60 # minutes
    @assert conveytime >= 0 conveytime
    conveying!(redeploy, amb, h, t)
    enqueue!(ems.eventqueue, (:return, id, t+conveytime, amb), t+conveytime)
end

function ret_event!(
        ems::EMSEngine,
        problem::DispatchProblem,
        redeploy::RedeployModel,
        id::Int,
        t::Int,
        amb::Int
    )
    stn = returning_to!(redeploy, amb, t)
    h = redeploy.hospital[amb]
    returntime = ceil(Int,60*2*problem.hospitals[h, Symbol("stn$(stn)_min")]) # ~ 10minutes
    ems.eventlog[id, :returntime] = returntime / 60 # minutes
    @assert returntime >= 0 returntime
    t_end = t + returntime
    enqueue!(ems.eventqueue, (:done, id, t_end, amb), t_end)
    # num_ambulances_array = Array{Integer}(undef, size(problem.available, 1))
    # for i in 1:size(problem.available, 1)
    #     num_ambulances_array[i] = problem.available[i]
    # end
    # push!(ems.guiArray,num_ambulances_array)
end

function don_event!(
        ems::EMSEngine,
        problem::DispatchProblem,
        dispatch::DispatchModel,
        redeploy::RedeployModel,
        id::Int,
        t::Int,
        amb::Int
    )
    stn = redeploy.assignment[amb]; @assert stn > 0
    if sum(length(wq) for wq in problem.wait_queue[problem.coverage[:,stn]]) > 0
        # people are waiting in a queue
        redirected!(redeploy, amb, t)
        # determine the person who has waited the longest
        minindex = 0; mintime = Inf
        for nbhd in 1:size(problem.coverage,1)
            if problem.coverage[nbhd,stn] && length(problem.wait_queue[nbhd]) > 0
                arrivaltime = problem.emergency_calls[problem.wait_queue[nbhd][1], :arrival_seconds]
                if arrivaltime < mintime
                    mintime = arrivaltime
                    minindex = nbhd
                end
            end
        end
        waittime = t - mintime
        @assert minindex != 0
        @assert waittime >= 0
        @assert 0 <= mintime < Inf

        # respond to the person
        let id = popfirst!(problem.wait_queue[minindex])
            println(id,": amb ", amb, " redirected from stn ", stn, " to serve ", problem.emergency_calls[id, :neighborhood])
            # =    call made / call responded / ambulance arrived
            #    String::event_type
                #neighborhood where call is made from
            #    Int::neighborhood_id
                # station where call is made from
            #    Int::deployment_id
                # id of the event generated
            #    Int::event_id
            #    Int::ambulance_id
            #    =#
            event = gui_event("call responded", problem.emergency_calls[id, :neighborhood], stn, id, amb,-1,problem.available[stn],Dates.now())
            num_ambulances_array = Array{Integer}(undef, size(problem.available, 1))
            for i in 1:size(problem.available, 1)
                num_ambulances_array[i] = problem.available[i]
            end
            push!(ems.guiArray,event)
            push!(ems.guiArray,num_ambulances_array)
            ems.eventlog[id, :return_to] = id
            ems.eventlog[id, :return_type] = :incident
            ems.eventlog[id, :ambulance] = amb
            ems.eventlog[id, :dispatch_from] = stn
            ems.eventlog[id, :waittime] = waittime / 60 # minutes
            travel_time = ceil(Int,60*problem.emergency_calls[id, Symbol("stn$(stn)_min")])
            ems.eventlog[id, :responsetime] = travel_time / 60 # minutes
            @assert travel_time >= 0
            # =    call made / call responded / ambulance arrived
            #    String::event_type
                #neighborhood where call is made from
            #    Int::neighborhood_id
                # station where call is made from
            #    Int::deployment_id
                # id of the event generated
            #    Int::event_id
            #    Int::ambulance_id
            #    =#
            eventresp = gui_event("call arrived", problem.emergency_calls[id, :neighborhood], stn, id, amb,travel_time,-1,Dates.now())
            push!(ems.guiArray,eventresp)
            total_delay = waittime + travel_time; @assert total_delay >= 0
            tarrive = t + total_delay; #@assert t + total_delay >= 0 "$t, $total_delay"
            enqueue!(ems.eventqueue, (:arrive, id, tarrive, amb), tarrive)
        end
    else # returned to base location
        ems.eventlog[id, :return_to] = redeploy.assignment[amb]
#        @assert ems.eventlog[id, :return_type] == :station
        returned_to!(redeploy, amb, t)
        returned_to!(problem, stn, t)
        # Add here
        update_ambulances!(dispatch, stn, 1)
        num_ambulances_array = Array{Integer}(undef, size(problem.available, 1))
        for i in 1:size(problem.available, 1)
            num_ambulances_array[i] = problem.available[i]
        end
        push!(ems.guiArray,num_ambulances_array)

    end
end


function sim_events!(
        problem::DispatchProblem,
        dispatch::DispatchModel,
        redeploy::RedeployModel;
        verbose::Bool=false
    )
    ems = EMSEngine(problem)

    # @show problem.available
    # @show redeploy.ambulances
    while !isempty(ems.eventqueue)
        (event, id, t, value) = dequeue!(ems.eventqueue)
        # @show (event, id, t, value)
        @assert t >= 0 # in case of integer overflow (when calls > ambulances)
        if event == :call
            call_event!(ems, problem, dispatch, redeploy, id, t, value, verbose=verbose)
        elseif event == :arrive
            arrive_event!(ems, problem, redeploy, id, t, value)
        elseif event == :convey
            convey_event!(ems, problem, redeploy, id, t, value)
        elseif event == :return
            # @show problem.available
            # @show redeploy.ambulances
            # @show redeploy.assignment
            reassign_ambulances!(ems, problem, redeploy, t)
            # println("obj: ", JuMP.getvalue(redeploy.obj1), ", ", JuMP.getvalue(redeploy.obj2))
            return_event!(ems, problem, redeploy, id, t, value)
        else
            @assert event == :done
            done_event!(ems, problem, dispatch, redeploy, id, t, value)
        end
        for i in eachindex(problem.available)
            #@assert problem.available[i] == length(redeploy.ambulances[i]) "$(problem.available) versus $(redeploy.ambulances)" # "$i: $(problem.available[i]), $(length(redeploy.ambulances[i]))"
        end
    end
    # @assert all(problem.available .== problem.deployment)
    @assert all(ems.eventlog[!,:dispatch_from] .>= 0)
     ems.eventlog, ems.guiArray
end
