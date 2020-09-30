using AmbulanceDeployment, DataFrames, JLD, Distributions

turnaround = Distributions.LogNormal(3.65, 0.3)
ncalls = 1000
namb = 30
lambda = 0

hourly_calls = DataFrames.readtable("data/processed/2-weekday_calls.csv")
# weekend_hourly_calls = DataFrames.readtable("data/processed/2-weekend_calls.csv")
adjacent_nbhd = DataFrames.readtable("data/processed/2-adjacent_nbhd.csv")
coverage = JLD.load("data/processed/3-coverage.jld", "stn_coverage")
hospitals = DataFrames.readtable("data/processed/3-hospitals.csv");
stations = DataFrames.readtable("data/processed/3-stations.csv");

solverstats = JLD.load("data/processed/4-solve-stats.jld")
amb_deployment = solverstats["amb_deployment"]
const model_names = (:Stochastic, :Robust01, :Robust005, :Robust001, :Robust0001, :Robust00001, :MEXCLP, :MALP)
name = model_names[1]
x = amb_deployment[name][namb]

p = DeploymentProblem(
    hourly_calls,
    adjacent_nbhd,
    coverage,
    namb = namb,
    train_filter = (hourly_calls[:year] .== 2012) .* (hourly_calls[:month] .<= 3)
)

# We focus on emergency calls during the "peak period" (8AM - 8PM),
# with the emergency calls from the first 3 month as our training set,
# and the subsequent emergency calls from the remaining months as our test set

# calls = DataFrames.readtable("data/processed/5-calls.csv");
# inc_test_filter  = !((calls[:year] .== 2012) .* (calls[:month] .<= 3))
# test_calls = calls[(1:nrow(calls))[inc_test_filter][1:ncalls],:];
test_calls = DataFrames.readtable("test_calls.csv")

problem = DispatchProblem(test_calls, hospitals, stations, p.coverage, x, turnaround=turnaround)
dispatch = ClosestDispatch(p, problem)
redeploy = AssignmentModel(p, x, hospitals, stations, lambda=Float64(lambda))

# id 145 dispatch to nbhd 88
srand(1234) # reset seed
@time df = simulate_events!(problem, dispatch, redeploy)
@show mean(df[:waittime]), maximum(df[:waittime])
@show mean(df[:waittime] + df[:responsetime])

# julia> mean(df[:responsetime])
# 8.34253333333334

test_calls = DataFrames.readtable("influx_calls.csv");

problem = DispatchProblem(test_calls, hospitals, stations, p.coverage, x, turnaround=turnaround);
dispatch = ClosestDispatch(p, problem);
redeploy = AssignmentModel(p, x, hospitals, stations, lambda=Float64(lambda));

# id 145 dispatch to nbhd 88
srand(1234); # reset seed
@time df = simulate_events!(problem, dispatch, redeploy);
@show mean(df[:waittime]), maximum(df[:waittime])
@show mean(df[:waittime] + df[:responsetime])