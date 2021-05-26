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

You will need python and jupyter notebooks to run this code.

### Outputs


<a name="Linear"/>

## Linear Program Solver

<a name="Simulation"/>

## Simulation Engine

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
