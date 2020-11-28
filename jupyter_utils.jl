using OpenStreetMapParser
using GeoJSON, GeoConverters
using Geodesy
using KDTrees

import GeoInterface
import DataArrays
import Colors: LCHab, Colorant
import Compose: Polygon, UnitBox, context, compose, linewidth
import Compose: stroke, fill, mm, circle
import Gadfly: lab_gradient

"returns osm id"
function nearby_nodes(nodes::Vector{OpenStreetMapParser.Node},
                      indices::Vector{Int},
                      pt::Tuple{Float64,Float64}, dist::Float64 = 0.1)
    results = Vector{Int}()
    for i in indices
        if OpenStreetMapParser.distance(pt, nodes[i].lonlat) < dist # within 100 metres
            push!(results, nodes[i].id)
        end
    end
    results
end

function nearby_nodes(nodes::Vector{OpenStreetMapParser.Node},
                      pt::Tuple{Float64,Float64}, dist::Float64 = 0.1)
    results = Vector{Int}()
    for i in 1:length(nodes)
        if OpenStreetMapParser.distance(pt, nodes[i].lonlat) < dist # within 100 metres
            push!(results, nodes[i].id)
        end
    end
    results
end

function nearest_node(nodes::Vector{OpenStreetMapParser.Node},
                      indices::Vector{Int},
                      pt::Tuple{Float64,Float64})
    i = indices[1]
    result = nodes[i].id
    shortest_dist = OpenStreetMapParser.distance(pt, nodes[i].lonlat)
    for n in 2:length(indices)
        dist = OpenStreetMapParser.distance(pt, nodes[i].lonlat)
        if dist < shortest_dist
            result = osm.nodes[i].id
            shortest_dist = dist
        end
    end
    result, dist
end

# Only supports 2D geometries for now

# pt is [x,y] and ring is [[x,y], [x,y],..]
function inring{T1,T2}(pt::Vector{T1}, ring::Vector{Vector{T2}})
    intersect(i::Vector{T2},j::Vector{T2}) = 
        (i[2] >= pt[2]) != (j[2] >= pt[2]) && (pt[1] <= (j[1] - i[1]) * (pt[2] - i[2]) / (j[2] - i[2]) + i[1])
    isinside = intersect(ring[1], ring[end])
    for k=2:length(ring)
        isinside = intersect(ring[k], ring[k-1]) ? !isinside : isinside
    end
    isinside
end

function inring{T1,T2}(pt::Tuple{T1,T1}, ring::Vector{Vector{T2}})
    intersect(i::Vector{T2},j::Vector{T2}) = 
        (i[2] >= pt[2]) != (j[2] >= pt[2]) && (pt[1] <= (j[1] - i[1]) * (pt[2] - i[2]) / (j[2] - i[2]) + i[1])
    isinside = intersect(ring[1], ring[end])
    for k=2:length(ring)
        isinside = intersect(ring[k], ring[k-1]) ? !isinside : isinside
    end
    isinside
end

# pt is [x,y] and polygon is [ring, [ring, ring, ...]]
function inpolygon{T1,T2}(pt::Vector{T1}, polygon::Vector{Vector{Vector{T2}}})
    if !inring(pt, polygon[1]) # check if it is in the outer ring first
        return false
    end
    for poly in polygon[2:end] # check for the point in any of the holes
        if inring(pt,poly)
            return false
        end
    end
    true
end

function inpolygon{T1,T2}(pt::Tuple{T1,T1}, polygon::Vector{Vector{Vector{T2}}})
    if !inring(pt, polygon[1]) # check if it is in the outer ring first
        return false
    end
    for poly in polygon[2:end] # check for the point in any of the holes
        if inring(pt,poly)
            return false
        end
    end
    true
end

function inmultipolygon{T1,T2}(pt::Tuple{T1,T1}, multipolygon::Vector{Vector{Vector{Vector{T2}}}})
    any(map(x->(inpolygon(pt,x)),multipolygon))
end

function driving_times(g::OpenStreetMapParser.Network, start_locations::Vector{Int})
    LightGraphs.dijkstra_shortest_paths(g.g, Int[g.node_id[n] for n in start_locations], g.distmx).dists
end

function stn2nbhd_coverage(closest_nodes::Vector{Vector{Int}},
                           nodes::Vector{OpenStreetMapParser.Node},
                           geometries::DataArrays.DataVector{GeoInterface.AbstractGeometry};
                           verbose::Bool=true)
    coverage = Array(Vector{Int}, length(closest_nodes))
    for stn in 1:length(coverage)
        verbose && print("$stn: ")
        coverage[stn] = Vector{Int}()
        covered_indices = (1:length(nodes))[driving_times(g, closest_nodes[stn]) .< 8/60]
        for (nbhd_i,nbhd) in enumerate(geometries)
            for i in randperm(length(covered_indices))
                if inmultipolygon(nodes[covered_indices[i]].lonlat,
                                  GeoInterface.coordinates(nbhd))
                    verbose && print("$nbhd_i ")
                    push!(coverage[stn],nbhd_i)
                    break
                end
            end
        end
        verbose && println("")
    end
    coverage
end

function compose_polygons(plist; fill_color="grey", stroke_color="white")
    dims = UnitBox(-77.116634,38.99596,0.207479,-0.19287) # WashingtonDC
    template = context(units=dims)
    c = template
    for p in plist
        c = compose(c,compose(template, composeform(p), linewidth(0.05mm),
                              stroke(Base.parse(Colorant,stroke_color)),
                              fill(Base.parse(Colorant,fill_color))))
    end
    c
end

coords(g::OpenStreetMapParser.Network, nodes::Vector{OpenStreetMapParser.Node}, i::Int) =
    nodes[g.node_id[i]].lonlat::Tuple{Float64,Float64}

function closest_coords(g::OpenStreetMapParser.Network, nodes::Vector{OpenStreetMapParser.Node}, stn::Int)
    Tuple{Float64,Float64}[coords(g, nodes, i) for i in closest_nodes[stn]]
end

function compose_stn_coverage(stn::Int,
                              g::OpenStreetMapParser.Network, 
                              nodes::Vector{OpenStreetMapParser.Node},
                              closest_nodes::Vector{Vector{Int}},
                              coverage::Vector{Vector{Int}},
                              stn_geometry::DataArrays.DataVector{GeoInterface.AbstractGeometry},
                              nbhd_geometry::DataArrays.DataVector{GeoInterface.AbstractGeometry})
    dims = UnitBox(-77.116634,38.99596,0.207479,-0.19287) # WashingtonDC
    template = context(units=dims)
    
    coords = GeoInterface.coordinates(stn_geometry[stn])
    xy = reinterpret(Float64, [nodes[g.node_id[i]].lonlat for i in closest_nodes[stn]])
    x = xy[1:2:end]; y = xy[2:2:end]
    cnodes = Tuple{Float64,Float64}[nodes[i].lonlat for i in (1:length(nodes))[driving_times(g, closest_nodes[stn]) .< 8/60]]
    vals = reinterpret(Float64, cnodes)
    
    compose(compose(template,compose(template,circle(coords[1:1], coords[2:2], [0.001]), fill("black"))),
            compose(template,compose(template,circle(x, y, [0.001]), fill("red"))),
            compose(template,compose(template,circle(vals[1:2:end], vals[2:2:end], [0.0001]), fill("orange"))),
            compose_polygons(nbhd_geometry[coverage[stn]], fill_color="grey", stroke_color="white"),
            compose_polygons(nbhd_geometry[setdiff(1:length(nbhd_geometry), coverage[stn])], fill_color="white", stroke_color="black"))
end

function lla_bounds(incident_pts::Vector{Geodesy.LLA})
    values = reinterpret(Float64, incident_pts)
    lons = values[1:3:end]
    lats = values[2:3:end]
    Geodesy.Bounds(minimum(lons), maximum(lons), minimum(lats), maximum(lats))
end

"returns the transformed points"
lla2enu(incident_pts::Vector{Geodesy.LLA}, center::Geodesy.LLA) =
    Geodesy.ENU[Geodesy.ENU(p, center) for p in incident_pts]

"returns the transformed points, and the center point"
function lla2enu(incident_pts::Vector{Geodesy.LLA})
    c = Geodesy.center(lla_bounds(incident_pts))
    lla2enu(incident_pts, c), c
end

function osm2enu_kdtree(nodes::Vector{OpenStreetMapParser.Node}, center_lla::Geodesy.LLA)
    osm_points = lla2enu(Geodesy.LLA[Geodesy.LLA(nodes[i].lonlat...) for i in eachindex(nodes)], center_lla)
    KDTrees.KDTree(reshape(reinterpret(Float64, osm_points), 3, length(nodes)))
end

"returns the shortest driving time from any of the start nodes in minutes"
function shortest_times(start_nodes::Vector{Int},
                        g::OpenStreetMapParser.Network,
                        nodes::KDTrees.KDTree{Float64},
                        highway_nodes::Vector{Int},
                        incident_points::Vector{Vector{Float64}})
    ncalls = length(incident_points)
    dists = driving_times(g, start_nodes)
    timings = Array(Float64, ncalls)
    for i in 1:ncalls
        pt = incident_points[i]
        timings[i] = minimum([dists[highway_nodes[p]] for p in knn(nodes, incident_points[i], 5)[1]]) * 60
    end
    timings
end

# function shortest_times(start_locations, # closest_nodes[stn]
#                         g::OpenStreetMapParser.Network,
#                         incident_points::Vector{Vector{Int}})
#     ncalls = length(incident_points)
#     dists = driving_times(g, start_locations)
#     timings = Array(Float64, ncalls)
#     for i in 1:ncalls
#         pt = incident_points[i]
#         try
            
#             timings[i] = minimum([dists[g.node_id[p]] for p in nearby_nodes(pt)])
#             catch
#             try
#                 timings[i] = 
#             catch
#                 println(i, " ", nearby_nodes(pt), " ", nearest_node(osm.nodes, highway_nodes, pt)[1])
#             end
#         end
#     end
#     timings
# end

# function shortest_times(stn, g, incident_points)
#     ncalls = length(incident_points)
#     dists = driving_times(g, closest_nodes[stn])
#     timings = Array(Float64, ncalls)
#     for i in 1:ncalls
#         pt = incident_points[i]
#         try
            
#             timings[i] = minimum([dists[g.node_id[p]] for p in nearby_nodes(pt)])
#             catch
#             try
#                 timings[i] = 
#             catch
#                 println(i, " ", nearby_nodes(pt), " ", nearest_node(osm.nodes, highway_nodes, pt)[1])
#             end
#         end
#     end
#     timings
# end
