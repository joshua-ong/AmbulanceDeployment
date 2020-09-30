type DSMDeployment <: DeploymentModel
    m::JuMP.Model
    x::Vector{JuMP.Variable}
end
deployment(m::StochasticDeployment) = [round(Int,x) for x in JuMP.getValue(m.x)]

function DSMDeployment(p::DeploymentProblem,
                          q::Float64; # busy fraction
                          max_amb::Int = 5
                          tol = params.δ,
                          solver = GurobiSolver(OutputFlag=0))
    demand = mean(p.demand[p.train,:],1)
    @assert length(demand) == problem.nregions
    I = 1:p.nlocations
    J = 1:problem.nregions
    K = 1:max_amb

    m = JuMP.Model(solver=solver)
    JuMP.@variable(m, x[1:p.nlocations] >= 0, Int)
    JuMP.@variable(m, z[1:p.nregions, 1:max_amb] >= 0, Bin)

    JuMP.@objective(m, Min, sum((1-q)*(q^k)*demand[j]*z[j,k] for j=J, k=K))

    JuMP.@constraint(m, sum(x[i] for i=I) <= p.nambulances)
    for j in J # coverage over all regions
        JuMP.@constraint(m, sum(x[i] for i in filter(i->p.coverage[j,i], I)) >= sum(z[j,k] for k=1:K))
    end

    DSMDeployment(m, x)
end

solve(model::DSMDeployment) = JuMP.solve(model.m)
solve(model::DSMDeployment, p::DeploymentProblem) = JuMP.solve(model.m)