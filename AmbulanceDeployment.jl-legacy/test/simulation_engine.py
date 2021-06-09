import numpy as np
import queue

import problem

# params
ncalls = 10

local_path = "C:/Users/Owner/Documents/Austin/PythonAmbulanceDepolyment/AmbulanceDeployment/AmbulanceDeployment.jl-legacy/test"

hospitals = np.genfromtxt(local_path + "/austin-data/hospitals.csv", delimiter=",")
stations = np.genfromtxt(local_path + "/austin-data/stations.csv", delimiter=",")
# hourly_calls = np.genfromtxt(local_path + "/austin-data/Full_WeekdayCalls.csv", delimiter=",")
# s_hourly_calls = np.genfromtxt(local_path + "/austin-data/Full_WeekdayCalls.csv", dtype=str, delimiter=",")
test_calls = np.genfromtxt(local_path + "/austin-data/austin_test_calls_update1.csv",
                           delimiter=",")  # update 1: remove negative indices
s_test_calls = np.genfromtxt(local_path + "/austin-data/austin_test_calls_update1.csv",
                             delimiter=",", dtype=str)  # update 1: remove negative indices
test_calls = test_calls[1:ncalls, :]

adjacent_nbhd = np.genfromtxt(local_path + "/austin-data/adjacent_nbhd.csv", delimiter=",")
coverage = np.genfromtxt(local_path + "/austin-data/coverage_real.csv", delimiter=",")

p1 = problem.problem(test_calls, adjacent_nbhd, coverage, 40)
print("files loaded")


class simulation_engine:
    def __init__(self):
        self.wings = 2
        self.eventqueue = queue.PriorityQueue()

    ## generates the priority queue and instantiates the EMSEngine struct
    def generateCalls(self, hourly_calls, ncalls=9):
        t = 0
        for i in range(1, ncalls):  # https://pythonguides.com/priority-queue-in-python/ pq tutorial
            event_type = "call"
            id = i
            t = t + test_calls[i, 0]
            nbhd = test_calls[i, 1]
            details = [event_type, id, t, nbhd]
            self.eventqueue.put(details, t)  # [type of emergency, id?, time, neighborhood], time priority
        return

def call_event(engine, problem, dispatch, id, t, value):
    return

def simulate_events(p1, debug_flag = True):
    "This prints a passed string into this function"
    se = simulation_engine()
    se.generateCalls(p1.hourly_calls)
    print("started from the bottomw")
    while not se.eventqueue.empty():
        item = se.eventqueue.get()
        print(item)
        event, id, t, nbhd = item
        if event == "call":
            if debug_flag:
                print("calling event id: " + str(id) + "time: " + str(t) + "neighborhood: " + str(nbhd))
            #call_event!(engine, problem, dispatch, id, t, value)
        elif event == "call":
            continue
        elif event == "call":
            continue
        elif event == "call":
            continue
        elif event == "call":
            continue
    return


simulate_events(p1)
