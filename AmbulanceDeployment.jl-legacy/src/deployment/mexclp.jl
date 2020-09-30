type MEXCLPDeployment <: DeploymentModel
    m::JuMP.Model
    x::Vector{JuMP.Variable}
end
deployment(m::MEXCLPDeployment) = Int[round(Int,x) for x in JuMP.getvalue(m.x)]

function MEXCLPDeployment(p::DeploymentProblem,
                          q::Float64; # busy fraction
                          max_amb::Int = 0,
                          tol = params.δ,
                          solver = GurobiSolver(OutputFlag=0))
    (max_amb == 0) && (max_amb = p.nambulances)
    @assert max_amb > 0
    demand = vec(mean(p.demand[p.train,:],1))
    @assert length(demand) == p.nregions
    
    I = 1:p.nlocations
    J = 1:p.nregions
    K = 1:max_amb

    m = JuMP.Model(solver=solver)
    JuMP.@variable(m, x[1:p.nlocations] >= 0, Int)
    JuMP.@variable(m, z[1:p.nregions, 1:max_amb], Bin)

    JuMP.@objective(m, Max, sum(demand[j]*(1-q)*(q^k)*z[j,k] for j in J, k in K))

    JuMP.@constraint(m, sum(x[i] for i in I) <= p.nambulances)

    for j in J # coverage over all regions
        JuMP.@constraint(m, sum(x[i] for i in filter(i->p.coverage[j,i], I)) >= 1)
        JuMP.@constraint(m, sum(x[i] for i in filter(i->p.coverage[j,i], I)) >=
                            sum(z[j,k] for k in K))
    end

    MEXCLPDeployment(m, x)
end

solve(model::MEXCLPDeployment) = JuMP.solve(model.m)
solve(model::MEXCLPDeployment, p::DeploymentProblem) = JuMP.solve(model.m)
