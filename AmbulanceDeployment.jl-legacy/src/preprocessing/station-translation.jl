using Distributions, JLD, CSV, DataFrames,Pkg, DataStructures


austin_stations_pre = CSV.File("raw/austin-stations.csv") |> DataFrame

# Yeesian has his coords in 3-stations.csv in this string format:
# "GeoInterface.Point([-77.00514742400335,38.83089499410552])"
formatted_coordinates = [string("GeoInterface.Point([", austin_stations_pre["LONGITUDE"][i], ", ", austin_stations_pre["LATITUDE"][i], "])") for i in 1:size(austin_stations_pre["LONGITUDE"], 1)]


austin_stations_post = DataFrame(geometry = formatted_coordinates,
                                 OBJECTID_1 = austin_stations_pre["OBJECTID_1"]
                                 )

CSV.write("formatted/austin_stations_formatted.csv", austin_stations_post)
