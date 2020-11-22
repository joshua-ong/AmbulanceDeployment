
import Distributions, JLD, CSV, DataFrames,Pkg
using DataFrames, Distributions, JLD, CSV, Pkg
abstract type BM <: AbstractMatrix{Bool} end
abstract type IM <: AbstractMatrix{Int} end

mutable struct DeploymentProblem
        nambulances::Int
        nlocations::Int
        nregions::Int
        demand::Array{Int64,2}      # nperiod x nregion !! can potentially break !!
        train::Vector{Int}
        test::Vector{Int}
        coverage::Array{Bool,2}    # nregion x nlocation !! can potentially break !!
        adjacency::Array{Bool,2}   # nregion x nregion !! can potentially break !!
end

function DeploymentProblem(
        hourly_calls::DataFrame,
        adjacent_nbhd::DataFrame,
        coverage::Array{Bool,2}; #!! changed from original !!
        namb = 30,
        train_filter = (hourly_calls[:year] .== 2012) .* (hourly_calls[:month] .<= 3)
    )
    regions = Int[parse(Int,string(x)) for x in names(hourly_calls[5:end])]
    locations = collect(1:size(coverage,2))
    adjacent = convert(Array, adjacent_nbhd[2:end])[regions,regions] .> 0.5
    demand = convert(Array,hourly_calls[:,5:end])

    indices = 1:nrow(hourly_calls)
    train_indices = indices[train_filter]
    test_indices = indices[.!train_filter]

    DeploymentProblem(
        namb,
        length(locations),
        length(regions),
        demand,
        train_indices,
        test_indices,
        coverage[regions,:],
        Array{Bool,2}(adjacent)
    )
end
function naive_solution(p::DeploymentProblem)
    # evenly distribute the ambulances over all the locations
    x = zeros(Int, p.nlocations)
    for i in 0:p.nambulances-1
        x[1 + (i % p.nlocations)] += 1
    end
    x
end

mutable struct DispatchProblem
    emergency_calls::DataFrame
    hospitals::DataFrame
    stations::DataFrame
    coverage::Matrix{Bool} # (nbhd x stns)
    turnaround::LogNormal
    deployment::Vector{Int}

    wait_queue::Vector{Vector{Int}} # length nbhd
    available::Vector{Int} # length stns
    redeploy_events::Vector{Tuple{Int,Int,Int,Int}} # amb,from,to,time

    DispatchProblem(emergency_data::DataFrame,
                        hospitals::DataFrame,
                        stations::DataFrame,
                        coverage::Array{Bool,2};
                        turnaround::LogNormal = LogNormal(3.65, 0.3)) =
        new(emergency_data, hospitals, stations, coverage, turnaround)
end


function initialize!(problem::DispatchProblem, deployment::Vector{Int})
    problem.wait_queue = [Int[] for i in 1:size(problem.coverage,1)]
    problem.available = copy(deployment)
    problem.deployment = deepcopy(deployment)
    problem.redeploy_events = Tuple{Int,Int,Int,Int}[]

    problem.emergency_calls[:arrival_seconds] =
        cumsum(problem.emergency_calls[:interarrival_seconds])

    problem
end

function DispatchProblem(
        emergency_data::DataFrame,
        hospitals::DataFrame,
        stations::DataFrame,
        coverage::Array{Bool,2},
        deployment::Vector{Int};
        turnaround::LogNormal = LogNormal(3.65, 0.3)
    )
    problem = DispatchProblem(
        emergency_data,
        hospitals,
        stations,
        coverage,
        turnaround=turnaround
    )
    initialize!(problem, deployment)
end


function returned_to!(problem::DispatchProblem, location::Int, t::Int)
    @assert problem.available[location] >= 0
    problem.available[location] += 1
end

struct Params
    α::Float64 # Probabilistic Guarantee
    ε::Float64 # Convergence
    δ::Float64 # Solver Tolerance

    nperiods::Int # for StochasticDeployment

    maxiter::Int # for RobustDeployment
end
params = Params(0.01, 0.5, 1e-6, 500, 50)
