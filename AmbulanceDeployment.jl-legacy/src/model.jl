#=
Author : Ng Yeesian
Modified : Guy Farmer / Zander Tedjo / Michael Hilborn
defines various deployment and dispatch models and functions that will be run on them
=#
# using Gurobi
abstract type DeploymentModel end

abstract type DispatchModel end

#=function respond_to!(redeploy::RedeployModel, i::Int, t::Int)
    @assert length(redeploy.ambulances[i]) > 0 "$i: $(redeploy.ambulances[i])"
    amb = popfirst!(redeploy.ambulances[i])
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
=#
