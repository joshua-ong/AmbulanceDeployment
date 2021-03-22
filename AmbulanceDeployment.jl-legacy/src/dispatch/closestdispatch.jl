#=
Author : Ng Yeesian
Modified : Guy Farmer / Zander Tedjo / Will Worthington
generates the closest dispatch model
=#
struct ClosestDispatch <: DispatchModel
    drivetime::DataFrame
    candidates::Vector{Vector{Int}}
end

function ClosestDispatch(p::DeploymentProblem, drivetime::DataFrame)
    candidates = Any[]
    I = 1:p.nlocations
    for region in 1:p.nregions
        push!(candidates, I[vec(p.coverage[region,:])])
    end
    ClosestDispatch(drivetime, candidates)
end

function ClosestDispatch(p::DeploymentProblem, problem::DispatchProblem)
    stn_names = [Symbol("stn$(i)_min") for i in 1:size(p.coverage,2)]
    ClosestDispatch(p, problem.emergency_calls[:, stn_names])
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
