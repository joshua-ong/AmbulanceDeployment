#=
Author : Ng Yeesian
Modified : Guy Farmer
generates the Maximum Expected Coverage Location Problem model
=#
struct MEXCLPDeployment <: DeploymentModel
    m::JuMP.Model
    x::Vector{JuMP.VariableRef}
end
deployment(m::MEXCLPDeployment) = Int[round(Int,x) for x in JuMP.value.(m.x)]

function MEXCLPDeployment(p::DeploymentProblem,
                          q::Float64; # busy fraction
                          max_amb::Int = 0,
                          tol = params.δ,
                          solver = Gurobi.Optimizer(OutputFlag=0))
    (max_amb == 0) && (max_amb = p.nambulances)
    @assert max_amb > 0
    #demand = vec(mean(p.demand[p.train,:],1))
    demand = vec(mean(p.demand[p.train,:],dims = 1))
    @assert length(demand) == p.nregions

    I = 1:p.nlocations
    J = 1:p.nregions
    K = 1:max_amb

    #m = JuMP.Model(solver=solver)
    m = Model(GLPK.Optimizer)
    solver=Gurobi.Optimizer(OutputFlag=0, MIPGapAbs=0.9)
    JuMP.@variable(m, x[1:p.nlocations] >= 0, Int)
    JuMP.@variable(m, z[1:p.nregions, 1:max_amb], Bin)

    JuMP.@objective(m, Max, sum(demand[j]*(1-q)*(q^k)*z[j,k] for j in J, k in K))

    JuMP.@constraint(m, sum(x[i] for i in I) <= p.nambulances)

    for j in J # coverage over all regions
        JuMP.@constraint(m, sum(x[i] for i in filter(i->p.coverage[j,i], I)) >= 1)
        JuMP.@constraint(m, sum(x[i] for i in filter(i->p.coverage[j,i], I)) >=
                            sum(z[j,k] for k in K))
    end
    for i in I
        JuMP.@constraint(m, x[i] <= 5)
    end
    MEXCLPDeployment(m, x)
end

optimize!(model::MEXCLPDeployment) = JuMP.optimize!(model.m)
optimize!(model::MEXCLPDeployment, p::DeploymentProblem) = JuMP.optimize!(model.m)
