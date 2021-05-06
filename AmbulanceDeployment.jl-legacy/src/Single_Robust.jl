#how to run
#include("Single_Robust.jl")
#generate_robust
joshpath = "C:/Users/Owner/Documents/Austin/AmbulanceDeployment/AmbulanceDeployment.jl-legacy"

PROJECT_ROOT = joshpath
currentpath = joshpath

using AmbulanceDeployment
using DataFrames, Winston, JLD, CSV, Gurobi, JuMP, GLPK, Dates

function generate_robust()
    # hourly calls - regions x hours x number of calls/ per region per hour (e.g. 210 x 10000 x Z)
    #adjacent_nbhd - boolean matrix, regionxregion (210x210) - if neighborhoods/region are adjacent?
    #coverage - boolean matrix, regions x stations (210x44) - true if station is within coverage of region
    #incidents - god object
    hourly_calls = CSV.File(PROJECT_ROOT * "/test/austin-data/Full_WeekdayCalls.csv") |> DataFrame
    # weekend_hourly_calls = CSV.File("data/processed/2-weekend_calls.csv") |> DataFrame
    adjacent_nbhd = CSV.File(PROJECT_ROOT * "/test/austin-data/adjacent_nbhd.csv") |> DataFrame
    coverage = CSV.read(PROJECT_ROOT * "/test/austin-data/coverage_real.csv", DataFrame, header=false)
    coverage = convert(Array{Bool, 2}, coverage[:, :])
    #incidents = CSV.File(PROJECT_ROOT * "/test/austin-data/austin_incidents.csv") |> DataFrame

    #regions - list of regions/neighborhoods where demands come from (1 ... 210)
    #locations -list of stations (1 ... 44)
    #demands - hours x regions = demands
    regions = Int[parse(Int,string(x)) for x in names(hourly_calls[:,6:ncol(hourly_calls)])]
    locations = collect(1:size(coverage,2))
    adjacent = convert(Array, adjacent_nbhd[:,2:ncol(adjacent_nbhd)])[regions,regions] .> 0.5
    demand = convert(Array,hourly_calls[:,6:end]);

    # We focus on emergency calls during the "peak period" (8AM - 8PM),
    # with the emergency calls from the first 3 month as our training set,
    # and the subsequent emergency calls from the remaining months as our test set
    peak_period = (hourly_calls[!,:hour] .>= 8) .* (hourly_calls[!,:hour] .<= 20)
    indices = 1:DataFrames.nrow(hourly_calls);
    train_filter = (hourly_calls[!,:year] .== 2019) .* (hourly_calls[!,:month] .<= 3)
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

    (deployment_model, name) = (next_dp -> RobustDeployment(next_dp, α=0.1), :Robust01)
    amb_deployment[name] = Dict{Int, Vector{Int}}()
    scenarios[name] = Dict{Int, Vector{Vector{Int}}}()
    generated_deployment[name] = Dict{Int, Vector{Vector{Int}}}()
    upperbounds[name] = Dict{Int, Vector{Float64}}()
    lowerbounds[name] = Dict{Int, Vector{Float64}}()
    upptiming[name] = Dict{Int, Vector{Float64}}()
    lowtiming[name] = Dict{Int, Vector{Float64}}()
    namb = 50
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
    model
end
