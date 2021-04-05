#Author Joshua
#Summary This is a condensed version of Ambulance Deployment Experiment
#
#Updated 12=17

 using AmbulanceDeployment
# using DataFrames, Winston, JLD, CSV, Gurobi, JuMP

isfile("../test/data/processed/2-weekday_calls.csv")
hourly_calls = CSV.File("../test/data/processed/2-weekday_calls.csv") |> DataFrame
adjacent_nbhd = CSV.File("../test/data/processed/2-adjacent_nbhd.csv") |> DataFrame
coverage = JLD.load("../test/data/processed/3-coverage.jld", "stn_coverage")
namb = 30

p = DeploymentProblem(
    hourly_calls,
    adjacent_nbhd,
    coverage,
    namb = namb,
    train_filter = (hourly_calls[!,:year] .== 2012) .* (hourly_calls[!,:month] .<= 3)
)

a = MALPDeployment(p,.9)

set_optimizer(a.m, Gurobi.Optimizer)
optimize!(a)
