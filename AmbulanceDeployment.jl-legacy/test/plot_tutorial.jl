#https://www.math.purdue.edu/~allen450/Plotting-Tutorial.html
#=
Author : Joshua Ong
Modified : none
small plotting tutorial for julia
=#
using Plots
x = 1:10; y = rand(10,2);
z = rand(10) # These are the plotting data
plot(x, y)
