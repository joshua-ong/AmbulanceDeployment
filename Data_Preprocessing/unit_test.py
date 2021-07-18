# -*- coding: utf-8 -*-
"""
Spyder Editor

This is a temporary script file.
"""

import numpy as np
import json
import math
import collections
import seaborn as sns
import matplotlib.pyplot as plt


# This is the grid object, which is used throughout all data preprocessing.
# It represents the city of Austin through a series of grids.
# It thus makes a tractable way to compute distance between grids, ect. 
class Grid():
    def __init__(self, grid_json):
        self.grid = grid_json
        self.min_lat = self.grid["latitude_min"]
        self.min_lon = self.grid["longitude_min"]
        self.max_lat = self.grid["latitude_max"]
        self.max_lon = self.grid["longitude_max"]
        self.latitude_delta = self.grid["latitude_step"]
        self.longitude_delta = self.grid["longitude_step"]
        self.nrows = math.ceil((self.max_lat - self.min_lat) / self.latitude_delta)
        self.ncols = math.ceil((self.max_lon - self.min_lon) / self.longitude_delta)
        self.times = self.grid["time_matrix"]
        self.census_tract_region_map = self.grid["census_tract_region_mapping"]
        self.region_to_tract = collections.defaultdict(list)
        for census_tract in self.census_tract_region_map:
            for region in self.census_tract_region_map[census_tract]:
                self.region_to_tract[region].append(census_tract)
    def map_point_to_region(self, latitude, longitude):
        return math.floor((latitude-self.min_lat)/self.latitude_delta) * self.ncols  + math.floor((longitude-self.min_lon)/self.longitude_delta)
    def get_representative(self, region_num):
        row_num = region_num//self.ncols
        col_num = region_num - row_num*self.ncols
        lat = self.min_lat + row_num * self.latitude_delta + 0.5*self.latitude_delta
        lon = self.min_lon + col_num * self.longitude_delta + 0.5*self.longitude_delta
        return [lon, lat]
    def get_time(self, region1, region2):
        try:
            return self.times[region1][region2]
        except IndexError:
            return -1
    def region_to_census_tract(self, region):
        try:
            return self.region_to_tract[region]
        except KeyError:
            return "0_0"

#the adjacent neighborhoods should be the same as the number of grid neighborhoods
def unit_test_adjacent_file_size(g, a_n): 
    if len(g_lil.times) != a_n.shape[0]:
        raise AssertionError("adjacent_neighborhood file is the wrong size")
    print("unit_test_adjacent_file_size passed")

#input: c,c2 two coverage matrices    
def unit_test_compare_coverage_percentage(c, c2): 
    c_coverage = np.sum(c) / (c.shape[0] * c.shape[1])
    c2_coverage = np.sum(c2) / (c2.shape[0] * c2.shape[1])
    print("c coverage = " + str(c_coverage))    
    print("c2 coverage = " + str(c2_coverage))    
    return

#input: g1, g2 two travel matrices. 
def unit_test_compare_travel_times(g, g2): 
    g_times = np.array(g.times)
    g_times = g_times.flatten()
    g2_times = np.array(g2.times)
    g2_times = g2_times.flatten()
    sns.kdeplot(data = g_times , label="g1")
    sns.kdeplot(g2_times, label="g2")
    plt.show()
    return


# Using old distance matrix to get an idea of how close we are (?)
with open("../Input_Data/grid_info_3200_v2.json", "r") as f:
    grid_json = json.load(f)
g_big = Grid(grid_json)

# Using old distance matrix to get an idea of how close we are (?)
with open("../Input_Data/grid_info_smaller.json", "r") as f:
    grid_json = json.load(f)
g_lil = Grid(grid_json)

adjacent_210 = (np.genfromtxt("../Output_Data/austin_data/adjacent_nbhd.csv", delimiter=",", dtype = str))
adjacent_3200 = (np.genfromtxt("../Output_Data/austin_data_3200/adjacent_nbhd.csv", delimiter=",", dtype = str))

coverage_210 = (np.genfromtxt("../Output_Data/austin_data/coverage.csv", delimiter=","))
coverage_210 = coverage_210[1:,1:] #take off header row and column.
coverage_3200_r = (np.genfromtxt("../Output_Data/austin_data_3200/coverage_regression.csv", delimiter=","))
coverage_3200_r = coverage_3200_r[1:,1:] 

# unit_test_adjacent_file_size(g_lil, adjacent_210)
unit_test_compare_coverage_percentage(coverage_210,coverage_3200_r)
#unit_test_compare_travel_times(g_lil,g_big) #takes a long time to flatten
  
print("hello world")