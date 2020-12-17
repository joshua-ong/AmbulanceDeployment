using JLD, Plots

solverstats = JLD.load("team_stats.jld")
amb_deployment = solverstats["amb_deployment"]

results = Array{Int,2}(undef, 6, 35)
for i = 1:35
           results[1,i] = amb_deployment[:Stochastic][:25][i]
           results[2,i] = amb_deployment[:Stochastic][:30][i]
           results[3,i] = amb_deployment[:Stochastic][:35][i]
           results[4,i] = amb_deployment[:Stochastic][:40][i]
           results[5,i] = amb_deployment[:Stochastic][:45][i]
           results[6,i] = amb_deployment[:Stochastic][:50][i]
end

plot(1:35, adjoint(results[:,:]),xticks= 1:1:35,legend = :outertopleft,title = "Stochastic Deployment", xtickfont = font(6,"Courier","Bold"), label = ["25" "30" "35" "40" "45" "50"])
xlabel!("StationId")
ylabel!("Ambulances Deployed")

savefig("stochasticDeployment.png")

response_times = JLD.load("response_times.jld")
