<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2026 KY (kyshipit)
-->

## I. ROS2 Basic Concepts

### 1.1 What is ROS2?

ROS (Robot Operating System) was created in 2007. It is not an operating system in the traditional sense, but a **distributed robot software development framework** . Its core value lies in achieving **decoupled development** of sensors, controllers, and decision-making modules through standardized communication middleware. You can develop LiDAR drivers, motion control algorithms, and navigation logic separately, and then assemble them like building blocks.

Released in 2018, ROS2 is a complete overhaul of ROS1. **ROS1 Noetic ceased maintenance in May 2025** , while ROS2 Jazzy Jalisco is the current active Long Term Support (LTS) version, with official support continuing until 2029. The core improvement of ROS2 lies in its communication architecture—upgrading from TCP communication reliant on a central node to a decentralized **DDS (Data Distribution Service)** communication mechanism.

**What is DDS?** Simply put: ROS1 communication is like "making a phone call by dialing the switchboard first," where all nodes must connect to the ROS Master to find each other; ROS2's DDS is like "WeChat group chat"—each node joins the same "domain," automatically discovering other nodes and communicating directly, eliminating single points of failure. This decentralized architecture allows ROS2 to run on various platforms, from embedded devices to cloud servers.

### 1.2 Four Major Communication Primitives

In ROS2, nodes exchange information in four ways:

Communication methods | Features | analogy | Typical applications
:-- | :-- | :-- | :--
**Topic** | Asynchronous publish-subscribe, one-to-many, continuous data stream | radio station | LiDAR point cloud, camera image
**Service** | Synchronous request-response, one-to-one | Call to ask for directions | Map query, route planning request
**Action** | Long-running tasks that allow for feedback and cancellation | Food delivery order tracking | Navigation tasks, robotic arm movements
**Parameter** | Node configuration and runtime dynamic adjustment | System Settings | PID parameters, sensor configuration

### 1.3 TF2 Coordinate Transformation

TF2 is the "mathematical skeleton" of robot motion control—without it, the distance measured by lidar, the displacement calculated by mileage, and the position of objects seen by cameras cannot all be unified under the same spatial coordinate system.

**Why is TF2 needed?** The robot's sensors are distributed in different locations: LiDAR on the roof, IMU in the center of the chassis, and cameras at the front. The LiDAR measures "an obstacle 2 meters to the left front"—this is relative to the LiDAR's own coordinates. But controlling the robot to avoid obstacles requires knowing "the obstacle's position relative to the robot's center (base_link)." What TF2 does is **maintain a transformation tree from the global map to each sensor's coordinate system** , allowing any node to query the transformation relationship between any two coordinate systems at any time.

A typical TF2 tree structure:

text

```
map → odom → base_footprint → base_link → laser_link
                                       → camera_link
                                       → imu_link
```

- `robot_state_publisher` : Resolves URDF and publishes all static coordinate transformations (such as the relative position from base_link to laser_link).
- Odometry node: Publishes dynamic transformation `odom → base_footprint` (this transformation changes every time the robot takes a step).
- Location node: Publish `map → odom` (align the robot's position to the global map)

## II. Robot Modeling and Observation

### 2.1 From CAD to URDF—Modeling is not "writing code"

You might think that robot modeling is simply writing URDF XML code in a text editor. However, **in actual engineering, graphical modeling is the mainstream starting point** .

**Real workflow: CAD drawing → Export URDF → Fine-tuning and optimization → RViz visualization verification**

**(1) CAD drawing (engineering-grade tool)**

The robot's structural design is first completed in specialized CAD software. Mainstream tools include:

- **Onshape** : A cloud-based CAD platform **that natively supports URDF export since March 2026** , eliminating the need for external conversion tools. The May 2026 update further expands URDF export capabilities, supporting frames, tool center points, clearer joint definitions, and more consistent naming conventions. Mesh export also supports adjustable subdivision quality for both STL and GLTF.
- **SolidWorks** : The most mainstream desktop mechanical design software. The official plugin is `sw_urdf_exporter` , but note that this plugin **exports to ROS1 format by default** ; you need to manually modify the configuration file to adapt it for ROS2 Jazzy. New tools such as **SW2GZ** have also emerged in the community, supporting direct export of SolidWorks assemblies to ROS2 + Gazebo (without manually writing URDF), and end-to-end testing on ROS2 Jazzy + Gazebo Harmonic has been implemented.
- **Fusion 360** : Also has a community-maintained export tool.

**(2) Export URDF**

The CAD plugin automatically identifies parts and constraints in an assembly and generates:

- Each part → one `<link>` (rigid body)
- Assembly constraints → `<joint>` (joint)
- Automatically calculate mass, moment of inertia, and colliding bodies

**(3) Fine-tuning and optimization (must be done after export)**

URDF files exported from CAD software typically cannot be used directly for simulation and must be manually adjusted.

Adjustment items | reason | Specific operations
:-- | :-- | :--
**Inertial parameters** | The moment of inertia derived from CAD is based on an ideal uniform density; the actual center of gravity may be offset. | Modify the mass and inertia matrices based on the physical sample or detailed design.
**Joint Limitation** | CAD assembly constraints may not reflect the actual range of motion of joints. | Check and set the lower/upper limits of the `<limit>` tag.
**Sensor mounting** | The LiDAR/IMU may not be drawn in the CAD file. | Manually add the `<gazebo>` tag and sensor definition.
**Collider simplification** | Collision bodies exported from CAD are often too detailed (original mesh). | Simplify to basic geometries such as box, cylinder, and sphere to improve the efficiency of the physics engine.
**ROS2 compatibility** | The official SolidWorks plugin exports to ROS1 format by default. | Modify tags and attributes in URDF to adapt to ROS2

**(4) RViz Visual Verification**

Load the URDF using RViz2 and check the model structure and joint movement in 3D to see if they are normal.

### 2.2 Core Structure and Key Pitfalls of URDF

The core of URDF is the kinematic chain composed of **links (rigid bodies) and joints** :

xml

```
<robot name="mbot">
  <link name="base_link">
    <inertial> ... </inertial>    <!-- 质量 + 惯性矩阵 -->
    <visual> ... </visual>       <!-- 显示几何 -->
    <collision> ... </collision> <!-- 物理碰撞体 -->
  </link>

  <joint name="left_wheel_joint" type="continuous">
    <parent link="base_link"/>
    <child link="left_wheel_link"/>
    <origin xyz="0.2 0.1 0.04" rpy="0 0 0"/>
    <axis xyz="0 1 0"/>
  </joint>
</robot>
```

**Trap 1: Root links cannot carry inertia**

`robot_state_publisher` uses **KDL (Kinematics and Dynamics Library)** to parse the kinematic chain. KDL requires the root link to be **a pure coordinate frame with no inertia and no geometry** . If the root link contains `<inertial>` , KDL will fail to parse the entire chain— **no TFs will publish** , and RViz will report `Frame [base_link] does not exist` ".

The correct approach is to use `base_footprint` (an empty link) as the root and `base_link` (with inertia) as its child. This perfectly aligns with Nav2's convention: `odom → base_footprint → base_link` .

**Trap Two: The Orientation of `<cylinder>`**

In URDF, `length` of `<cylinder>` ` is along the local **Z-axis** —not the X-axis, not the Y-axis. To make a cylindrical wheel "stand up" (disc facing forward and backward), it needs to be rotated 90° around the X-axis: `rpy="${pi/2} 0 0"` . Rotating around the Y-axis or Z-axis will cause the wheel to "lie flat" or "tilt".

### 2.3 Visualization Observation Layer – The Developer's "Eyes"

Visualization tools are not standalone functions, but rather **an integral part of the debugging and observation process** . Before undertaking any simulation or control work, mastering "how to see" is more important than "how to do it."

**(1) RViz2 - 3D Visualization**

ROS2 comes standard with 3D visualization tools. These tools can display:

- URDF robot model (3D rendering)
- LiDAR point cloud
- TF coordinate axes
- Path, cost map, navigation target point

Applicable scenario: **Checking if the space is correct** — whether the model is complete and whether the sensor data is in the correct location.

**(2) PlotJuggler – Time Series Analysis**

A tool specifically designed for analyzing how numerical data changes over time. It supports drag-and-drop loading of rosbag2, MCAP, or real-time topic data, and uses hardware-accelerated OpenGL to render large-scale datasets. New channels can be created using formulas, and data filtering can be performed.

Applicable scenarios: **Checking whether the values ​​are correct** — PID response curves, speed command tracking, and sensor noise analysis.

**(3) Foxglove Studio - Full-Stack Visualization**

A modern browser-based visualization platform that natively supports the MCAP format. It can simultaneously display multiple panels, including 3D models, 2D maps, images, and time-series curves. Real-time remote connection and teleoperation are supported.

Applicable scenarios: **System-wide integration testing** —simultaneously view models, maps, images, and signals to quickly locate cross-module issues.

## III. Simulation Verification

### 3.1 How Gazebo works

Gazebo is **the official standard simulator** for the ROS ecosystem, maintained by the Open Robotics Foundation. The current mainstream version is **Gazebo Harmonic (gz-sim8)** , which is the officially recommended combination with ROS2 Jazzy. For example, the open-source project `rbot` has integrated robot description, Gazebo simulation, `ros2_control` , teleoperation, sensor simulation, localization, mapping, and Nav2 navigation into a single ROS2 workspace.

**What is the physics engine doing?**

The essence of a physics engine is solving the equations of rigid body dynamics— **given the forces acting on all joints, calculating how each part of the robot will move in the next second** . Mathematically, this is represented as:

M⋅q¨+C+G=Fext *M⋅q¨* + *C* + *G* = *F **e** x*** *t*

- **M** : Mass matrix (mass and moment of inertia of each component)
- **q̈** : Acceleration (angular and linear acceleration of each joint/part in the next second)
- **C** : Coriolis force and centrifugal force (additional force generated by rotation)
- **G** : Gravity (Earth's gravitational pull)
- **F_ext** : All external forces (motor driving force, ground friction force, collision force).

Gazebo itself does not perform physics calculations; instead, it integrates physics engines such as ODE, Bullet, and DART as a framework. Collision detection uses the GJK algorithm (convex body collision detection) + SAP algorithm (space partitioning acceleration).

**What does sensor simulation do?**

- **GPU LiDAR** : Firing tens of thousands of rays into the scene via ray casting to detect the distance to intersections with the mesh. Gazebo Harmonic has removed `type="ray"` from the Classic version and now uniformly uses `type="gpu_lidar"` .
- **IMU** : Reads the angular velocity and linear acceleration of a rigid body from the physics engine and adds Gaussian noise to simulate a real sensor.
- **Camera** : Outputs RGB/depth images through the rendering engine.

### 3.2 How Gazebo communicates with ROS2

Gazebo uses its own communication middleware, **Gazebo Transport** (based on ZeroMQ + Protobuf), while ROS2 uses DDS— **the two systems do not communicate with each other** . The bridge is **ros_gz_bridge** .

text

```
[ROS2节点] ←→ [ros_gz_bridge] ←→ [Gazebo Transport] ←→ [Gazebo仿真引擎]
     ↓                                ↓
  DDS通信                       物理引擎+传感器+渲染
```

`ros_gz_bridge` establishes **a bidirectional mapping** between ROS2 topics and Gazebo topics. For example, it translates LiDAR data from the Gazebo ` `/scan` topic to the ROS2 `/scan` topic.

### 3.3 Emulator Selection: Each Has Its Own Battlefield

Dimension | Gazebo | Isaac Sim | Webots | MuJoCo
:-- | :-- | :-- | :-- | :--
**Open source license** | Apache 2.0 | Closed source (free to use) | Apache 2.0 | Apache 2.0
**Physics Engine** | ODE/Bullet/DART | PhysX 5 (GPU accelerated) | ODE | Self-developed (supports MJX GPU acceleration)
**ROS2 integration** | Original official standard configuration | via the isaac_ros package | via the webots_ros2 package | Community Package
**Rendering quality** | middle | Extremely high (RTX ray tracing) | middle | Low (emphasis on physics)
**Typical scenarios** | General Robot Simulation | AI/Vision/Digital Twin | Education/Rapid Validation | Reinforcement learning/motor control

**Selection logic** : If you're unsure which to use, go for **Gazebo** —it's the official standard for ROS, has the largest community, and solutions are readily available for common problems. **Isaac Sim** is suitable for scenarios requiring high-fidelity vision or digital twins. **MuJoCo** is suitable for reinforcement learning and legged robot contact dynamics research. **Webots** is suitable for education and rapid prototyping.

## IV. Control and Drive: ros2_control

### 4.1 What problem does it solve?

If the same robot runs perfectly in simulation, do we need to rewrite the control code when we switch it to a real machine? `ros2_control` aims to solve this problem— **allowing the same control algorithm to run seamlessly in both simulation and real machine environments** .

### 4.2 Three-tier architecture

`ros2_control` adopts a layered design:

text

```
┌─────────────────────────────────────────────────────┐
│              Controller Manager                     │
│  ┌──────────────┐  ┌──────────────┐               │
│  │ diff_drive   │  │ joint_traj   │  ...          │
│  └──────────────┘  └──────────────┘               │
└─────────────────────────────────────────────────────┘
                        ↓
               Resource Manager
                        ↓
       ┌────────────────┴────────────────┐
       ↓                                 ↓
┌─────────────────┐           ┌─────────────────┐
│ GazeboSimSystem │           │ RealHardware    │
│ (仿真插件)      │           │ (真机插件)      │
└─────────────────┘           └─────────────────┘
```

- **Controller** : Implements specific control algorithms—such as `diff_drive_controller` (differential control) and `joint_trajectory_controller` (joint trajectory control).
- **Controller Manager** : Manages the loading, unloading, and execution cycle of controllers.
- **Hardware Interface** : Communicates with the underlying hardware (emulation or real machine).

### 4.3 Seamless switching between simulation and real machine

The key mechanism lies in **the hardware interface layer** :

- **Simulation mode** : Using `gz_ros2_control/GazeboSimSystem` plugin. The `gz_ros2_control` plugin **automatically loads the controller_manager** and then starts the controller via the spawner. Each physics step (typically 1000Hz) executes the following: read Gazebo joint state → pass to Controller Manager → Controller calculates instructions → write back to Gazebo joint.
- **Real device mode** : Use custom hardware plugins (such as reading and writing motors via serial port/CAN/ETH).

In URDF, the controller plugin is declared using the `<gazebo>` ` tag. All upper-level controllers— `diff_drive_controller` , `joint_state_broadcaster` — **require no modification** . Switching between them only requires changing one line of configuration.

**Core value** : **One-time modeling (URDF), one set of control (ros2_control), two deployments (simulation parameter tuning + real machine operation)** .

## V. Perception and Localization: SLAM

### 5.1 What problem does SLAM solve?

SLAM (Simultaneous Localization and Mapping) aims to answer two questions simultaneously: **"Where am I?"** and **"What does my surroundings look like?"** . As a robot moves through an unknown environment, it uses sensor data to estimate its own position while simultaneously building a map of the environment.

The mainstream technical approach has evolved from the early **filtering method** (EKF SLAM, particle filtering) to **the graph optimization method** —currently, almost all practical SLAM systems are based on graph optimization.

**The core idea of ​​graph optimization** :

1. Each time the robot takes a step, it records a **pose node** .
2. The relative motion between two poses (from odometry) constitutes **the odometry edge** .
3. When the robot returns to the visited area, it detects **a closed loop** through scanning and matching, and adds a closed loop constraint edge.
4. Adjust all pose nodes using an optimization algorithm (such as iSAM2) to minimize the overall error of all constraints.

### 5.2 Three Mainstream Solutions

**(1) slam_toolbox - ROS2 official recommendation**

`slam_toolbox` is the currently officially recommended 2D SLAM solution for ROS2, based on a graph-optimized architecture of Karto SLAM.

Features:

- **Lightweight** : On resource-constrained platforms such as Raspberry Pi, CPU load is only about 22%.
- **High map quality** : Multiple comparative studies have shown that slam_toolbox performs best in terms of map quality and trajectory estimation accuracy.
- **Supports Lifelong** Mapping – Maps can be continuously optimized and updated after they are built.
- Deep integration with Nav2
- Suitable for indoor mobile robots, service robots, and warehouse AGVs

**(2) Cartographer - a Google product, suitable for large-scale mapping.**

Google's open-source real-time SLAM solution. The core idea is **submap + loop closure detection** :

- Each frame of laser scanning is matched with the previous frame, accumulating to form **a sub-image.**
- Using **branch and bound to** quickly match new and historical subgraphs to detect loop closures.
- Global optimization using Ceres Solver

It is suitable for **large-scale indoor mapping** (such as office buildings and warehouses), but the computational cost is greater than slam_toolbox - on the same hardware, Cartographer may not be able to guarantee global trajectory consistency.

**(3) RTAB-Map - 3D Visual SLAM**

**Real** -Time Appearance-Based Mapping **supports RGB-D cameras, LiDAR, and stereo cameras, outputting 3D point cloud maps** . Loop closure detection uses **a bag-of-words model** to quickly retrieve historical keyframes.

Suitable for scenarios requiring **3D environmental perception** (such as visual navigation and humanoid robots), it is often used in conjunction with slam_toolbox (for 2D mapping) and Nav2 (for navigation).

### 5.3 Selection Recommendations

Scene | Recommended solution | Computational overhead | Closed-loop detection | Map type
:-- | :-- | :-- | :-- | :--
Indoor 2D LiDAR Robot | **slam_toolbox** | Low (~22% CPU) | Graph optimization closed loop | 2D occupying grid
Large-scale interior design (office building/warehouse) | **Cartographer** | Medium-high | Subgraph matching loop closure | 2D/3D Occupied Grid
Requires 3D maps or visual sensors | **RTAB-Map** | high | Bag-of-words model closed loop | 3D point cloud + 2D mesh

## VI. Positioning: AMCL

### 6.1 What problem does the location aim to solve?

SLAM addresses the issue of "exploring and mapping as you go when you first arrive at a place." But **once the map is built, how does the robot know its location on the map the next time it's started?**

This is the problem that **Localization** aims to solve— **we already have a map, but where am I?** Location is a prerequisite for navigation: without knowing where you are, you cannot plan a path to your destination.

### 6.2 The Principle of AMCL

AMCL (Adaptive Monte Carlo Localization) is the standard localization scheme in the Nav2 ecosystem. It is based on **the Particle Filter** algorithm.

**The core idea** is to use a group of "particles" to represent the robot's possible positions, with each particle representing a hypothetical position and direction. The more concentrated the particles, the more certain the positioning.

**Workflow** :

1. **Initialization** : Randomly scatter a bunch of particles on the map (anywhere the robot might be).
2. **Prediction** : As the robot moves, all particles will move along with it (based on odometry data).
3. **Update** : After the robot observes sensor data (such as LiDAR scans), it scores each particle—the particle that matches the observation more closely receives a higher score.
4. **Resampling** : Eliminate low-scoring particles and replicate new particles near high-scoring particles.
5. **Adaptive** : When the location is uncertain (particles are scattered), increase the number of particles; when the location is certain, decrease the number of particles to save computation.

**In conjunction with Nav2** : The AMCL node continuously publishes `map → odom` TF transformation, aligning the robot's position to the global map. Nav2's planner relies on this transformation to correctly plan paths.

### 6.3 Positioning vs. SLAM: When and Which to Use

Scene | Usage Plan
:-- | :--
When entering an unknown environment for the first time, mapping is required. | **SLAM** (slam_toolbox/Cartographer)
The map is available; the robot has restarted. | **AMCL** (pure location tracking, no map modification)
The map is available, but the environment has been slightly changed (e.g., new temporary obstacles have been added). | **AMCL + Local Cost Map Update** (Global map remains unchanged, local areas are updated in real time)

## VII. Planning and Navigation: Nav2

### 7.1 What problems does Nav2 solve?

How can a robot walk to a target point on its own? Nav2 aims to solve this **autonomous navigation** problem—the complete link from the target point to the control commands.

### 7.2 Layered Architecture: Strategy vs. Tactics

Nav2 breaks down navigation into two levels:

**Global Planning (Strategic Level)** – “Which Path to Take?”

- Find a path from the starting point to the destination on a static map.
- Optional Algorithms:
    - **Smac Planner (Hybrid A*)** : Nav2 default, considers vehicle kinematic constraints (minimum turning radius).
    - **NavFn** : Based on classic A*, simple and fast, does not consider kinematics.
    - **ThetaStar** : A variant of A* that allows paths to traverse mesh vertices, resulting in shorter paths.

**Local planning (tactical level)** – "How to proceed in the current frame?"

- Real-time speed command generation tracks the global path while avoiding dynamic obstacles.
- Optional algorithms: DWB, MPPI, RPP (Regulated Pure Pursuit), etc.

**Cost map** : Maintains obstacle information, divided into global cost map (static map + static obstacles) and local cost map (real-time sensor obstacles).

**Behavior Tree** : The state machine that orchestrates the entire navigation task—receiving the target → planning → execution → success/failure recovery.

### 7.3 Comparison of Two Local Planners

Dimension | DWB | MPPI
:-- | :-- | :--
**Algorithm Ideas** | Velocity space sampling + scoring and selection | MPC with random sampling and iterative optimization
**Core Mechanism** | Within the achievable speed range, sample hundreds of `(v, ω)` trajectories, simulate trajectories, and select the optimal one using a cost function. | Multi-trajectory parallel sampling + cost evaluation, using model prediction path integral optimization to optimize control commands.
**Controlling smoothness** | Generally (may cause heading sway) | Excellent (smooth trajectory generation)
**Controlling energy consumption** | middle | lowest
**Computational overhead** | Low | High (requires GPU acceleration or parameter downgrading)
**Dynamic obstacle avoidance** | good | excellent
**Narrow channel performance** | Possibly a slight fluctuation | Better
**Applicable Scenarios** | Structured environments, resource-constrained platforms | Complex dynamic environment, high computing power platform
**Selection Recommendations** | **Low cost preferred** | **The most dynamic and advanced**

## VIII. Debugging and Troubleshooting

### 8.1 ROS2 bag – Data recording and playback

`ros2 bag` is **a data logger** for ROS2. It can record all topic data to a file and then play it back offline— **bringing the real device running scenario to your desk for debugging** .

**Why do we need it?**

- **Problem reproduction** : The problem occurred on the actual device. I recorded a bug report, then played it back offline at my desk for debugging, avoiding the need to repeat the experiment.
- **Algorithm comparison** : Run different SLAM algorithms or planners on the same bag of data and compare the results.
- **CI/CD** : In automated testing, bag data is used as fixed input to verify whether the algorithm output meets expectations.
- **On-site data recording** : Commercial robots (such as autonomous delivery vehicles, lawnmower robots, and inspection robots) typically record high-frequency data from cameras, IMUs, odometers, positioning, control commands, and diagnostic data.

**Recommended format** : Use **the MCAP storage format** , which offers better performance than the default SQLite3, supports larger files, and provides faster read and write speeds. ROS2 Jazzy has MCAP as the default format.

bash

```
# 录制（使用 MCAP 格式）
ros2 bag record -s mcap /topic1 /topic2

# 查看信息
ros2 bag info -s mcap your_recording.mcap
```

### 8.2 ros2 doctor — System Diagnosis

`ros2 doctor` checks the system status: whether all nodes are functioning correctly, whether the topic has subscribers, and whether the network is working properly. It quickly identifies basic issues like "Why isn't my node responding?"

### 8.3 RQt Series – Lightweight GUI Tools

ROS2 comes with a set of graphical debugging tools:

- `rqt_graph` : A node topology graph—clearly showing who is publishing and who is subscribing.
- `rqt_console` : Log viewer – centrally view the output of all nodes.
- `rqt_plot` : Quickly plot curves
- `rqt_topic` : Topic monitoring

### 8.4 Quick Reference for Common Problems (Based on Real-World Engineering Experiences)

symptom | Root cause | repair
:-- | :-- | :--
RViz reports `Frame [x] does not exist` | Root link with inertia | Root using `base_footprint` without inertia
Wheels that are "crooked" or "lying down" | `<cylinder>` length along the Z-axis | Rotate 90° around the X-axis: `rpy="${pi/2} 0 0"`
The car did not move | Twist vs TwistStamped do not match | Nav2 configuration `enable_stamped_cmd_vel: true`
`Moved backwards in time` | `use_sim_time` is not standardized | Add `use_sim_time: true` to all nodes.
`/clock` is abnormally large | Residual Gazebo process | `pkill -f 'gz sim'`
LiDAR not loaded | Harmonic removes `type="ray"` | Use `type="gpu_lidar"`
Sensor frame_id with prefix | URDF→SDF conversion and mounting error | Explicitly specify `<gz_frame_id>`
The `gz sim` command cannot be found. | vendor package installation method | Run `gz sim` directly; no need to check `which`.

## IX. Complete Development Process

text

```
① CAD 画图（Onshape / SolidWorks / Fusion 360）→ 导出 URDF
       ↓ （微调：惯性参数、关节限位、传感器、碰撞体简化）
② RViz2 可视化验证模型结构
       ↓
③ Gazebo 仿真 + ros_gz_bridge → 验证物理和传感器
       ↓
④ ros2_control 调参（PID / 速度曲线）
       ↓
⑤ slam_toolbox 建图（或 Cartographer / RTAB-Map）
       ↓
⑥ AMCL 定位（地图已有，定位自身）
       ↓
⑦ Nav2 导航调试（全局规划 Smac + 局部规划 DWB/MPPI）
       ↓
⑧ 全链路可视化（PlotJuggler / Foxglove / rqt）
       ↓
⑨ ros2 bag 录制现场数据 → 离线调试 / 算法对比 / CI 验证
       ↓
⑩ 替换硬件接口插件 → 真机部署
```

**Substitutability of each link** :

- **CAD modeling** : Onshape (cloud-based, native URDF export) / SolidWorks (desktop, plugin required) / Fusion 360
- **Emulators** : Gazebo (general purpose) / Isaac Sim (AI/vision) / Webots (education) / MuJoCo (reinforcement learning)
- **SLAM** : slam_toolbox (lightweight and stable) / Cartographer (large-scale) / RTAB-Map (3D vision)
- **Positioning** : AMCL (Nav2 standard particle filter positioning)
- **Global planners** : Smac Planner (default, considers kinematics) / NavFn (simple and fast) / ThetaStar (shorter path)
- **Local planners** : DWB (low computing power, low cost preferred) / MPPI (high computing power dynamic obstacle avoidance)
- **Visualization** : RViz2 (3D) / PlotJuggler (signal analysis) / Foxglove (full stack)
- **Debugging** : ROS2 bag (data recording and playback) / ROS2 doctor (system diagnostics) / RQT series (lightweight GUI)
