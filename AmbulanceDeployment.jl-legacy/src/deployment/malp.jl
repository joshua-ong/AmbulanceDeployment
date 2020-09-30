type MALPDeployment <: DeploymentModel
    m::JuMP.Model
    x::Vector{JuMP.Variable}
end
deployment(m::MALPDeployment) = Int[round(Int,x) for x in JuMP.getValue(m.x)]

function MALPDeployment(p::DeploymentProblem,
                        q::Float64; # busy fraction;
                        α::Float64 = 0.99, # reliability level
                        tol = params.δ,
                        solver = GurobiSolver(OutputFlag=0))
    demand = vec(mean(p.demand[p.train,:],1))
    @assert length(demand) == p.nregions
    
    I = 1:p.nlocations
    J = 1:p.nregions
    b = ceil(Int, log(1-α)/log(q))

    m = JuMP.Model(solver=solver)
    JuMP.@variable(m, x[1:p.nlocations] >= 0, Int)
    JuMP.@variable(m, z[1:p.nregions, 1:b], Bin)

    JuMP.@objective(m, Max, sum(demand[j]*z[j,b], j in J))

    JuMP.@constraint(m, sum(x[i] for i in I) <= p.nambulances)
    for j in J # coverage over all regions
        JuMP.@constraint(m, sum(x[i] for i in filter(i->p.coverage[j,i], I)) >= 1)
        JuMP.@constraint(m, sum(x[i] for i in filter(i->p.coverage[j,i], I)) >= sum(z[j,k] for k in 1:b))
        for k in 2:b
            JuMP.@constraint(m, z[j,k] <= z[j,k-1])
        end
    end

    MALPDeployment(m, x)
end

solve(model::MALPDeployment) = JuMP.solve(model.m)
solve(model::MALPDeployment, p::DeploymentProblem) = JuMP.solve(model.m)
