#=
Author : Ng Yeesian
Modified : Guy Farmer / Zander Tedjo / Will Worthington / Michael Hilborn
generates the closest dispatch model
=#
mutable struct ClosestDispatch <: DispatchModel
    drivetime::DataFrame
    candidates::Vector{Vector{Int}}
    available::Vector{Int}
    assignment::Vector{Int} # which location the ambulance is assigned to
    ambulances::Vector{Vector{Int}} # list of ambulances assigned to each location
    status::Vector{Symbol} # the current status of the ambulance
        # possible statuses: :available, :responding, :atscene, :conveying, :returning
    fromtime::Vector{Int} # the time it started the new status
    hospital::Vector{Int}
end

function ClosestDispatch(p::DeploymentProblem, drivetime::DataFrame,distribution::Vector{Int})
    candidates = Any[]
    I = 1:p.nlocations
    for region in 1:p.nregions
        push!(candidates, I[vec(p.coverage[region,:])])
    end

    assignment = zeros(Int, p.nambulances)
    ambulances = [Int[] for i in 1:p.nlocations]
    k = 1
    for i in eachindex(distribution), j in 1:distribution[i]
        assignment[k] = i
        push!(ambulances[i], k)
        k += 1
    end
    status = fill(:available, p.nambulances)
    fromtime = zeros(Int, p.nambulances)
    hospital = zeros(Int, p.nambulances)

    ClosestDispatch(drivetime, candidates, distribution, assignment, ambulances, status, fromtime, hospital)

end

function ClosestDispatch(p::DeploymentProblem, problem::DispatchProblem)
    stn_names = [Symbol("stn$(i)_min") for i in 1:size(p.coverage,2)]
    ClosestDispatch(p, problem.emergency_calls[:, stn_names], problem.available)
end

function update_ambulances!(model::ClosestDispatch, i::Int, delta::Int)
    model.available[i] += delta
    @assert model.available[i] >= 0
end

function closest_available(dispatch::ClosestDispatch, id::Int, problem::DispatchProblem)
    location = 0
    min_time = Inf
    for i in dispatch.candidates[problem.emergency_calls[id, :neighborhood]]
        if problem.available[i] > 0 && dispatch.drivetime[id, i] < min_time
            location = i
            min_time = dispatch.drivetime[id, i]
        end
    end
    location
end

function respond_to!(dispatch::ClosestDispatch, i::Int, t::Int)
    @assert length(dispatch.ambulances[i]) > 0 "$i: $(dispatch.ambulances[i])"
    amb = popfirst!(dispatch.ambulances[i])
    @assert amb != 0
    @assert dispatch.status[amb] == :available "$amb: $(dispatch.status[amb])"
    dispatch.status[amb] = :responding
    amb
end

function arriveatscene!(dispatch::ClosestDispatch, amb::Int, t::Int)
    @assert dispatch.status[amb] == :responding "$amb: $(dispatch.status[amb])"
    @assert dispatch.hospital[amb] == 0
    dispatch.status[amb] = :atscene
    dispatch.fromtime[amb] = t
end

function arriveathospital!(dispatch::DispatchModel, amb::Int, hosp::Int, t::Int)
    @assert dispatch.status[amb] == :atscene "$amb: $(dispatch.status[amb])"
    @assert dispatch.hospital[amb] != 0
    dispatch.status[amb] = :atHospital
    dispatch.fromtime[amb] = t
    dispatch.hospital[amb] = hosp
end

function returning_to!(dispatch::DispatchModel, amb::Int, t::Int)
    @assert dispatch.status[amb] == :atHospital "$amb: $(dispatch.status[amb])"
    @assert dispatch.hospital[amb] != 0
    dispatch.status[amb] = :returning
    dispatch.fromtime[amb] = t
    dispatch.assignment[amb]
end
