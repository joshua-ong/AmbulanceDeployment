using AmbulanceDeployment, Dates

Pkg.add("Query")
using Query

struct EMSEngine{T}
    eventlog::DataFrame
    eventqueue::PriorityQueue{T,Int,Base.Order.ForwardOrdering}
    shortqueue::PriorityQueue{T,Int,Base.Order.ForwardOrdering}
    guiArray::Array{Any, 1}
end

struct gui_event
    #call made / call responded / ambulance arrived / shortfall
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

## generates the priority queue and instantiates the EMSEngine struct
function generateCalls(problem::DispatchProblem)
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
    shortqueue = PriorityQueue{Tuple{Symbol,Int,Int,Int},Int}()
    guiArray = Any[]
    for i in 1:nrow(problem.emergency_calls)
        t = problem.emergency_calls[i, :arrival_seconds]
        enqueue!(eventqueue, (:call, i, t, problem.emergency_calls[i, :neighborhood]), t)
    end
    EMSEngine{Tuple{Symbol,Int,Int,Int}}(eventlog, eventqueue, shortqueue, guiArray) ## returns the ems engine struct
end

function simulate_events!(problem::DispatchProblem, dispatch::ClosestDispatch)
    engine = generateCalls(problem)
    while(~isempty(engine.eventqueue))
        (event, id, t, value) = dequeue!(engine.eventqueue)

        if event == :call
            # if the event is reachable then change event to station2call
            # if not it is a shortfall
            println("calling event id: $id time: $t value: $value")
            call_event!(engine, problem, dispatch, id, t, value)

        elseif event == :station2call
            #once the ambulance arrives at the station change event to call2hospital
            println("Ambulance has arrived on the scene for event $id at time $t")
            station2call_event!(engine, problem, dispatch, id, t, value)
        elseif event == :call2hospital
            #once the ambulance arrives at the hospital it will hand over the patient and then
            #change the deploy back to its station
            println("Ambulance for event $id has arrived at the hospital at time $t")
            call2hosp_event!(engine, problem, dispatch, id, t, value)

        elseif event == :hospital2station
            #once the ambulance drops off the patient it will reroute to the station
            println("Ambulance for event $id is returning to the station at $t")
            return_event!(engine, problem, dispatch, id, t, value)

        elseif event == :done
            #increase the number of ambulances at that station now that it is done
            done_event!(engine, problem, dispatch, id, t, value)

        end
    end
    println("This is the Short Queue")
    while(~isempty(engine.shortqueue))
       (event, id, t, value) = dequeue!(engine.shortqueue)
        print("$event, $id, $t, $value")
        print("This is not empty")
    end
    engine.eventlog , engine.guiArray
end


function call_event!(
        ems::EMSEngine,
        problem::DispatchProblem,
        dispatch::DispatchModel,
        id::Int, # the id of the emergency call
        t::Int, # the time of the emergency call
        nbhd::Int; # the neighborhood the call is from
    )

    #check if there is an ambulance within the coverage matrix
    if sum(problem.deployment[problem.coverage[nbhd,:]]) == 0
        @assert false "$id: no ambulance reachable for call at $nbhd"
    #check if one of the ambulances within the coverage is available
    elseif sum(problem.available[problem.coverage[nbhd,:]]) > 0
        i = closest_available(dispatch, id, problem)
        #println("closest available station : $i")
        @assert i > 0 "$id: dispatch from $i to nbhd $nbhd" # assume valid i (enforced by <if> condition)
        update_ambulances!(dispatch, i, -1)
        ems.eventlog[id, :dispatch_from] = i
        @assert problem.available[i] >= 0


        travel_time = ceil(Int, 60*2*problem.emergency_calls[id, Symbol("stn$(i)_min")])
        @assert travel_time >= 0
        if(t != problem.emergency_calls[id, :arrival_seconds])
            print("This is a shortfall")
        end
        ems.eventlog[id, :responsetime] = (travel_time + t - problem.emergency_calls[id,:arrival_seconds]) / 60 # minutes

        amb = respond_to!(dispatch, i, t)
        ems.eventlog[id, :ambulance] = amb

        event = gui_event("call responded", problem.emergency_calls[id, :neighborhood], i, id, amb,-1, problem.available[i] ,Dates.now())
        num_ambulances_array = Array{Integer}(undef, size(problem.available, 1))
        for i in 1:size(problem.available, 1)
            num_ambulances_array[i] = problem.available[i]
        end
        push!(ems.guiArray,event)
        push!(ems.guiArray,num_ambulances_array)
        enqueue!(ems.eventqueue, (:station2call, id, t + travel_time, amb), t + travel_time)
    #else queue it
    else
        # println(id, ": call from ", nbhd, " queued behind ", problem.wait_queue[nbhd])
        # event = gui_event("call made", nbhd, -1, id, -1,-1,-1,Dates.now())
        # push!(ems.guiArray,event)
        # problem.shortfalls = problem.shortfalls + 1
        # #push!(problem.shortfalls) # count shortfalls
        # push!(problem.wait_queue[nbhd], id) # queue the emergency call
        event = gui_event("shortfall", problem.emergency_calls[id, :neighborhood], -1, id, -1,-1,-1 ,Dates.now())
        push!(ems.guiArray, event)
        enqueue!(ems.shortqueue, (:call, id, t, problem.emergency_calls[id, :neighborhood]), t)
        println(id, ": call from ", nbhd, " is a shortfall")
    end
end

function station2call_event!(
        ems::EMSEngine,
        problem::DispatchProblem,
        dispatch::DispatchModel,
        id::Int, # the id of the emergency call
        t::Int, # the time of the emergency call
        amb::Int
    )
    arriveatscene!(dispatch, amb, t)
    # time the ambulance spends at the scene
    scene_time = ceil(Int,60*0.4*rand(problem.turnaround)) # 60sec*0.4*mean(40minutes) ~ 15minutes
    ems.eventlog[id, :scenetime] = scene_time / 60 # minutes
    @assert scene_time > 0

    event = gui_event("ambulance arrived", problem.emergency_calls[id, :neighborhood], -1, id, amb, t,-1 ,Dates.now())
    push!(ems.guiArray, event)
    enqueue!(ems.eventqueue, (:call2hospital, id, t + scene_time, amb), t + scene_time)
end

function call2hosp_event!(
        ems::EMSEngine,
        problem::DispatchProblem,
        dispatch::DispatchModel,
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
    dispatch.hospital[amb] = ems.eventlog[id, :hospital] = h
    conveytime = 60*15 + ceil(Int, 60*problem.emergency_calls[id, Symbol("hosp$(h)_min")]) # ~20minutes
    ems.eventlog[id, :conveytime] = conveytime / 60 # minutes
    @assert conveytime >= 0 conveytime
    arriveathospital!(dispatch, amb, h, t)

    #         #call made / call responded / ambulance arrived / shortfall
#     event_type::String
#     #neighborhood where call is made from
#     neighborhood_id::Int
#     # station where call is made from
#     deployment_id::Int
#     # id of the event generated
#     event_id::Int
#     ambulance_id::Int
#     arrival_time::Int
#     remaining_amb::Int
#     # current timestamp of event
#     timestamp::DateTime
    event = gui_event("ambulance hospital", problem.emergency_calls[id, :neighborhood], -1, id, amb, t,-1 ,Dates.now())
    push!(ems.guiArray, event)


    enqueue!(ems.eventqueue, (:hospital2station, id, t+conveytime, amb), t+conveytime)
end

function return_event!(
        ems::EMSEngine,
        problem::DispatchProblem,
        dispatch::DispatchModel,
        id::Int,
        t::Int,
        amb::Int
    )
    stn = returning_to!(dispatch, amb, t)
    h = dispatch.hospital[amb]
    returntime = ceil(Int,60*2*problem.hospitals[h, Symbol("stn$(stn)_min")]) # ~ 10minutes
    dispatch.hospital[amb] = 0
    ems.eventlog[id, :returntime] = returntime / 60 # minutes
    @assert returntime >= 0 returntime
    t_end = t + returntime

#         #call made / call responded / ambulance arrived / shortfall
#     event_type::String
#     #neighborhood where call is made from
#     neighborhood_id::Int
#     # station where call is made from
#     deployment_id::Int
#     # id of the event generated
#     event_id::Int
#     ambulance_id::Int
#     arrival_time::Int
#     remaining_amb::Int
#     # current timestamp of event
#     timestamp::DateTime

    event = gui_event("ambulance returning", problem.emergency_calls[id, :neighborhood], -1, id, amb, t,-1 ,Dates.now())
    push!(ems.guiArray, event)


    enqueue!(ems.eventqueue, (:done, id, t_end, amb), t_end)
    # num_ambulances_array = Array{Integer}(undef, size(problem.available, 1))
    # for i in 1:size(problem.available, 1)
    #     num_ambulances_array[i] = problem.available[i]
    # end
    # push!(ems.guiArray,num_ambulances_array)
end

function done_event!(
        ems::EMSEngine,
        problem::DispatchProblem,
        dispatch::DispatchModel,
        id::Int,
        t::Int,
        amb::Int
    )
    i = dispatch.assignment[amb]
    println("Ambulance from event $id has returned to station $i")
    @assert i > 0 "$id: dispatch from $i to nbhd $nbhd" # assume valid i (enforced by <if> condition)
    update_ambulances!(dispatch, i, 1)
    push!(dispatch.ambulances[i], amb)
    dispatch.status[amb] = :available
    ems.eventlog[id, :return_to] = id
    @assert problem.available[i] > 0

#         #call made / call responded / ambulance arrived / shortfall
#     event_type::String
#     #neighborhood where call is made from
#     neighborhood_id::Int
#     # station where call is made from
#     deployment_id::Int
#     # id of the event generated
#     event_id::Int
#     ambulance_id::Int
#     arrival_time::Int
#     remaining_amb::Int
#     # current timestamp of event
#     timestamp::DateTime

    event = gui_event("ambulance returned", problem.emergency_calls[id, :neighborhood], -1, id, amb, t,-1 ,Dates.now())
    push!(ems.guiArray, event)

    while(~isempty(ems.shortqueue))
        # record time difference
        (event, short_id, short_t, value) = dequeue!(ems.shortqueue)
        enqueue!(ems.eventqueue, (event, short_id, t , value), short_t)
    end
end
