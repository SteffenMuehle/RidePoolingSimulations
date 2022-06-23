# RidePoolingSimulations
Simulation code, animations and results from the paper "A framework for modeling ride pooling efficiency and minimum fleet size".
Link to paper: *placeholder*

the simulation framework was written by Steffen Mühle (@SteffenMuehle) and was tested in Julia version 1.6.2.
I currently plan to publish it as a Julia package (RidePooling.jl) in late 2022, and write a brief Archive paper dedicated to it.
Until then, there is a limited but functioning API as found in this repo.

If you have any questions, feel free to contact me!

If you use this code for your work, please cite this paper:

@article{
muehle2022ridepoolingefficiency,
title={A framework for modeling ride pooling efficiency and minimum fleet size},
author={Mühle, Steffen},
journal={PNAS},
volume={},
number={},
pages={},
year={2022},
publisher={PNAS}
}

# Contents of repository
- **animations:** animations of simulated dynamics on all used maps (.gif and .mp4)
- **simulation_code:** simulation framework, environment and scripts
  - **src:** The source code. If you don't know what you're doing, don't touch it.
  - **maps:** The transport spaces as used in the paper. Same here.
  - **scripts**:
    - animations: The notebook used for making the animations.
    - demo: A notebook for simulating ride pooling dynamics and evaluating the results.
    - minimal_fleet.jl: The script used for solving the minimum fleet problem as described in the paper and SI
