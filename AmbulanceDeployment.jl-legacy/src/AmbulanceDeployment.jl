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
    import CSV, JLD, Query
    using Gurobi, CSV, JLD, Query, JuMP, Dates
    using DataFrames, Distributions, CSV, Random, Plots,JSON
    #Pkg.resolve()
    include("problem.jl")
    include("model.jl")
    include("dispatch/closestdispatch.jl")
    include("simulate.jl")
    include("evaluate.jl")
    include("plot.jl")
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
           simulate_events!

end
