using Distributions, JLD, CSV, DataFrames,Pkg, DataStructures


austin_stations_pre = CSV.File("raw/austin-hospitals.csv") |> DataFrame

# Yeesian has his coords in 3-stations.csv in this string format:
# "GeoInterface.Point([-77.00514742400335,38.83089499410552])"
formatted_coordinates = [string("GeoInterface.Point([", austin_stations_pre["longitude"][i], ", ", austin_stations_pre["latitude"][i], "])") for i in 1:size(austin_stations_pre["longitude"], 1)]


austin_stations_post = DataFrame(geometry = formatted_coordinates,
                                 name = austin_stations_pre["hospital_names"]
                                 )

CSV.write("formatted/austin_hospitals_formatted.csv", austin_stations_post)
