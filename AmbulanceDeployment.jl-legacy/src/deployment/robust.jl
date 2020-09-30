type Gamma
    _single::Vector{Int}
    _local::Vector{Int}
    _regional::Vector{Int}
    _global::Int
end

type Qrobust
    m::JuMP.Model
    I::UnitRange{Int}
    J::UnitRange{Int}
    d::Vector{JuMP.Variable}
    q::Vector{JuMP.Variable}
    γ::Gamma
end

type RobustDeployment <: DeploymentModel
    m::JuMP.Model
    Q::Qrobust

    I::UnitRange{Int}
    J::UnitRange{Int}

    x::Vector{JuMP.Variable}
    y::Vector{Matrix{JuMP.Variable}}
    z::Vector{Vector{JuMP.Variable}}
    η::JuMP.Variable

    scenarios::Vector{Vector{Int}}
    upperbounds::Vector{Float64}
    lowerbounds::Vector{Float64}
    deployment::Vector{Vector{Int}}

    upptiming::Vector{Float64}
    lowtiming::Vector{Float64}
end
deployment(m::RobustDeployment) = m.deployment[end]

function Gamma(p::DeploymentProblem; α=params.α)
    demand = p.demand[p.train,:]
    γ_single = vec(maximum(demand,1) + 1*(maximum(demand,1) .== 0))
    γ_local = [quantile(Poisson(mean(sum(demand[:,vec(p.adjacency[i,:])], 2))),1-α) for i=1:p.nregions]
    γ_regional = [quantile(Poisson(mean(sum(demand[:,p.coverage[:,i]],2))),1-α) for i in 1:p.nlocations]
    γ_global = quantile(Poisson(mean(sum(demand,2))),1-α)
    Gamma(γ_single,γ_local,γ_regional,γ_global)
end

function Qrobust(problem::DeploymentProblem; α=params.α, verbose=false,
    solver=GurobiSolver(OutputFlag=0, MIPGapAbs=0.9)) #, TimeLimit=30))
    if verbose
        solver=GurobiSolver(OutputFlag=1) #, MIPGapAbs=0.9)
    end
    γ = Gamma(problem, α=α)
    upp_bound = maximum(γ._single)
    I = 1:problem.nlocations
    J = 1:problem.nregions

    m = JuMP.Model(solver=solver)
    JuMP.@variable(m, d[1:problem.nregions]>=0, Int)
    JuMP.@variable(m, p[1:problem.nregions], Bin)
    JuMP.@variable(m, q[1:problem.nlocations], Bin)

    for i in I, j in J
        problem.coverage[j, i] && JuMP.@constraint(m, p[j] <= q[i])
    end

    # Uncertainty
    for j in J
        JuMP.@constraint(m, d[j] <= γ._single[j]*p[j])
        adjacent_regions = filter(k->problem.adjacency[k,j],J)
        JuMP.@constraint(m, sum(d[k] for k in adjacent_regions) <= γ._local[j])
    end
    for i in I
        covered_regions = filter(j->problem.coverage[j,i],J)
        JuMP.@constraint(m, sum(d[j] for j in covered_regions) <= γ._regional[i])
    end
    JuMP.@constraint(m, sum(d[j] for j in J) <= γ._global)

    Qrobust(m, I, J, d, q, γ)
end

function evaluate{T <: Real}(Q::Qrobust, x::Vector{T})
    JuMP.@objective(Q.m, Max, sum(Q.d[j] for j in Q.J) - sum(x[i]*Q.q[i] for i in Q.I))
    status = JuMP.solve(Q.m)
    JuMP.getobjectivevalue(Q.m), Int[round(Int,d) for d in JuMP.getvalue(Q.d)]
end

function evaluate_objvalue{T <: Real}(Q::Qrobust, x::Vector{T})
    JuMP.@objective(Q.m, Max, sum(Q.d[j] for j in Q.J) - sum(x[i]*Q.q[i] for i in Q.I))
    status = JuMP.solve(Q.m)
    JuMP.getobjectivevalue(Q.m)
end

function RobustDeployment(p::DeploymentProblem; α=params.α, eps=params.ε, tol=params.δ,
    solver=GurobiSolver(OutputFlag=0, MIPGapAbs=0.9), verbose=false, master_verbose=false)
    if master_verbose
        solver=GurobiSolver(OutputFlag=1, MIPGapAbs=0.9)
    end
    I = 1:p.nlocations
    J = 1:p.nregions

    warmstart = naive_solution(p)

    m = JuMP.Model(solver=solver)
    JuMP.@variable(m, x[i=1:p.nlocations] >= 0, Int, start=warmstart[i])
    JuMP.@variable(m, η >= 0)
    y = Vector{Matrix{JuMP.Variable}}()
    z = Vector{JuMP.Variable}()

    # Initial Restricted Master Problem
    JuMP.@objective(m, Min, η)
    JuMP.@constraint(m, sum(x[i] for i=I) <= p.nambulances)
    for j in J # coverage over all regions
        JuMP.@constraint(m, sum(x[i] for i in filter(i->p.coverage[j,i], I)) >= 1)
    end

    RobustDeployment(m, Qrobust(p, α=α, verbose=verbose), I, J, x, y, z, η,
                     Vector{Vector{Int}}(), Vector{Float64}(), Vector{Float64}(),
                     Vector{Int}[warmstart], Vector{Float64}(), Vector{Float64}())
end

function add_scenario{T <: Real}(model::RobustDeployment, p::DeploymentProblem, scenario::Vector{T}; tol=params.δ)
    # Create variables yˡ
    push!(model.y, Array(JuMP.Variable, (p.nlocations,p.nregions)))
    l = length(model.y)
    for i in model.I, j in model.J
        model.y[l][i,j] = JuMP.Variable(model.m, 0, p.nambulances, :Int, String("y[$i,$j,$l]"))
    end
    push!(model.z, Array(JuMP.Variable, p.nregions))
    for j in model.J
        model.z[l][j] = JuMP.Variable(model.m, 0, Inf, :Int, String("z[$j,$l]"))
    end

    # (1) η >= 1ᵀ(dˡ + Bᴶyˡ)^+
    JuMP.@constraint(model.m, model.η >= sum(model.z[l][j] for j=model.J) + tol*sum(model.y[l][i,j] for i=model.I, j=model.J))
    for i in model.I # flow constraints at each station
        JuMP.@expression(m, outflow, sum(model.y[l][i,j] for j in filter(j->p.coverage[j,i], model.J)))
        JuMP.@constraint(model.m, model.x[i] >= outflow)
    end
    # (2) yˡ ∈ Y(x)
    for j in model.J # shortfall from satisfying demand/calls
        JuMP.@expression(m, inflow, sum(model.y[l][i,j] for i in filter(i->p.coverage[j,i], model.I)))
        JuMP.@constraint(model.m, model.z[l][j] >= scenario[j] - inflow)
    end
end

function solve(model::RobustDeployment, p::DeploymentProblem; verbose=false, maxiter=params.maxiter, eps=params.ε)
    LB = 0.0
    UB, scenario = evaluate(model.Q, model.deployment[end])
    push!(model.lowerbounds, LB)
    push!(model.upperbounds, UB)
    push!(model.scenarios, scenario)

    for k in 1:maxiter
        verbose && println("iteration $k: LB $LB, UB $UB")
        abs(UB - LB) < eps && break
        verbose && println("  solving Q with $(model.deployment[end])")

        add_scenario(model, p, scenario)
        tic()
        status = JuMP.solve(model.m)
        push!(model.lowtiming, toq())
        @assert status == :Optimal

        LB = JuMP.getobjectivevalue(model.m)

        push!(model.deployment, [round(Int,x) for x in JuMP.getvalue(model.x)])

        tic()
        shortfall, scenario = evaluate(model.Q, model.deployment[end])
        push!(model.upptiming, toq())
        UB = min(UB, shortfall)

        # for tracking convergence later
        push!(model.upperbounds, UB)
        push!(model.scenarios, scenario)
        push!(model.lowerbounds, LB)
    end
end