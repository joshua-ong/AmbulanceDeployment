#how to run
#include("Single_Robust.jl")
#generate_robust
joshpath = "C:/Users/Owner/Documents/Austin/AmbulanceDeployment/AmbulanceDeployment.jl-legacy"

PROJECT_ROOT = joshpath
currentpath = joshpath

using AmbulanceDeployment
using DataFrames, Winston, JLD, CSV, Gurobi, JuMP, GLPK, Dates
using JSON

function generate_robust(alpha::Float64 = .1, namb::Int64 = 40, cross_validation::Int64 = 1)
   adjacent_nbhd = CSV.File("C:/Users/Owner/Documents/Austin/AmbulanceDeployment/AmbulanceDeployment.jl-legacy/test/austin_data/adjacent_nbhd.csv") |> DataFrame
   coverage = CSV.File("C:/Users/Owner/Documents/Austin/AmbulanceDeployment/AmbulanceDeployment.jl-legacy/test/austin_data/coverage.csv") |> DataFrame
   hourly_calls = CSV.File("C:/Users/Owner/Documents/Austin/AmbulanceDeployment/AmbulanceDeployment.jl-legacy/test/austin_data/Full_WeekdayCalls.csv") |> DataFrame

   print("\n coverage ",size(coverage))
   print("\n hourly_calls ",size(hourly_calls))
   print("\n adjacent_nbhd ",size(adjacent_nbhd))

   num_regions = 209
   regions = collect(1:209)

   #reformat data frames as matrix data
   locations = collect(1:size(coverage,2))
   coverage = Matrix(coverage)
   coverage = convert(Array{Bool, 2}, coverage[:, :])
   adjacent = Matrix(adjacent_nbhd[!,2:end])
   adjacent = adjacent[regions,regions] .> 0.5
   demand = Matrix(hourly_calls[!,5:end-1]); #we were trimming first 6 collumns but it seems to me it only the first 5 contain extraneous data

   print("\n coverage ",size(coverage))
   print("\n demand ",size(demand))
   print("\n adjacent ",size(adjacent))

    # We focus on emergency calls during the "peak period" (8AM - 8PM),
    # with the emergency calls from the first 3 month as our training set,
    # and the subsequent emergency calls from the remaining months as our test set
    peak_period = (hourly_calls[!,:hour] .>= 8) .* (hourly_calls[!,:hour] .<= 20)
    indices = 1:DataFrames.nrow(hourly_calls);
    if(cross_validation == 1)
          train_filter = (hourly_calls[!,:year] .== 2019) .* (hourly_calls[!,:month] .<= 3)
    elseif(cross_validation == 2)
          train_filter = (hourly_calls[!,:year] .== 2019) .* (hourly_calls[!,:month] .<= 6) .* (hourly_calls[!,:month] .>= 3)
    elseif(cross_validation == 3)
          train_filter = (hourly_calls[!,:year] .== 2019) .* (hourly_calls[!,:month] .<= 9) .* (hourly_calls[!,:month] .>= 6)
    end
    test_filter  = .~train_filter;
    train_indices = indices[train_filter]
    test_indices = indices[test_filter];

    # we distinguish between peak and offpeak hours
    train_peak = indices[peak_period .* train_filter]
    train_offpeak = indices[.~peak_period .* train_filter]

    test_peak = indices[peak_period .* test_filter]
    test_offpeak = indices[.~peak_period .* test_filter]

    p = DeploymentProblem(30, length(locations), length(regions), demand, train_indices,
          test_indices, coverage[regions,:], Array{Bool,2}(adjacent));
    #p.demand[p.train,:]

    #test_inc_peak = inc_peak_period .* inc_test_filter
    #test_inc_offpeak = .~inc_peak_period .* inc_test_filter;

    #data structures to record results
    scenarios = Dict{Symbol, Dict{Int, Vector{Vector{Int}}}}()
    generated_deployment = Dict{Symbol, Dict{Int, Vector{Vector{Int}}}}()
    upperbounds = Dict{Symbol, Dict{Int, Vector{Float64}}}()
    lowerbounds = Dict{Symbol, Dict{Int, Vector{Float64}}}()
    upptiming = Dict{Symbol, Dict{Int, Vector{Float64}}}()
    lowtiming = Dict{Symbol, Dict{Int, Vector{Float64}}}()
    amb_deployment = Dict{Symbol, Dict{Int, Vector{Int}}}()

    (deployment_model, name) = (next_dp -> RobustDeployment(next_dp, α=alpha), :Robust01)
    amb_deployment[name] = Dict{Int, Vector{Int}}()
    scenarios[name] = Dict{Int, Vector{Vector{Int}}}()
    generated_deployment[name] = Dict{Int, Vector{Vector{Int}}}()
    upperbounds[name] = Dict{Int, Vector{Float64}}()
    lowerbounds[name] = Dict{Int, Vector{Float64}}()
    upptiming[name] = Dict{Int, Vector{Float64}}()
    lowtiming[name] = Dict{Int, Vector{Float64}}()
    println("$namb ")
    p.nambulances = namb

    model = deployment_model(p)
    set_optimizer(model.m, Gurobi.Optimizer)
    @time AmbulanceDeployment.optimize_robust!(model, p);

    amb_deployment[name][namb] = deployment(model)

    # for tracking purposes
    scenarios[name][namb] = model.scenarios
    generated_deployment[name][namb] = model.deployment
    upperbounds[name][namb] = model.upperbounds
    lowerbounds[name][namb] = model.lowerbounds
    upptiming[name][namb] = model.upptiming
    lowtiming[name][namb] = model.lowtiming


    solver_stats = Dict{String, Any}()
    push!(solver_stats, "amb_deployment" => amb_deployment)
    push!(solver_stats, "scenarios" => scenarios)
    push!(solver_stats, "generated_deployment" => generated_deployment)
    push!(solver_stats, "upperbounds" => upperbounds)
    push!(solver_stats, "lowerbounds" => lowerbounds)
    push!(solver_stats, "upptiming" => upptiming)
    push!(solver_stats, "lowtiming" => lowtiming)
    json_string = JSON.json(solver_stats)

    open(string(PROJECT_ROOT , "/src/outputs/solver_stats_8_7.json"),"w") do f
     write(f, json_string)
    end

    print(sum(model.scenarios[1]))
    model
end
