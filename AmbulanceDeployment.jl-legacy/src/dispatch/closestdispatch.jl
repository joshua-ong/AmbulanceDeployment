#=
Author : Ng Yeesian
Modified : Guy Farmer / Zander Tedjo / Will Worthington
generates the closest dispatch model
=#
struct ClosestDispatch <: DispatchModel
    drivetime::DataFrame
    candidates::Vector{Vector{Int}}
    available::Vector{Int}
    assignment::Vector{Int} # which location the ambulance is assigned to
    ambulances::Vector{Vector{Int}} # list of ambulances assigned to each location
end

function ClosestDispatch(p::DeploymentProblem, drivetime::DataFrame,distribution::Vector{Int})
    candidates = Any[]
    I = 1:p.nlocations
    for region in 1:p.nregions
        push!(candidates, I[vec(p.coverage[region,:])])
    end
    println("creating the dispatch problem :$distribution")

    assignment = zeros(Int, nambulances)
    ambulances = [Int[] for i in 1:nlocations]
    k = 1
    for i in eachindex(available), j in 1:available[i]
        assignment[k] = i
        push!(ambulances[i], k)
        k += 1
    end
    ClosestDispatch(drivetime, candidates, distribution)

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
            println("apparently this station is available : $i and here is the amount of ambulances avalable: $(problem.available[i])")
            location = i
            min_time = dispatch.drivetime[id, i]
        end
    end
    location
end
