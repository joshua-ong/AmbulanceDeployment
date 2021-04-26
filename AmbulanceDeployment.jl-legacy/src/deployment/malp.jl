#=
Author : Ng Yeesian
Modified : Guy Farmer
generates the Maximum Availability Location Problem model
=#
struct MALPDeployment <: DeploymentModel
    m::JuMP.Model
    x::Vector{JuMP.VariableRef}
end
deployment(m::MALPDeployment) = Int[round(Int,x) for x in JuMP.value.(m.x)]

function MALPDeployment(p::DeploymentProblem,
                        q::Float64; # busy fraction;
                        α::Float64 = 0.99, # reliability level
                        tol = params.δ,
                        solver = Gurobi.Optimizer(OutputFlag=0))
    demand = vec(mean(p.demand[p.train,:],dims = 1))
    @assert length(demand) == p.nregions

    I = 1:p.nlocations
    J = 1:p.nregions
    b = ceil(Int, log(1-α)/log(q))

    m = Model(GLPK.Optimizer)
    solver=Gurobi.Optimizer(OutputFlag=0)
    JuMP.@variable(m, x[1:p.nlocations] >= 0, Int)
    JuMP.@variable(m, z[1:p.nregions, 1:b], Bin)


    #possible breaking change with for j in J
    JuMP.@objective(m, Max, sum(demand[j]*z[j,b] for j in J))

    JuMP.@constraint(m, sum(x[i] for i in I) <= p.nambulances)
    for j in J # coverage over all regions
        JuMP.@constraint(m, sum(x[i] for i in filter(i->p.coverage[j,i], I)) >= 1)
        JuMP.@constraint(m, sum(x[i] for i in filter(i->p.coverage[j,i], I)) >= sum(z[j,k] for k in 1:b))
        for k in 2:b
            JuMP.@constraint(m, z[j,k] <= z[j,k-1])
        end
    end
    for i in I
        JuMP.@constraint(m, x[i] <= 5)
    end

    MALPDeployment(m, x)
end

optimize!(model::MALPDeployment) = JuMP.optimize!(model.m)
optimize!(model::MALPDeployment, p::DeploymentProblem) = JuMP.optimize!(model.m)
