using Distributions, JLD, CSV, DataFrames,Pkg

Pkg.add("Gurobi")
Pkg.add("JuMP")
using Gurobi
using JuMP

abstract type BM <: AbstractMatrix{Bool} end
abstract type IM <: AbstractMatrix{Int} end

abstract type DispatchModel end
abstract type DeploymentModel end
abstract type RedeployModel end 


struct DeploymentProblem{ IM <: AbstractMatrix{Int},
                        BM <: AbstractMatrix{Bool}}
    nambulances::Int
    nlocations::Int
    nregions::Int
    demand::IM      # nperiod x nregion !! can potentially break !!
    train::Vector{Int}
    test::Vector{Int}
    coverage::BM    # nregion x nlocation !! can potentially break !!
    adjacency::BM   # nregion x nregion !! can potentially break !!
end

# ambulance deployment problem _ determines where to put ambulances

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

turnaround = Distributions.LogNormal(3.65, 0.3)
ncalls = 1000
namb = 30
lambda = 0

hourly_calls = CSV.File("data/processed/2-weekday_calls.csv") |> DataFrame
adjacent_nbhd = CSV.File("data/processed/2-adjacent_nbhd.csv") |> DataFrame
coverage = JLD.load("data/processed/3-coverage.jld", "stn_coverage")
hospitals = CSV.File("data/processed/3-hospitals.csv") |> DataFrame
stations = CSV.File("data/processed/3-stations.csv") |> DataFrame
solverstats = JLD.load("data/processed/4-solve-stats.jld")
amb_deployment = solverstats["amb_deployment"]
const model_names = (:Stochastic, :Robust01, :Robust005, :Robust001, :Robust0001, :Robust00001, :MEXCLP, :MALP)
name = model_names[1]
x = amb_deployment[name][namb]

p = DeploymentProblem(
           hourly_calls,
           adjacent_nbhd,
           coverage,
           namb = namb,
           train_filter = (hourly_calls[:year] .== 2012) .* (hourly_calls[:month] .<= 3)
       )


function naive_solution(p::DeploymentProblem)
    # evenly distribute the ambulances over all the locations
    x = zeros(Int, p.nlocations)
    for i in 0:p.nambulances-1
        x[1 + (i % p.nlocations)] += 1
    end
    x
end

test_calls = CSV.File("test_calls.csv") |> DataFrame

# ambulance routing problem / where the ambulances should go based on a call

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

problem = DispatchProblem(test_calls, hospitals, stations, p.coverage, x, turnaround=turnaround)

# defined a new abstract DispatchModel and struct (abstract contained in model.jl)
# struct defined in ClosestDispatch.jl

struct ClosestDispatch <: DispatchModel
           drivetime::DataFrame
           candidates::Vector{Vector{Int}}
       end
# defined a ClosestDispatch Function 

function ClosestDispatch(p::DeploymentProblem, drivetime::DataFrame)
    candidates = Array(Vector{Int}, p.nregions)
    I = 1:p.nlocations
    for region in 1:p.nregions
        candidates[region] = I[vec(p.coverage[region,:])]
    end
    ClosestDispatch(drivetime, candidates)
end



struct AssignmentModel <: RedeployModel
           model::Gurobi.Model
           lambda::Float64

           hosp2stn::Matrix{Float64}
           stn2stn::Matrix{Float64}

           assignment::Vector{Int} # which location the ambulance is assigned to
           ambulances::Vector{Vector{Int}} # list of ambulances assigned to each location
           status::Vector{Symbol} # the current status of the ambulance
               # possible statuses: :available, :responding, :atscene, :conveying, :returning
           fromtime::Vector{Int} # the time it started the new status
           hospital::Vector{Int} # the hospital the ambulance is at (0 otherwise)

           soln::Vector{Float64} # buffer for storing dynamic assignment solutions
       end
       
function AssignmentModel(
        p::DeploymentProblem,
        available::Vector{Int},
        # utilization::Vector{Float64},
        hospitals::DataFrame,
        stations::DataFrame;
        lambda::Float64 = 100.0
    )

    nambulances = sum(available)
    nlocations = length(available)
    assignment = zeros(Int, nambulances)

    hosp2stn = convert(Matrix{Float64},
        hcat([hospitals[Symbol("stn$(i)_min")] for i in 1:nlocations]...)
    )
    stn2stn =  convert(Matrix{Float64},
        hcat([stations[Symbol("stn$(i)_min")] for i in 1:nlocations]...)
    )

    k = 1
    ambulances = [Int[] for i in 1:nlocations]
    for i in eachindex(available), j in 1:available[i]
        assignment[k] = i
        push!(ambulances[i], k)
        k += 1
    end
    @assert k == nambulances + 1

    @assert sum(length(a) for a in ambulances) == nambulances
    status = fill(:available, nambulances)
    fromtime = zeros(Int, nambulances)
    hospital = zeros(Int, nambulances)

    m = Gurobi.Model(Gurobi.Env(), "redeploy", :minimize)
    Gurobi.setparam!(m, "OutputFlag", 0)
    for a in 1:nambulances, i in 1:nlocations # w variables
        Gurobi.add_bvar!(m, 0.)
    end
    for i in 1:nlocations # eta1
        Gurobi.add_cvar!(m, 0., -Inf, Inf)
    end
    for a in 1:nambulances, i in 1:nlocations # eta2 variables
        Gurobi.add_cvar!(m, lambda, 0., Inf)
    end
    for i in 1:nlocations # eta3 := eta1^2
        Gurobi.add_cvar!(m, 1., 0., Inf)
    end

    # η₁[i] >= available[i] - sum(w[a,i] for a in 1:nambulances)
    #     reformulated to
    # sum(w[a,i] for a in 1:nambulances) + η₁[i] >= available[i]
    for i in 1:nlocations
            Gurobi.add_constr!(m,
                   [((1:nambulances).-1)*nlocations.+i; nambulances*nlocations + i], # inds
                   ones(nambulances + 1), # coeffs
                   '>', Float64(available[i]))
           end

    ## repaired with dot syntax 

    # sum(w[a,i] for i in 1:nlocations) == 1       [a=1:nambulances]
    for a in 1:nambulances
        Gurobi.add_constr!(m,
            collect((a-1)*nlocations .+ (1:nlocations)), # inds
            ones(nlocations), # coeffs
            '=', 1.)
    end

    # eta2[a,i] >= |w[a,i] - (assignment[a] == i)|   [a=1:nambulances, i=1:nlocations]
    #     reformulated to
    # eta2[a,i] >= w[a,i] - (assignment[a] == i)   i.e. eta2[a,i] - w[a,i] >= -(assignment[a] == i)
    # eta2[a,i] >= - w[a,i] + (assignment[a] == i) i.e. eta2[a,i] + w[a,i] >=  (assignment[a] == i)
    for a in 1:nambulances, i in 1:nlocations
        offset = (a-1)*nlocations + i
        inds = [(nambulances+1)*nlocations + offset, offset]
        Gurobi.add_constr!(m, inds, [1., -1.], '>', - Float64(assignment[a] == i))
        Gurobi.add_constr!(m, inds, [1., 1.], '>', Float64(assignment[a] == i))
    end

    # eta3[i] = eta1[i]^2
    #     reformulated into
    # eta3[i] >= 0
    # eta3[i] >= 1 + 2*eta1[i]
    # eta3[i] >= 4 + 4*eta1[i]
    # eta3[i] >= 9 + 6*eta1[i]
    # ...
    for i in 1:nlocations
        for k in 0.1:0.1:0.9
            Gurobi.add_constr!(m,
                [2*nambulances*nlocations + nlocations + i, nambulances*nlocations + i], # inds
                [1., -2*k], # coeffs
                '>', Float64(k^2))
        end
        for k in 1:3
            Gurobi.add_constr!(m,
                [2*nambulances*nlocations + nlocations + i, nambulances*nlocations + i], # inds
                [1., -Float64(2*k)], # coeffs
                '>', Float64(k^2))
        end
    end

    AssignmentModel(m, lambda, hosp2stn, stn2stn, assignment, ambulances,
                    status, fromtime, hospital, zeros(nambulances*nlocations))
end


redeploy = AssignmentModel(p, x, hospitals, stations, lambda=Float64(lambda))
