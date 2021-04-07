#=
Author : Ng Yeesian
Modified : Guy Farmer
generates the AmbulanceDeployment package
=#
module AmbulanceDeployment

    import JuMP, Gurobi
    import DataStructures: PriorityQueue, enqueue!, dequeue!
    import DataFrames: DataFrame, nrow
    import Distributions: Poisson, LogNormal, quantile, sample, Random
    import DataStructures: PriorityQueue, enqueue!, dequeue!
    import Pkg
    #import JLD, Query, CSV, CPLEX
    import CSV, Query
    using Gurobi, CSV, Query, JuMP, Dates, JLD, GLPK
    using DataFrames, Distributions, CSV, Random, Plots,JSON
    #Pkg.resolve()

    const PROJECT_ROOT = pkgdir(AmbulanceDeployment)

    include("problem.jl")
    include("model.jl")
    include("dispatch/closestdispatch.jl")
    include("simulate.jl")
    include("evaluate.jl")
    include("plot.jl")
    include("../test/generate_simulation.jl")
    include("deployment/robust.jl")
    #include("problem.jl")
    #include("../test/runtests.jl")



    export
           DeploymentProblem,
           DispatchProblem,
           RobustDeployment,
           StochasticDeployment,
           MALPDeployment,
           MEXCLPDeployment,
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
           generate_simulation,
           PROJECT_ROOT,
           optimize!

end
