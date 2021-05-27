# AmbulanceDeployement

![S_Map](https://github.com/michaelhilborn/AmbulanceDeployment/blob/master/results/stochastic50_map.png "Stochastic Mapping")

In 2019-2020, Austin EMS (Emergency Medical Service) served a total of 246,809 calls with an average of 338 calls per day with only 37 ambulances. In this repo we apply two-stage stochastic and robust linear programs to optimize ambulance stationing and routing. We further include data formatting, linear program solvers, simulation enginer, visulization, and GUI in a comprehensive package for use by the City of Austin and others! 


## Table of Contents 

1. [Introduction](#Introduction)
3. [Austin EMS Data Preprocessing](#Austin)
4. [Open Street Map](#Open)
5. [Linear Program Solver](#Linear)
6. [Simulation Engine](#Simulation)
7. [Graphing](#Graphing)
8. [GUI Package](#GUI)
9. [Credits](#Credits)

<a name="Introduction"/>

## Introduction 

![Overview](https://github.com/michaelhilborn/AmbulanceDeployment/blob/master/results/flowchart.png "Flowchart Overview")

<a name="Austin"/>

## Austin EMS Data Preprocessing 

### How to run

You will need python and jupyter notebooks to run this code. If this is your first time using jupyter notebook, we recommend installing anaconda and jupyter notebook here (https://www.anaconda.com/products/individual).

In anaconda you can install the necessary packages to run this code by installing any missing packages, for example:

```python
conda install numpy
conda install pandas
conda install csv
```

### Outputs

First we take the city of austin and partition it into a rectangular grid. For this example, consider a 19x19 grid consisting of 196 total rectangles.
* adjacent_nbhd: Consider a 19x19 grid consisting of 196 total rectangles. Then adjacent_nbhd produces a 196x19x19 boolean matrix for entry (i,j,k) is 1 if grid i is adjacent to grid (j,k) and 0 otherwise.
* coverage: Consider if there are 40 ambulance stations and 196 grid points. Then coverage produces a matrix that is 40x196 and for entry (i,j) is 1 if station i can reach region j in 10 minutes.
* hourly_calls: hourly_calls produces a matrix of size 196x37,000 where for entry (i,j) is the number of calls region i had at hour j. So in total there are 37,000 hours of EMS time recorded here.
* train_test_split_hourly_calls: splits hourly_calls into a training and testing data set.

Note: to change the grid size, run the open street map module with a different grid size and save the .json file. Then load the new .json file into these data preprocessing files.

<a name="Open"/>

## Open Street Map

### How to run

You will need python and jupyter notebooks to run this code. You also will need an open service routing key which is free (https://openrouteservice.org/services/). In the line with the header, put in your API key.
```python
headers = {
    'Accept': 'application/json, application/geo+json, application/gpx+xml, img/png; charset=utf-8',
    'Authorization': 'YOUR_KEY_HERE',
    'Content-Type': 'application/json; charset=utf-8'
}
```
### Outputs

* create_regions: it uses census tract data to obtain travis county coordinates and then outputs travis county into a grid. We query from open street map to find the distance between any two grid points. This grid info is saved into a .json that goes into the Austin data preprocessing.

<a name="Linear"/>

## Linear Program Solver

### How to run

You will need Julia, Gurobi and jupyter notebooks. You can choose to run this code in Julia or jupyter notebooks. We suggest atom as an IDE for Julia. For a tutorial on how to install and run Julia and Gurobi reference [here.](https://github.com/michaelhilborn/AmbulanceDeployment/blob/master/documentation/gurobi.md) Add any packages you dont have in Julia like this:

```julia
using Pkg
Pkg.add("Package Name")
```

* For Single_Robust and Single_Stochastic set PROJECT_ROOT =  the_directory_of_AmbulanceDeploymentLegacy.jl

### Outputs

* Single_Stochastic (jupyter notebook): solves a two-stage stochastic linear program. It outputs the according optimal deplyment x and routing y. This is saved to a .json.
* Single_Robust (jupyter notebook): solves a two-stage robust linear program using the column constraint method. It outputs the according optimal deployment x. It also outputs details about run time. Since the column constraint method is an iterative method, it outputs upper and lower bounds for each iteration. This is saved to a .json.
* Ambulance_Deployment_experiments (Julia): solves classical models MALP,MEXCLP as well as the stochastic and robust deployments for [30,35,40,45,50] number of ambulances resulting in solving 20 linear programs. These are saved into a dict into a .json.


```julia
44-element Array{Int64,1}:
 2 2 1 1 1 0 1 2 2 0 0 0 0 ...  1 2 0 0 0 0 1 0 1 0 1 1
```
<a name="Simulation"/>

## Simulation Engine

### How to run

Again you can run these with jupyter notebooks or with Julia. 

### Outputs

*

<a name="Graphing"/>

## Graphing

<a name="GUI"/>

## GUI Package

nvm
https://developpaper.com/how-to-install-and-use-nvm-in-windows/
npm
https://www.npmjs.com/get-npm
yarn
https://yarnpkg.com/getting-started/install
GUI
https://www.w3schools.com/react/default.asp	

<a name="License"/>
