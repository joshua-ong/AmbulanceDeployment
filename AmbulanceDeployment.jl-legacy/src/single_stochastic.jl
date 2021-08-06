#=
Author : Guy Farmer
generates a distribution of ambulances for various ambulance counts and stores to a jld file
=#
using AmbulanceDeployment

#using AmbulanceDeployment
using DataFrames, Winston, JLD, CSV, Gurobi, JuMP, GLPK, JLD, JSON

# #I CAN'T for the life of me see the difference.
adjacent_nbhd = CSV.File("C:/Users/Owner/Documents/Austin/AmbulanceDeployment/AmbulanceDeployment.jl-legacy/test/austin_data/adjacent_nbhd.csv") |> DataFrame;
coverage = CSV.File("C:/Users/Owner/Documents/Austin/AmbulanceDeployment/AmbulanceDeployment.jl-legacy/test/austin_data/coverage.csv") |> DataFrame;
#coverage = convert(Array{Bool, 2}, coverage[:, :])
hourly_calls = CSV.File("C:/Users/Owner/Documents/Austin/AmbulanceDeployment/AmbulanceDeployment.jl-legacy/test/austin_data/Full_WeekdayCalls.csv") |> DataFrame;


num_regions = 209;
regions = collect(1:209);
locations = collect(1:size(coverage,2));
coverage = Matrix(coverage);
coverage = convert(Array{Bool, 2}, coverage[:, :]);
adjacent = Matrix(adjacent_nbhd[!,2:end]);
adjacent = adjacent[regions,regions] .> 0.5;
demand = Matrix(hourly_calls[!,5:end]); #we were trimming first 6 collumns but it seems to me it only the first contain ex

#= previously there was an error that didnt account for all the regions because it
 it only included regions for incidents. the regions without incidents are changed
 to 0=#
# for x in incidents[!,:neighborhood]
#     if(!haskey(regions2index,x))
#         regions2index[x] = 0
#     end
# end

# We focus on emergency calls during the "peak period" (8AM - 8PM),
# with the emergency calls from the first 3 month as our training set,
# and the subsequent emergency calls from the remaining months as our test set
peak_period = (hourly_calls[!,:hour] .>= 8) .* (hourly_calls[!,:hour] .<= 20);
indices = 1:DataFrames.nrow(hourly_calls);
train_filter = (hourly_calls[!,:year] .== 2019) .* (hourly_calls[!,:month] .<= 3);
test_filter  = .~train_filter;
train_indices = indices[train_filter];
test_indices = indices[test_filter];

p = DeploymentProblem(30, length(locations), length(regions), demand, train_indices,
                      test_indices, coverage[regions,:], Array{Bool,2}(adjacent));

amb_deployment = Dict{Symbol, Dict{Int, Vector{Int}}}();

(deployment_model, name) = (next_dp -> StochasticDeployment(next_dp, nperiods=500), :Stochastic)
println("$name: ")
amb_deployment[name] = Dict{Int, Vector{Int}}()
namb = 40
println("$namb ")
p.nambulances = namb
println("time for model generation - stochastic $namb ambulances")
## make sure to include @time begin
@time model = deployment_model(p);
#@time model2 = StochasticDeployment_hyp(p)
set_optimizer(model.m, Gurobi.Optimizer);
println("time for model solution - stochastic $namb ambulances")
@time AmbulanceDeployment.optimize!(model, p)
#@time AmbulanceDeployment.StochasticDeployment_hyp!(model, p, extra_amb = 1)

amb_deployment[name][namb] = deployment(model)
