#=
Author : Guy Farmer, Michael Hilborn
Runs simulations for all models (generated in Ambulance_Deployment_experiments.jl) and returns the data as a dictionary
=#

using AmbulanceDeployment
#using DataFrames, JLD, Distributions, CSV, Random, Plots,JSON
#import DataStructures: PriorityQueue, enqueue!, dequeue!
#include("..//src//model.jl")
#include("..//src//dispatch/closestdispatch.jl")
#include("..//src//problem.jl")
#include("..//src//simulate.jl")
#include("..//src//evaluate.jl")
    function generate_simulation(model_name::String, namb::Int, ncalls::Int)

        turnaround = Distributions.LogNormal(3.65, 0.3)
        lambda = 0
        local_path = ""

        hospitals = CSV.File(string(local_path,"../test/austin-data/hospitals.csv")) |> DataFrame
        stations = CSV.File(string(local_path,"../test/austin-data/stations.csv")) |> DataFrame
        hourly_calls = CSV.File("../test/austin-data/Full_WeekdayCalls.csv") |> DataFrame
        adjacent_nbhd = CSV.File("../test/austin-data/adjacent_nbhd.csv") |> DataFrame
        coverage = CSV.read("../test/austin-data/coverage_real.csv", DataFrame, header=false)
        coverage = convert(Array{Bool, 2}, coverage[:, :])
        incidents = CSV.File("../test/austin-data/austin_incidents.csv") |> DataFrame
        solverstats = JLD.load("../src/outputs/austin_team_stats_1_03.jld")
        amb_deployment = solverstats["amb_deployment"]
        model_dict = Dict{String, Symbol}("Stochastic"=>:Stochastic, "Robust01"=>:Robust01, "Robust005"=>:Robust005, "Robust001"=>:Robust001, "Robust0001"=>:Robust0001,
        "Robust00001"=>:Robust00001, "MEXCLP"=>:MEXCLP, "MALP"=>:MALP)

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

        # calls = DataFrames.readtable("data/processed/5-calls.csv");
        # inc_test_filter  = !((calls[:year] .== 2012) .* (calls[:month] .<= 3))
        # test_calls = calls[(1:nrow(calls))[inc_test_filter][1:ncalls],:];
        test_calls = CSV.File("../test/austin-data/austin_test_calls.csv")|> DataFrame
        test_calls = test_calls[1:ncalls,:] #lowers call count. which makes simulation faster for debugging.
        #iterates through model (names) and number of ambulances for example Stochastic model with 20 ambulances
        # results = Array{Float64,2}(undef, 8, 5) #it saves the results to print later

        # model_results = Any[]
        println("running $namb ambuances & $ncalls calls")
        x = amb_deployment[model_dict[model_name]][namb]
        problem = DispatchProblem(test_calls, hospitals, stations, p.coverage, x, turnaround=turnaround)
        dispatch = ClosestDispatch(p, problem)


        #redeploy = AssignmentModel(p, x, hospitals, stations, lambda=Float64(lambda))

        # id 145 dispatch to nbhd 88
        Random.seed!(1234); # reset seed
        @time df, guiArray = simulate_events!(problem, dispatch);
        #@show mean(df[!,:waittime]), maximum(df[!,:waittime])
        #@show mean(df[!,:waittime] + df[!,:responsetime])
        #results[j,i,1] = mean(df[!,:waittime]), maximum(df[!,:waittime])
        println("wait time : ", df[!,:waittime])
        println("response time: ", df[!,:responsetime])

        d = df[!,:responsetime]
        r = d
        d = filter(x->x!=Inf,d)
        m =  mean(d)
        println("mean response time = $m")
        json_string = JSON.json(guiArray)
        open("../src/outputs/guiArray.json","w") do f
            write(f, json_string)
        end
        return guiArray
        #results[j,i] = mean(df[!,:waittime] + df[!,:responsetime])
end


# stuff = generate_simulation("Stochastic", 30, 1000)
