module AmbulanceDeployment

    import JuMP, Gurobi
    import DataStructures: PriorityQueue, enqueue!, dequeue!
    import DataFrames: DataFrame, isna, nrow
    import Distributions: Poisson, LogNormal, quantile, sample
    import Pkg
    #import JLD, Query, CSV, CPLEX
    import CSV, JLD, Query
    using Gurobi, CSV, JLD, Query, JuMP
    Pkg.resolve()
    include("model.jl")
    include("dispatch/closestdispatch.jl")
    include("problem.jl")
    include("simulate.jl")
    include("evaluate.jl")
    include("plot.jl")
    #include("../test/runtests.jl")



    export
           DeploymentProblem,
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

end
