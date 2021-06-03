#=
Author : Guy Farmer, Michael Hilborn
Runs simulations for all models (generated in Ambulance_Deployment_experiments.jl) and returns the data as a dictionary
=#


using AmbulanceDeployment

function generate_simulation(model_name::String, namb::Int, ncalls::Int)

    turnaround = Distributions.LogNormal(3.65, 0.3)
    lambda = 0
    local_path = ""

    solverstats = JSON.parsefile(PROJECT_ROOT * "/src/outputs/solver_stats.json")
    hospitals = CSV.File(string(local_path, PROJECT_ROOT * "/test/austin-data/hospitals.csv")) |> DataFrame
    stations = CSV.File(string(local_path, PROJECT_ROOT * "/test/austin-data/stations.csv")) |> DataFrame
    hourly_calls = CSV.File(PROJECT_ROOT * "/test/austin-data/Full_WeekdayCalls.csv") |> DataFrame
    adjacent_nbhd = CSV.File(PROJECT_ROOT * "/test/austin-data/adjacent_nbhd.csv") |> DataFrame
    coverage = CSV.read(PROJECT_ROOT * "/test/austin-data/coverage_real.csv", DataFrame, header=false)
    coverage = convert(Array{Bool, 2}, coverage[:, :])
    incidents = CSV.File(PROJECT_ROOT * "/test/austin-data/austin_incidents.csv") |> DataFrame
    amb_deployment = solverstats["amb_deployment"]
    model_dict = Dict{String, Symbol}("Stochastic"=>:Stochastic, "Robust01"=>:Robust01, "Robust005"=>:Robust005, "Robust001"=>:Robust001, "Robust0001"=>:Robust0001,
    "Robust00001"=>:Robust00001, "MEXCLP"=>:MEXCLP, "MALP"=>:MALP)
    test_calls = CSV.File(PROJECT_ROOT *"/test/austin-data/austin_test_calls.csv")|> DataFrame
    # remember to reset number of calls
    test_calls = test_calls[1:ncalls,:]
    #filtering out invalid neighborhoods

    test_calls = filter(x->x[:neighborhood]>0,test_calls)

    p = DeploymentProblem(
    hourly_calls,
    adjacent_nbhd,
    coverage,
    namb = namb,
    train_filter = (hourly_calls[!,:year] .== 2019) .* (hourly_calls[!,:month] .<= 3)
    )

    # We focus on emergency calls during the "peak period" (8AM - 8PM),
    # with the emergency calls from the first 3 month as our training set,
    # and the subsequent emergency calls from the remaining months as our test set

    println("running $namb ambuances & $ncalls calls")
    x = amb_deployment[model_name][string(namb)]
    x = convert(Array{Int64}, x)
    problem = DispatchProblem(test_calls, hospitals, stations, p.coverage, x, turnaround=turnaround)
    dispatch = ClosestDispatch(p, problem)

    # id 145 dispatch to nbhd 88
    Random.seed!(1234); # reset seed
    @time df, guiArray = simulate_events!(problem, dispatch);
    println("wait time : ", df[!,:waittime])
    println("response time: ", df[!,:responsetime])

    d = df[!,:responsetime]
    r = d
    d = filter(x->x!=Inf,d)
    m =  mean(d)
    println("mean response time = $m")
    json_string = JSON.json(guiArray)
    open(PROJECT_ROOT *"/src/outputs/guiArray.json","w") do f
        write(f, json_string)
    end
    events = filter(x->typeof(x)==gui_event,guiArray)
    responded_array = filter(x->x.event_type == "call responded", events)
    arrived_array = filter(x->x.event_type == "ambulance arrived", events)
    return guiArray, responded_array, arrived_array
    #results[j,i] = mean(df[!,:waittime] + df[!,:responsetime])
end
