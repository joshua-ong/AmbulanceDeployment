#=
Author : Ng Yeesian
Modified : none
Creates various dispatch models
=#

type RobustDispatch <: DispatchModel
    Q::Qrobust
    candidates::Vector{Vector{Int}}
    available::Vector{Int}
end

function RobustDispatch(p::DeploymentProblem,
                        available::Vector{Int},
                        solver=GurobiSolver(OutputFlag=0),
                        tol=params.δ)
    I = 1:p.nlocations
    candidates = Array(Vector{Int}, p.nregions)
    for region in 1:p.nregions
        candidates[region] = I[vec(p.coverage[region,:])]
    end
    RobustDispatch(Qrobust(p), candidates, available)
end

function update_ambulances!(model::RobustDispatch, i::Int, delta::Int)
    model.available[i] += delta
end

function available_for(model::RobustDispatch, j::Int, problem::DispatchProblem)
    qvalues = Vector{Float64}()
    for i in model.candidates[j]
        model.available[i] -= 1
        push!(qvalues, evaluate_objvalue(model.Q, model.available))
        model.available[i] += 1
    end
    for i in sortperm(qvalues)
        location = model.candidates[j][i]
        if problem.available[location] > 0 # send the most "desirable" one
            return location
        end
    end
    return 0 # if no ambulance is available
end

type StochasticDispatch <: DispatchModel
    m::JuMP.Model
    candidates::Vector{Vector{Int}}
    location::Vector{JuMP.ConstraintRef}
end

function StochasticDispatch(p::DeploymentProblem,
                            available::Vector{Int},
                            nperiods = params.nperiods,
                            solver = GurobiSolver(OutputFlag=0),
                            tol = params.δ)
    @assert sum(available) <= p.nambulances
    nperiods = min(length(p.train), nperiods)
    demand = vec(mean(p.demand[p.train,:],1))
    I = 1:p.nlocations
    J = 1:p.nregions
    T = 1:nperiods

    m = JuMP.Model(solver=solver)
    JuMP.@variable(m, y[1:p.nlocations,1:p.nregions,1:nperiods] >= 0, Int)
    JuMP.@variable(m, z[1:p.nregions,1:nperiods] >= 0, Int)

    JuMP.@objective(m, Min, sum(z[j,t] for j=J, t=T) + tol*sum(y[i,j,t] for i=I, j=J, t=T))

    location = Array(JuMP.ConstraintRef, p.nlocations)
    for t in T
        for i in I # flow constraints at each station
            JuMP.@expression(m, outflow, sum(y[i,j,t] for j in filter(j->p.coverage[j,i], J)))
            location[i] = JuMP.@constraint(m, outflow <= available[i])
        end
        for j in J # shortfall from satisfying demand/calls
            JuMP.@expression(m, inflow, sum(y[i,j,t] for i in filter(i->p.coverage[j,i], I)))
            JuMP.@constraint(m, z[j,t] >= demand[t,j] - inflow)
        end
    end

    candidates = Array(Vector{Int}, p.nregions)
    for j in J
        candidates[region] = I[vec(p.coverage[j,:])]
    end
    StochasticDispatch(m, candidates, location)
end

function update_ambulances!(model::StochasticDispatch, i::Int, delta::Int)
    constr = model.location[i]
    prev = JuMP.rhs(JuMP.LinearConstraint(constr))
    JuMP.chgConstrRHS(constr, prev + delta)
end

function available_for(model::StochasticDispatch, j::Int, problem::DispatchProblem)
    qvalues = Vector{Float64}()
    for i in model.candidates[j]
        constr = model.location[i]
        prev = JuMP.rhs(JuMP.LinearConstraint(constr))
        if prev > 0.5 # consider sending an ambulance only if it's available
            JuMP.chgConstrRHS(constr, prev - 1)
            status = JuMP.solve(model.m)
            @assert status == :Optimal
            push!(qvalues, JuMP.getObjectiveValue(model.m))
            JuMP.chgConstrRHS(constr, prev)
        else
            push!(qvalues, Inf)
        end
    end
    for i in sortperm(qvalues)
        location = model.candidates[j][i]
        if problem.available[location] > 0 # send the most "desirable" one
            return location
        end
    end
    return 0 # if no ambulance is available
end

type MEXCLPDispatch <: DispatchModel
    x::Vector{Int}  # nlocation
    candidates::Vector{Vector{Int}}
    q::Float64

    function MEXCLPDispatch(p::DeploymentProblem, available::Vector{Int}, q::Float64)
        I = 1:p.nlocations
        candidates = Array(Vector{Int}, p.nregions)
        for region in 1:p.nregions
            candidates[region] = I[vec(p.coverage[region,:])]
        end
        new(available, candidates, q)
    end
end

function update_ambulances!(model::MEXCLPDispatch, i::Int, delta::Int)
    model.x[i] += delta
end

#"the math says you'll return the location with the highest number of ambulances"
function available_for(model::MEXCLPDispatch, j::Int, problem::DispatchProblem)
    location = 0
    max_x = 0
    for i in model.candidates[j]
        if model.x[i] > max_x
            location = i
            max_x = model.x[i]
        end
    end
    location
end

type MALPDispatch{BM <: AbstractMatrix{Bool}} <: DispatchModel
    m::JuMP.Model
    available::Vector{Int}
    coverage::BM    # nregion x nlocation
    region::Vector{JuMP.ConstraintRef}
end

function MALPDispatch(p::DeploymentProblem,
                      available::Vector{Int},
                      q::Float64; # busy fraction
                      α::Float64 = 0.99, # reliability level
                      solver = GurobiSolver(OutputFlag=0))
    demand = vec(mean(p.demand[p.train,:],1))
    @assert length(demand) == p.nregions

    I = 1:p.nlocations
    J = 1:p.nregions
    b = ceil(Int, log(1-α)/log(q))

    m = JuMP.Model(solver=solver)
    JuMP.@variable(m, x[1:p.nlocations] >= 0, Int)
    JuMP.@variable(m, z[1:p.nregions, 1:b], Bin)

    JuMP.@objective(m, Max, sum(demand[j]*z[j,b] for j in J))

    JuMP.@constraint(m, sum(x[i] for i in I) <= p.nambulances)
    region = Array(JuMP.ConstraintRef, p.nregions)
    for j in J # coverage over all regions
        region_j = sum([available[i] for i in filter(i->p.coverage[j,i], I)])
        region[j] = JuMP.@constraint(m, sum(z[j,k] for k in 1:b) <= region_j)
        for k in 2:b
            JuMP.@constraint(m, z[j,k] <= z[j,k-1])
        end
    end

    MALPDispatch(m, available, p.coverage, region)
end

function update_ambulances!(model::MALPDispatch, i::Int, delta::Int)
    model.available[i] += delta
    @assert model.available[i] >= 0
    for j in 1:size(model.coverage,1)
        if model.coverage[j,i]
            constr = model.region[j]
            prev = JuMP.rhs(JuMP.LinearConstraint(constr))
            JuMP.chgConstrRHS(constr, prev + delta)
        end
    end
end

function available_for(model::MALPDispatch, j::Int, problem::DispatchProblem)
    location = 0
    max_q = 0.0
    for i in 1:size(model.coverage,2)
        if model.coverage[j,i] && model.available[i] > 0
            update_ambulances!(model, i, -1)
            status = JuMP.solve(model.m)
            @assert status == :Optimal
            qvalue = JuMP.getObjectiveValue(model.m)
            update_ambulances!(model, i, 1)
            if qvalue > max_q
                location = i
                max_q = qvalue
            end
        end
    end
    location
end
