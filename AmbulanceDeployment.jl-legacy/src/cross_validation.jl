#Author: Joshua Ong
#Summary run robust with same number of ambualnce, different alpha values, different training sets to see when the model
#1) saturates 2) performs best

using DelimitedFiles
using AmbulanceDeployment

include("single_robust.jl")

alpha_list = [.1,.05,.01,.001,.0001]
cross_validation = [1,2,3]

scenarios = Dict{String, Dict{Int, Vector{Vector{Int}}}}()
generated_deployment = Dict{String, Dict{Int, Vector{Vector{Int}}}}()
upperbounds = Dict{String, Dict{Int, Vector{Float64}}}()
upptiming = Dict{String, Dict{Int, Vector{Float64}}}()
lowtiming = Dict{String, Dict{Int, Vector{Float64}}}()
amb_deployment = Dict{String, Dict{Int, Vector{Int}}}()

namb = 40

for j in cross_validation
    for i in alpha_list
        name = "robust" * string(i)

        model = generate_robust(i, 40, j) #alpha,namb,cross_validation

        scenarios[name] = Dict()
        generated_deployment[name] = Dict()
        upperbounds[name] = Dict()
        upptiming[name] = Dict()
        lowtiming[name] = Dict()
        scenarios[name][namb] = model.scenarios
        generated_deployment[name][namb] = model.deployment
        upperbounds[name][namb] = model.upperbounds
        upptiming[name][namb] = model.upptiming
        lowtiming[name][namb] = model.lowtiming

        filename = "cross" * string(j) * "robust" * string(i) * ".csv"
        print(filename)
        writedlm(filename,  deployment(model), ',')
    end
end
