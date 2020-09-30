type StochasticDeployment <: DeploymentModel
    m::JuMP.Model
    x::Vector{JuMP.Variable}
end
deployment(m::StochasticDeployment) = [round(Int,x) for x in JuMP.getvalue(m.x)]

function StochasticDeployment(p::DeploymentProblem; nperiods=params.nperiods, tol=params.δ,
    solver=GurobiSolver(OutputFlag=0))

    nperiods = min(length(p.train), nperiods)
    demand = p.demand[p.train,:]
    I = 1:p.nlocations
    J = 1:p.nregions
    T = 1:nperiods

    m = JuMP.Model(solver=solver)
    JuMP.@variable(m, x[1:p.nlocations] >= 0, Int)
    JuMP.@variable(m, y[1:p.nlocations,1:p.nregions,1:nperiods] >= 0, Int)
    JuMP.@variable(m, z[1:p.nregions,1:nperiods] >= 0, Int)

    JuMP.@objective(m, Min, sum(z[j,t] for j=J, t=T) + tol*sum(y[i,j,t] for i=I, j=J, t=T))

    JuMP.@constraint(m, sum(x[i] for i=I) <= p.nambulances)

    for j in J # coverage over all regions
        JuMP.@constraint(m, sum(x[i] for i in filter(i->p.coverage[j,i], I)) >= 1)
    end

    # flow constraints at each station
    for i in I, t in T
        JuMP.@expression(m, outflow, sum(y[i,j,t] for j in filter(j->p.coverage[j,i], J)))
        JuMP.@constraint(m, x[i] >= outflow)
    end

    # shortfall from satisfying demand/calls
    for j in J, t in T
        JuMP.@expression(m, inflow, sum(y[i,j,t] for i in filter(i->p.coverage[j,i], I)))
        JuMP.@constraint(m, z[j,t] >= demand[t,j] - inflow)
    end

    StochasticDeployment(m, x)
end

solve(model::StochasticDeployment) = JuMP.solve(model.m)
solve(model::StochasticDeployment, p::DeploymentProblem) = JuMP.solve(model.m)