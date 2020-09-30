abstract DeploymentModel

abstract DispatchModel

abstract RedeployModel
    # Interface
    # =========
    # assignment::Vector{Int} # which location the ambulance is assigned to
    # ambulances::Vector{Vector{Int}} # list of ambulances assigned to each location
    # status::Vector{Int} # the current status of the ambulance
    # fromtime::Vector{Int} # the time it started the new status
    # hospital::Vector{Int} # the hospital the ambulance is at (0 otherwise)

    # MUST IMPLEMENT
    # reassign_ambulances!(ems, problem::DispatchProblem, redeploy::DeployModel, t::Int)

function respond_to!(redeploy::RedeployModel, i::Int, t::Int)
    @assert length(redeploy.ambulances[i]) > 0 "$i: $(redeploy.ambulances[i])"
    amb = shift!(redeploy.ambulances[i])
    # @assert redeploy.hospital[amb] == 0
    @assert amb != 0
    @assert redeploy.status[amb] == :available "$amb: $(redeploy.status[amb])"
    redeploy.status[amb] = :responding
    redeploy.fromtime[amb] = t
    amb
end

function arriveatscene!(redeploy::RedeployModel, amb::Int, t::Int)
    @assert redeploy.status[amb] == :responding "$amb: $(redeploy.status[amb])"
    @assert redeploy.hospital[amb] == 0
    redeploy.status[amb] = :atscene
    redeploy.fromtime[amb] = t
end

function conveying!(redeploy::RedeployModel, amb::Int, hosp::Int, t::Int)
    @assert redeploy.status[amb] == :atscene "$amb: $(redeploy.status[amb])"
    @assert redeploy.hospital[amb] != 0
    redeploy.status[amb] = :conveying
    redeploy.fromtime[amb] = t
    redeploy.hospital[amb] = hosp
end

function returning_to!(redeploy::RedeployModel, amb::Int, t::Int)
    @assert redeploy.status[amb] == :conveying "$amb: $(redeploy.status[amb])"
    @assert redeploy.hospital[amb] != 0
    redeploy.status[amb] = :returning
    redeploy.fromtime[amb] = t
    redeploy.assignment[amb]
end

function redeploying_to!(redeploy::RedeployModel, amb::Int, i::Int, t::Int)
    # DEBUG:
    println("redeploying amb $amb from $(redeploy.assignment[amb]) to $i")
    ambulances = redeploy.ambulances[redeploy.assignment[amb]]
    @assert !in(amb, redeploy.ambulances[i])
    @assert in(amb, ambulances)
    deleteat!(ambulances, findfirst(ambulances, amb))
    @assert !in(amb, ambulances)
    redeploy.assignment[amb] = i
    redeploy.status[amb] = :redeploying
    redeploy.fromtime[amb] = t
end

function returned_to!(redeploy::RedeployModel, amb::Int, t::Int)
    @assert in(redeploy.status[amb], (:returning, :redeploying)) "$amb: $(redeploy.status[amb])"
    redeploy.hospital[amb] = 0
    redeploy.status[amb] = :available
    redeploy.fromtime[amb] = t
    @assert !in(amb, redeploy.ambulances[redeploy.assignment[amb]])
    push!(redeploy.ambulances[redeploy.assignment[amb]], amb)
end

function redirected!(redeploy::RedeployModel, amb::Int, t::Int)
    @assert in(redeploy.status[amb], (:returning, :redeploying)) "$amb: $(redeploy.status[amb])"
    redeploy.hospital[amb] = 0
    redeploy.status[amb] = :responding
    redeploy.fromtime[amb] = t
end

include("deployment/robust.jl")
include("deployment/stochastic.jl")
include("deployment/mexclp.jl")
include("deployment/malp.jl")

include("dispatch/closestdispatch.jl")
#include("dispatch/dispatch.jl") # unused

include("redeployment/assignment.jl")
include("redeployment/noredeploy.jl")
