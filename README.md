# Moose Simulation Project - Modeling Course 2024

This project simulates moose movements and behaviors in a forested area, and models how effectively a drone-based surveying method can estimate the number of moose within that area. The simulation ties into a scenario where a drone equipped with LiDAR and thermal cameras is used to count moose in a given forest region near Tampere and Valkeakoski (east side of highway E12 in Finland). The primary goal is to propose a cost-effective and accurate moose counting method using drones, supported by a simulation model that estimates detection accuracy under varying moose populations.

**Original Assignment (in Finnish):**  
"Laadi tarjous hirvien laskennasta drooneilla Tampereen ja Valkeakosken välisellä, tien E12 itäpuolisella metsäalueella.  
Kriteerit onnistumiselle:  
- halpa hinta  
- laskennan tarkkuus  

Laske hinta droonin ja kameran hankintakustannuksille ja 10 tutkimuskerralle. Voit olettaa, että työvoimakustannus on 100 € / tunti.  
Perustele simulaatiomallilla, kuinka tarkka mittauksenne on erilaisilla hirvimäärillä."

---

## Features

- **Moose Behavior Modeling:**  
  - Moose move mostly at dawn and dusk.  
  - Moose eat and rest for several hours a day.  
  - Moose wander around throughout the day, moving alone or as a cow-calf pair.  
  - Movement patterns reflect traveling between feeding and watering areas, often in a zig-zag pattern.
  - Moose prefer being near water sources.

- **Drone Surveying Setup:**  
  - Drone equipped with LiDAR and thermal cameras to detect moose and distinguish them from false positives  
  - Detects if a cow moose is accompanied by a calf using thermal imagery.  
  - The drone follows a planned path over the area and records how many moose are detected within its "view cone."
      - The flight path is based on the [bar scan sweep pattern](https://vnfawing.com/VNFAWING-BFM-Intro-5.htm)

- **Simulation Model Details:**  
  - Simulates moose locations, hunger cycles, sleeping and resting periods, wandering around, and their movements towards the nearest feeding/watering "bars" (areas).
  - Models drone path and scanning patterns over the forest, and calculates the number of moose detected.
  - Allows for multiple simulation runs to assess average detection accuracy and variability.

## Code Structure

- **Main.lua** (LOVE2D-based visual simulation):  
  Runs a single simulation visually. Displays moose movements, drone coverage, and detection counts over time. Used for demonstration and visualization.

- **crunch.lua** (LuaJIT-based model):  
  Runs the core simulation logic without visualization, designed for fast execution and statistical analysis.  
  - Parameters: area size, moose density, feeding site density, start time, drone speed, view cone size, and flight duration.
  - Runs the simulation 100 times for a given parameter combination
  - Outputs summary statistics (detected moose vs. actual moose population, smallest & largest amount of detected moose population).

- **run.lua:**  
  Batch runner that executes `crunch.lua` with various parameter sets, collecting data for aggregate analysis.

## How to Run

1. **Requirements:**
   - [LOVE2D](https://love2d.org/) for visual simulation (`Main.lua`).
   - LuaJIT for the CLI simulations (`crunch.lua` and `run.lua`).
   - A working Lua environment.

2. **Visual Simulation (Main.lua):**  
   - Install LOVE2D.  
   - Run: `love .` inside the project directory.  
   - A window will open showing moose, feeding sites, and the drone's path.

3. **Command-Line Simulation (crunch.lua):**  
   - Run: `luajit crunch.lua [parameters]`  
   - Example parameters: `luajit crunch.lua 80000 3.1 12 0 1200 10 10 2`  
     - These parameters represent area, moose density, feeding site density, start time, drone speed, view width/height, and simulation duration.
   - The script prints out detection statistics. Use different sets of parameters to compare accuracy.

4. **Batch Runs (run.lua):**  
   - Create a parameter file listing various parameter sets line by line.  
   - Run: `luajit run.lua parameters.txt crunch.lua output.txt`
   - Each line in parameters.txt should have a set of parameters, seperated by whitespace.
   - Collects results for multiple parameter sets, useful for tuning parameters and analyzing accuracy over many simulations.

## Parameter Units of Measure

- **alue (Area):**  
  - **Unit:** hectares (ha)  
  - 1 hectare (ha) = 10,000 m²  
  In this simulation, 1 ha is represented as a 1 hm × 1 hm area (1 hm = 100 m). Thus, 1 ha corresponds to 1 hm² in the simulation’s coordinate system.

- **hirviTiheys (Moose Density):**  
  - **Unit:** moose per 1000 hectares (moose/1000 ha)

- **baariTiheys (Feeding Site Density):**  
  - **Unit:** feeding sites (bars) per 1000 hectares (bars/1000 ha)

- **vasaTiheys (Calf Density):**  
  - **Unit:** calves per moose

- **droneSpeed (Drone Speed):**  
  - **Unit:** hectometers per hour (hm/h)  
  (1 hm = 100 m, so drone speed is given in hm/h)

- **Hirvi (Moose) Movement Speeds:**  
  - **Wandering speed:** hm/h  
  - **Searching speed:** hm/h

- **Drone "View Cone" Dimensions (w, h):**  
  - **Unit:** hectometers (hm)

Because the simulation uses a coordinate system where 1 unit of area = 1 ha and 1 unit of length = 1 hm, these units allow straightforward calculations. Distances and drone coverage are in hm, while area-related densities are conveniently expressed in ha.

## Interpreting Results

- **Drone Counts:**  
  The simulation prints how many moose were detected and the estimated density based on the surveyed area.
  
- **Accuracy & Cost Analysis:**  
  Combine simulation results with cost assumptions (e.g., drone purchase, camera cost, operator wages at 100 €/hour, and number of survey runs) to estimate overall cost-efficiency and accuracy.
  
- **Parameter Variations:**  
  By adjusting moose density, feeding site density, and drone flight parameters, you can see how detection accuracy changes. This helps justify and refine the proposed drone counting strategy.

---

## License

This project is licensed under the [MIT License](./LICENSE).  
Please see the `LICENSE` file for the full terms.

## Acknowledgments

- [LOVE2D](https://love2d.org/) for the 2D game framework.  
- LuaJIT for efficient scripting.
  
*This project serves as a conceptual and academic exercise in wildlife surveying simulations.*
