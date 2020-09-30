import Gadfly: lab_gradient
import GeoInterface: coordinates
import GeoConverters: composeform
import Winston: FramedPlot, Curve, Legend, setattr, add
import Colors: LCHab, Colorant
import Compose: Polygon, UnitBox, context, compose, linewidth
import Compose: stroke, fill, mm, circle

function convergence_plot(robust_model::RobustDeployment)
    fp = FramedPlot(title="Bounds", xlabel="iteration", ylabel="shortfall")
    n = length(robust_model.upperbounds)
    upperbound = Curve(1:n, robust_model.upperbounds, color="red")
    setattr(upperbound, label="upperbound")
    lowerbound = Curve(1:n, robust_model.lowerbounds, color="blue")
    setattr(lowerbound, label="lowerbound")
    legend = Legend(.8,.9, Curve[upperbound, lowerbound])
    add(fp,upperbound, lowerbound, legend)
    fp
end

function plot_timings(results:: Matrix{Result})
    fp = Winston.FramedPlot(
        title="Solve Time (Robust)",
        xlabel="Number of Ambulances",
        ylabel="runtime (seconds)"
    )
    α₁ = Curve(25:5:45, Float64[results[i,1].robust_timing for i=1:5], color="yellow")
    setattr(α₁, label="α=0.1")
    α₂ = Curve(25:5:45, Float64[results[i,2].robust_timing for i=1:5], color="orange")
    setattr(α₂, label="α=0.05")
    α₃ = Curve(25:5:45, Float64[results[i,3].robust_timing for i=1:5], color="red")
    setattr(α₃, label="α=0.01")
    α₄ = Curve(25:5:45, Float64[results[i,4].robust_timing for i=1:5], color="purple")
    setattr(α₄, label="α=0.001")
    α₅ = Curve(25:5:45, Float64[results[i,5].robust_timing for i=1:5], color="blue")
    setattr(α₅, label="α=0.0001")
    l = Legend(.8, .9, Curve[α₁, α₂, α₃, α₄, α₅])
    add(fp, α₁, α₂, α₃, α₄, α₅, l)
    fp
end

function compose_neighborhoods(
        df::DataFrame,
        colname::Symbol;
        fill_color::AbstractString = "blue",
        stroke_color::AbstractString = "black"
    )
    dims = UnitBox(-77.116634,38.99596,0.207479,-0.19287) # WashingtonDC
    template = context(units=dims)
    c = template
    grad = lab_gradient(parse(Colorant, "white"),parse(Colorant, fill_color))
    minv = minimum(df[colname])
    maxv = maximum(df[colname])
    for (row,p) in enumerate(df[:geometry])
        v = Float64(isna(df[row,colname]) ? 0.0 : df[row,colname])
        proportion = (v-minv)/(maxv-minv)
        c = compose(c,compose(
            template,
            composeform(p),
            linewidth(0.05mm),
            stroke(parse(Colorant, stroke_color)),
            fill(grad(proportion))
        ))
    end
    c
end

function compose_neighborhoods{T <: Real}(
        df::DataFrame,
        values::Vector{T};
        fill_color::AbstractString = "blue",
        stroke_color::AbstractString = "black"
    )
    dims = UnitBox(-77.116634,38.99596,0.207479,-0.19287) # WashingtonDC
    template = context(units=dims)
    c = template
    grad = lab_gradient(parse(Colorant, "white"),parse(Colorant, fill_color))
    minv = minimum(values)
    maxv = maximum(values)
    for (row,p) in enumerate(df[:geometry])
        v = values[row]
        proportion = (v-minv)/(maxv-minv)
        c = compose(c,compose(
            template,
            composeform(p),
            linewidth(0.05mm),
            stroke(parse(Colorant, stroke_color)),
            fill(grad(proportion))
        ))
    end
    c
end

function compose_neighborhoods_nominal{T <: Real}(
        df::DataFrame,
        values::Vector{T};
        fill_color::AbstractString = "blue",
        stroke_color::AbstractString = "black"
    )
    dims = UnitBox(-77.116634,38.99596,0.207479,-0.19287) # WashingtonDC
    template = context(units=dims)
    c = template
    grad = lab_gradient(parse(Colorant, "white"),parse(Colorant, fill_color))
    for (row,p) in enumerate(df[:geometry])
        c = compose(c, compose(
            template,
            composeform(p),
            linewidth(0.05mm),
            stroke(parse(Colorant, stroke_color)),
            fill(grad(values[row]))
        ))
    end
    c
end

function compose_locations(
        df::DataFrame;
        nambs=[0.001],
        fill_color=LCHab(78, 84, 29)
    )
    template = context(units=UnitBox(-77.116634,38.99596,0.207479,-0.19287)) # WashingtonDC
    compose(template, compose(
        template,
        circle([coordinates(p)[1] for p in df[:geometry]],
               [coordinates(p)[2] for p in df[:geometry]], nambs),
        fill(fill_color)
    ))
end

function compose_chloropleth{T <: Real}(
        location_df::DataFrame,
        region_df::DataFrame,
        values::Vector{T},
        regions::Vector{Int};
        nambs = [1],
        fill_color::AbstractString = "blue",
        stroke_color::AbstractString = "black"
    )
    result = zeros(217)
    result[regions] = values
    location_c = compose_locations(location_df, nambs=sqrt(nambs)*0.0015)
    region_c = compose_neighborhoods(
        region_df,
        result,
        fill_color=fill_color,
        stroke_color=stroke_color
    )
    compose(location_c, region_c)
end

