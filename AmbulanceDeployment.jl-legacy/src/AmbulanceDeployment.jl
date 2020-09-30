module AmbulanceDeployment

    import JuMP, Gurobi
    import Base.Collections: PriorityQueue, enqueue!, dequeue!
    import DataFrames: DataFrame, isna, nrow
    import Distributions: Poisson, LogNormal, quantile, sample

    export DeploymentProblem,
           RobustDeployment,
           StochasticDeployment,
           MALPDeployment,
           MEXCLPDeployment,

           DispatchProblem,
           ClosestDispatch,

           NoRedeployModel,
           AssignmentModel,

           solve,
           evaluate,
           deployment,
           convergence_plot,
           compose_neighborhoods,
           compose_locations,
           compose_chloropleth,
           performance,
           test_performance,
           plot_timings,
           simulate_events!,
           initialize!

    include("problem.jl")
    include("model.jl")
    include("simulate.jl")

    include("evaluate.jl")
    include("plot.jl")
end