#=
Author : Guy Farmer
Runs simulations for all models (generated in Ambulance_Deployment_experiments.jl) and stores the response times in json file
=#
using DataFrames, JLD, Distributions, CSV, Random, Plots,JSON
import DataStructures: PriorityQueue, enqueue!, dequeue!
include("..//src//model.jl")
include("..//src//dispatch/closestdispatch.jl")
include("..//src//problem.jl")
include("..//src//simulate.jl")
include("..//src//evaluate.jl")

turnaround = Distributions.LogNormal(3.65, 0.3)
ncalls = 100
namb = 40
lambda = 0

local_path = ""

hospitals = CSV.File(string(local_path,"../test/austin-data/hospitals.csv")) |> DataFrame
stations = CSV.File(string(local_path,"../test/austin-data/stations.csv")) |> DataFrame
 #solverstats = JLD.load(string(local_path,"data/processed/4-solve-stats.jld"))
hourly_calls = CSV.File("../test/austin-data/Full_WeekdayCalls.csv") |> DataFrame
 # weekend_hourly_calls = CSV.File("data/processed/2-weekend_calls.csv") |> DataFrame
adjacent_nbhd = CSV.File("../test/austin-data/adjacent_nbhd.csv") |> DataFrame
coverage = CSV.read("../test/austin-data/coverage_real.csv", DataFrame, header=false)
coverage = convert(Array{Bool, 2}, coverage[:, :])
incidents = CSV.File("../test/austin-data/austin_incidents.csv") |> DataFrame
solverstats = JLD.load("../src/austin_team_stats.jld")

amb_deployment = solverstats["amb_deployment"]
const model_names = (:Stochastic, :Robust01, :Robust005, :Robust001, :Robust0001, :Robust00001, :MEXCLP, :MALP)
# const model_names = (:Stochastic, :Robust01, :Robust005, :Robust001, :Robust0001, :Robust00001, :MEXCLP, :MALP)
#const model_names = (:Stochastic, :Robust01,:MEXCLP, :MALP)
model_namb = [30, 35, 40, 45, 50] #note 10 breaks some assertion in simulation
#name = model_names[1]

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
result_dict = Dict{Symbol, Dict{Int, Vector{Float64}}}()

#iterates through model (names) and number of ambulances for example Stochastic model with 20 ambulances
# results = Array{Float64,2}(undef, 8, 5) #it saves the results to print later
results = Any[]
for j = 1:8
    # model_results = Any[]
    result_dict[model_names[j]] = Dict{Int, Vector{Int}}()
    for i = 1:5
    print(i, j, "\n")
    x = amb_deployment[model_names[j]][model_namb[i]]
    problem = DispatchProblem(test_calls, hospitals, stations, p.coverage, x, turnaround=turnaround)
    dispatch = ClosestDispatch(p, problem)
    redeploy = AssignmentModel(p, x, hospitals, stations, lambda=Float64(lambda))

    # id 145 dispatch to nbhd 88
    Random.seed!(1234); # reset seed
    @time df = simulate_events!(problem, dispatch, redeploy);
    #@show mean(df[!,:waittime]), maximum(df[!,:waittime])
    #@show mean(df[!,:waittime] + df[!,:responsetime])
    #results[j,i,1] = mean(df[!,:waittime]), maximum(df[!,:waittime])
    println("wait time : ", df[!,:waittime])
    println("response time: ", df[!,:responsetime])
    result_dict[model_names[j]][model_namb[i]] = df[!,:responsetime]
    #results[j,i] = mean(df[!,:waittime] + df[!,:responsetime])
    end
end

    println("adding trivial solution")
    #x = amb_deployment[model_names[j]][model_namb[i]]
    x = ones(length(stations[:,1]))
    x = convert(Array{Int64,1}, x)
    x = [0, 0, 0, 0, 0, 0, 0, 2, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 0]
    problem = DispatchProblem(test_calls, hospitals, stations, p.coverage, x, turnaround=turnaround)
    dispatch = ClosestDispatch(p, problem)
    redeploy = AssignmentModel(p, x, hospitals, stations, lambda=Float64(lambda))

# id 145 dispatch to nbhd 88
    Random.seed!(1234); # reset seed
    @time df = simulate_events!(problem, dispatch, redeploy);
    #@show mean(df[!,:waittime]), maximum(df[!,:waittime])
    #@show mean(df[!,:waittime] + df[!,:responsetime])
    #results[j,i,1] = mean(df[!,:waittime]), maximum(df[!,:waittime])
    println("wait time : ", df[!,:waittime])
    println("response time: ", df[!,:responsetime])

    #   results[j,i] = mean(df[!,:waittime] + df[!,:responsetime])


JLD.jldopen("../src/outputs/austin_response_times.jld", "w") do file
    write(file, "response_times", result_dict)
end
json_string = JSON.json(result_dict)
open("../src/outputs/austin_response_times.json","w") do f
    write(f, json_string)
end
