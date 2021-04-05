#=
Author : Guy Farmer
converts the austin_team_stats.jld file into a json file which can be parseable in python
=#
# using JLD, JSON

solverstats = JLD.load("austin_team_stats.jld")
amb_deployment = solverstats["amb_deployment"]
json_string = JSON.json(amb_deployment)
open("../src/outputs/austin_amb_deployment.json","w") do f
    write(f, json_string)
end
