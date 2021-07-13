#=
Author : Ng Yeesian
Modified : Guy Farmer
generates the AmbulanceDeployment package
=#
module AmbulanceDeployment

    import JuMP, Gurobi
    import DataStructures: PriorityQueue, enqueue!, dequeue!
    import DataFrames: DataFrame, nrow
    import Distributions
    import DataStructures: PriorityQueue, enqueue!, dequeue!
    import Pkg
    import CSV, Query
    using Gurobi, CSV, Query, JuMP, Dates, JLD, GLPK
    using DataFrames, CSV, Random, JSON, Distributions #Plots


    const PROJECT_ROOT = pkgdir(AmbulanceDeployment)

    include("problem.jl")
    include("model.jl")
    include("dispatch/closestdispatch.jl")
    include("simulate.jl")
    include("evaluate.jl")
    include(PROJECT_ROOT * "/test/generate_simulation.jl")
    include("deployment/robust.jl")
    include("deployment/stochastic.jl")
    include("deployment/malp.jl")
    include("deployment/mexclp.jl")
    include("plot.jl")
    #include("Ambulance_Deployment_experiments.jl")
    include("Single_Robust.jl")

    export
           DeploymentProblem,
           DispatchProblem,
           RobustDeployment,
           StochasticDeployment,
           MALPDeployment,
           MEXCLPDeployment,
           ClosestDispatch,
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
           optimize!,
           generate_deployment

end
