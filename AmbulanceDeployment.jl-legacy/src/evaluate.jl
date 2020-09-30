function within{T <: Real}(scenario::Vector{T}, gamma::Gamma, p::DeploymentProblem)
    # returns true if scenario ∈ gamma; false otherwise
    if any(scenario .> gamma._single) 
        return false
    elseif sum(scenario) > gamma._global
        return false
    else
        for j in 1:p.nregions
            if sum(scenario[vec(p.adjacency[j,:])]) > gamma._local[j]
                return false
            end
        end
        for i in 1:p.nlocations
            if sum(scenario[p.coverage[:,i]]) > gamma._regional[i]
                return false
            end
        end
    end
    true
end

type Evaluation
    objvalue::Int
    shortfall::Vector{Int}
    dispatch::Matrix{Int}
end

function evaluate{T1, T2 <: Real}(x::Vector{T1}, scenario::Vector{T2}, p::DeploymentProblem;
    solver=GurobiSolver(OutputFlag=0,PrePasses=3))

    I = 1:p.nlocations
    J = 1:p.nregions

    m = JuMP.Model(solver=solver)
    JuMP.@variable(m, y[1:p.nlocations,1:p.nregions] >= 0, Int)
    JuMP.@variable(m, z[1:p.nregions] >= 0, Int)

    JuMP.@objective(m, Min, sum(z[j] for j in J))

    # flow constraints at each station
    for i in I
        JuMP.@expression(m, outflow, sum(y[i,j] for j in filter(j->p.coverage[j,i], J)))
        JuMP.@constraint(m, x[i] >= outflow)
    end
    # shortfall from satisfying demand/calls
    for j in J
        JuMP.@expression(m, inflow, sum(y[i,j] for i in filter(i->p.coverage[j,i], I)))
        JuMP.@constraint(m, z[j] >= scenario[j] - inflow)
    end
    status = JuMP.solve(m)
    @assert status == :Optimal

    Evaluation(Int(JuMP.getObjectiveValue(m)),
               [round(Int,z) for z in JuMP.getValue(z)],
               map(y->round(Int,y), JuMP.getValue(y)))
end

function evaluate{T <: Real}(x::Vector{T}, p::DeploymentProblem)
    Evaluation[evaluate(x,vec(p.demand[i,:]),p) for i in p.test]
end

type Result
    stoch_x
    robust_x
    bad_scenarios
    upperbounds
    lowerbounds
    stoch_timing
    robust_timing
end

function performance(p::DeploymentProblem, α::Float64; verbose=false)
    stoch_model = StochasticDeployment(p)
    tic()
    solve(stoch_model)
    stoch_timing = toq()
    robust_model = RobustDeployment(p, α=α, verbose=verbose, master_verbose=verbose)
    tic()
    solve(robust_model, p, verbose=verbose)
    robust_timing = toq()
    Result( deployment(stoch_model),
            deployment(robust_model),
            robust_model.scenarios,
            robust_model.upperbounds,
            robust_model.lowerbounds,
            stoch_timing,
            robust_timing)
end

function test_performance(p::DeploymentProblem; namb::Vector{Int}=[25:5:45], alpha::Vector{Float64}=[0.1,0.05,0.01,0.001,0.0001], verbose=false)
    results = Array(Result, (5,5))
    for (i,n) in enumerate(namb)
        print(n)
        p.nambulances = n
        stoch_model = StochasticDeployment(p)
        tic()
        solve(stoch_model)
        stoch_timing = toq()
        for (j,α) in enumerate(alpha)
            print(" $α")
            robust_model = RobustDeployment(p, α=α, verbose=verbose, master_verbose=verbose)
            tic()
            solve(robust_model, p, verbose=verbose)
            robust_timing = toq()
            results[i,j] = Result(  deployment(stoch_model),
                                    deployment(robust_model),
                                    robust_model.scenarios,
                                    robust_model.upperbounds,
                                    robust_model.lowerbounds,
                                    stoch_timing,
                                    robust_timing)
        end
        println("")
    end
    results
end

