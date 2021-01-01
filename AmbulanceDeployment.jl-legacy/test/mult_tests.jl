#=
Author : Guy Farmer
Modified : none
runs dispatch simulations on numerous dc models using original dc data and plots the results
=#

using DataFrames, JLD, Distributions, CSV, Random, Plots
import DataStructures: PriorityQueue, enqueue!, dequeue!
include("..//src//model.jl")
include("..//src//dispatch/closestdispatch.jl")
include("..//src//problem.jl")
include("..//src//simulate.jl")
#include("..//src//evaluate.jl")

turnaround = Distributions.LogNormal(3.65, 0.3)
ncalls = 100
namb = 20
lambda = 0

local_path = ""
hourly_calls = CSV.File(string(local_path,"data/processed/2-weekday_calls.csv")) |> DataFrame
adjacent_nbhd = CSV.File(string(local_path,"data/processed/2-adjacent_nbhd.csv")) |> DataFrame
coverage = JLD.load(string(local_path,"data/processed/3-coverage.jld"), "stn_coverage")
hospitals = CSV.File(string(local_path,"data/processed/3-hospitals.csv")) |> DataFrame
stations = CSV.File(string(local_path,"data/processed/3-stations.csv")) |> DataFrame
 #solverstats = JLD.load(string(local_path,"data/processed/4-solve-stats.jld"))
# solverstats = JLD.load("../src/team_stats.jld")
amb_deployment = solverstats["amb_deployment"]
const model_names = (:Stochastic, :Robust01, :Robust005, :Robust001, :Robust0001, :Robust00001, :MEXCLP, :MALP)
#const model_names = (:Stochastic, :Robust01,:MEXCLP, :MALP)
model_namb = [25, 30, 35, 40, 45, 50] #note 10 breaks some assertion in simulation
#name = model_names[1]

p = DeploymentProblem(
    hourly_calls,
    adjacent_nbhd,
    coverage,
    namb = namb,
    train_filter = (hourly_calls[!,:year] .== 2012) .* (hourly_calls[!,:month] .<= 3)
)

# We focus on emergency calls during the "peak period" (8AM - 8PM),
# with the emergency calls from the first 3 month as our training set,
# and the subsequent emergency calls from the remaining months as our test set

# calls = DataFrames.readtable("data/processed/5-calls.csv");
# inc_test_filter  = !((calls[:year] .== 2012) .* (calls[:month] .<= 3))
# test_calls = calls[(1:nrow(calls))[inc_test_filter][1:ncalls],:];
test_calls = CSV.File("test_calls.csv")|> DataFrame
test_calls = test_calls[1:ncalls,:] #lowers call count. which makes simulation faster for debugging.

#iterates through model (names) and number of ambulances for example Stochastic model with 20 ambulances
results = Array{Float64,2}(undef, 1, 5) #it saves the results to print later
for j = 1:1
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
    results[j,i] = mean(df[!,:waittime] + df[!,:responsetime])

end
end

plot(model_namb, adjoint(results[:,:]), markershape = :ltriangle, label = "stochastic")
xlabel!("Number of Ambulances")
ylabel!("Mean Response Time")
savefig("og_stochasticplot.png")
JLD.jldopen("stochastic.jld", "w") do file
    write(file, "amb_deployment", amb_deployment)
end
# x = amb_deployment[name][namb]
# problem = DispatchProblem(test_calls, hospitals, stations, p.coverage, x, turnaround=turnaround)
# dispatch = ClosestDispatch(p, problem)
# redeploy = AssignmentModel(p, x, hospitals, stations, lambda=Float64(lambda))
#
# # id 145 dispatch to nbhd 88
# Random.seed!(1234); # reset seed
# @time df = simulate_events!(problem, dispatch, redeploy);
# @show mean(df[!,:waittime]), maximum(df[!,:waittime])
# @show mean(df[!,:waittime] + df[!,:responsetime])
