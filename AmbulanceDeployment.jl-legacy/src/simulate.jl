using AmbulanceDeployment, Dates

struct EMSEngine{T}
    eventlog::DataFrame
    eventqueue::PriorityQueue{T,Int,Base.Order.ForwardOrdering}
    guiArray::Array{Any, 1}
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
    guiArray = Any[]
    for i in 1:nrow(problem.emergency_calls)
        t = problem.emergency_calls[i, :arrival_seconds]
        enqueue!(eventqueue, (:call, i, t, problem.emergency_calls[i, :neighborhood]), t)
    end
    EMSEngine{Tuple{Symbol,Int,Int,Int}}(eventlog, eventqueue,guiArray) ## returns the ems engine struct
end

function simulate_events!(problem::DispatchProblem, dispatch::ClosestDispatch)
    engine = generateCalls(problem)
    while(~isempty(engine.eventqueue))
        (event, id, t, value) = dequeue!(engine.eventqueue)

        if event == :call
            # if the event is reachable then change event to station2call
            # if not it is a shortfall
            call_event!(engine, problem, dispatch, id, t, value)
        elseif event == :station2call
            #
        elseif event == :call2hospital

        elseif event == :hospital2station

        end
    end

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
        # println(id, ": call from ", nbhd, " queued behind ", problem.wait_queue[nbhd])
        # event = gui_event("call made", nbhd, -1, id, -1,-1,-1,Dates.now())
        # push!(ems.guiArray,event)
        # problem.shortfalls = problem.shortfalls + 1
        # #push!(problem.shortfalls) # count shortfalls
        # push!(problem.wait_queue[nbhd], id) # queue the emergency call
        println(id, ": call from ", nbhd, " is a shortfall")
    end
end
