type NoRedeployModel <: RedeployModel
    assignment::Vector{Int} # which location the ambulance is assigned to
    ambulances::Vector{Vector{Int}} # list of ambulances assigned to each location
    status::Vector{Symbol} # the current status of the ambulance
        # possible statuses: :available, :responding, :atscene, :conveying, :returning
    fromtime::Vector{Int} # the time it started the new status
    hospital::Vector{Int} # the hospital the ambulance is at (0 otherwise)
end

function NoRedeployModel(
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

    NoRedeployModel(assignment, ambulances, status, fromtime, hospital)
end

reassign_ambulances!(ems, problem::DispatchProblem, redeploy::NoRedeployModel, t::Int) = nothing
