#=
Author : Ng Yeesian
Modified : Joshua Ong / Guy Farmer
generates the stochastic deployment model
=#
struct StochasticDeployment_hyp <: DeploymentModel
    m::JuMP.Model
    x::Vector{JuMP.VariableRef}
    y::Array{JuMP.VariableRef,3}
    slack::Vector{JuMP.VariableRef}
end
deployment(m::StochasticDeployment_hyp) = [round(Int,x) for x in JuMP.value.(m.x)]

function StochasticDeployment_hyp(p::DeploymentProblem; nperiods=params.nperiods, tol=params.δ,
    solver=Gurobi.Optimizer(OutputFlag=0), extra_amb = 1)

    old_x = [1, 1, 1, 2, 0, 0, 1, 2, 2, 0, 2, 0, 0, 1, 2, 2, 1, 2, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 2, 1, 1, 1, 1, 0, 1, 0, 0, 1, 1, 1, 0, 2, 1]
    nperiods = min(length(p.train), nperiods)
    demand = p.demand[p.train,:]
    I = 1:p.nlocations
    J = 1:p.nregions
    T = 1:nperiods

    m = Model(GLPK.Optimizer) #using GLPK
    JuMP.@variable(m, x[1:p.nlocations] >= 0, Int)
    JuMP.@variable(m, y[1:p.nlocations,1:p.nregions,1:nperiods] >= 0, Int)
    JuMP.@variable(m, z[1:p.nregions,1:nperiods] >= 0, Int)
    JuMP.@variable(m, slack[1:p.nlocations] >= 0, Int) #slack variable

    JuMP.@objective(m, Min, sum(z[j,t] for j=J, t=T) + tol*sum(y[i,j,t] for i=I, j=J, t=T));

    JuMP.@constraint(m, sum(x[i] for i=I) <= p.nambulances + extra_amb);

    #ensure new solution is within slack of the old x.
    for i in I #collect(1:44)
        JuMP.@constraint(m, x[i] - slack[i] == old_x[i]);
    end
    JuMP.@constraint(m, sum(slack[i] for i in I) == extra_amb) #make sure slack is the +/- n ambulances of the old solution

    #Guarantees coverage for all regions
    for j in J
        JuMP.@constraint(m, sum(x[i] for i in filter(i->p.coverage[j,i], I)) >= 1);
    end

    # flow constraints at each station
    for i in I, t in T
        outflow = JuMP.@expression(m, sum(y[i,j,t] for j in filter(j->p.coverage[j,i], J)));
        JuMP.@constraint(m, x[i] >= outflow);
    end

    # shortfall from satisfying demand/calls
    for j in J, t in T
        inflow = JuMP.@expression(m, sum(y[i,j,t] for i in filter(i->p.coverage[j,i], I)));
        JuMP.@constraint(m, z[j,t] >= demand[t,j] - inflow);
    end

    # any location can only house so many hospitals
    for i in I
        JuMP.@constraint(m, x[i] <= 5);
    end

    StochasticDeployment_hyp(m, x, y, slack)
end

#status = JuMP.optimize!(model.m)
optimize!(model::StochasticDeployment_hyp) = JuMP.optimize!(model.m)
optimize!(model::StochasticDeployment_hyp, p::DeploymentProblem) = JuMP.optimize!(model.m)
