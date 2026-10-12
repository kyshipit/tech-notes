**English** | [简体中文](../../ros/交叉编译ROS2踩坑记录.md)

<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2026 KY (kyshipit)
-->

# Cross-compiling ROS2 Jazzy to ARM64 from x86: Getting it working from scratch + Troubleshooting Experience

## I. Why do we need to cross-compile on x86 computers?

The board-side `colcon build` is only suitable for early-stage demo verification. As project dependencies increase, the time for a full board-side compilation can balloon from a few minutes to over ten minutes or even longer. Meanwhile, embedded development boards have limited memory and storage, which can easily trigger memory overflows or disk warnings when the project is large. Compilation also consumes runtime and debugging resources. Furthermore, after integrating CI/CD, board-side compilation is difficult to standardize, and environmental differences can easily introduce compatibility issues.

Cross-compilation decouples the build process from the target hardware, trading configuration complexity for compilation efficiency, artifact consistency, and freeing up board resources. This article outlines common pitfalls throughout the entire process, including toolchains, sysroot, and custom message packets, to help you get it working on the first try.

---

## II. Understand a few core concepts.

### 2.1 What is cross-compilation?

Compile a program on a computer with architecture A that can run on architecture B.

Role | This article corresponds to | illustrate
:-- | :-- | :--
**Host machine** | x86_64 Ubuntu 24.04 | The computer you use to write code and run compilation.
**Target machine** | RK3588 (ARM64) | The final board for running the program
**cross compiler** | `aarch64-buildroot-linux-gnu-gcc` | A compiler capable of generating ARM64 instructions

> 💡 Analogy: A cross compiler is like a "translator"—you write a letter in Chinese (C++ source code), and the translator translates it directly into English (ARM64 machine code), which the recipient (ARM64 CPU) can then understand.

### 2.2 What is sysroot? Why are two needed?

sysroot = a "mirror copy" of the target board's file system.

The compiler needs two things during compilation: header files ( `.h` ) tell the compiler "what this function looks like"; and library files ( `.so` ) "assemble" the function implementation during linking. When cross-compiling, you can't simply copy the entire `/usr/lib` directory from the development board, so we need a streamlined root file system, which is sysroot.

Why are two sysroots needed?

Sysroot type | Location | content | What to provide
:-- | :-- | :-- | :--
① The toolchain comes with a built-in sysroot | Toolchain directory | libc, libstdc++, basic system libraries, OpenCV (full version) | C/C++ Runtime Basics
② Board-side ROS2 sysroot | Extracted from the development board myself | `/opt/ros/jazzy` + ROS dependent system libraries (libyaml, libspdlog, etc.) | ROS2 and project dependencies

> 💡 Analogy: The toolchain sysroot is like "pots and pans in the kitchen" (basic tools), while the board-side sysroot is like "recipes and ingredients" (ROS2 libraries). You need both to cook a meal.

### 2.3 What are CMake toolchain files?

CMake uses the host machine's `gcc` by default. When cross-compiling, we need a "manual" to tell CMake: "Don't use the local gcc, use that cross compiler; look for header files in this directory; look for libraries in that directory..." This manual is the toolchain file, a script ending in `.cmake` .

### 2.4 What did colcon do in the middle?

`colcon` itself doesn't understand cross-compilation; it simply passes parameters to CMake. All the magic of cross-compilation happens in the toolchain file and CMakeLists.txt. The process is as follows:

1. You run `./build-linux.sh`
2. The script calls `colcon build --cmake-args ...`
3. Colcon executes `cmake -DCMAKE_TOOLCHAIN_FILE=toolchain.cmake ..` on each ROS2 package.
4. CMake reads the toolchain files and the package's CMakeLists.txt file, and generates a Makefile.
5. The `make` command compiles and links the code to generate ARM64 ELF files.

---

## III. Environmental Preparation

### 3.1 What is needed?

project | illustrate
:-- | :--
Host machine | x86_64 Ubuntu 24.04
Target board | RK3588, running Ubuntu 24.04, with ROS2 Jazzy (ARM64) installed.
Cross-toolchain | `/opt/atk-dlrk3588-toolchain` (Provided by Zhengdian Atom)
board-side sysroot | Extract it from the development board and place it in `~/software/rk_sysroot`
ROS2 workspace | `~/work/ros-robot` contains packages such as `src/eai_bot`
Host tools | `colcon` , `cmake` , `make` , `python3` , ROS2 Jazzy (using only its code generation tool)

### 3.2 Extract the board-side sysroot (if it doesn't already exist)

Execute on the development board:

```
# 打包 ROS2 安装目录
tar czf ros2_jazzy.tar.gz /opt/ros/jazzy

# 打包 ROS 依赖的系统库（关键！很多人漏了这步）
tar czf sys_libs.tar.gz \
  /lib/aarch64-linux-gnu/libyaml* \
  /lib/aarch64-linux-gnu/libspdlog* \
  /lib/aarch64-linux-gnu/liblttng* \
  /usr/lib/aarch64-linux-gnu/libconsole_bridge* \
  /usr/lib/aarch64-linux-gnu/liborocos-kdl* \
  /usr/lib/aarch64-linux-gnu/liblog4cxx*
# ↑ 按需补充，后面踩坑 6.3 会讲怎么发现缺了哪些
```

After copying to the host machine, extract it to `~/software/rk_sysroot/` , maintaining the directory structure:

```
~/software/rk_sysroot/
├── opt/ros/jazzy/          ← ROS2 本体
├── lib/aarch64-linux-gnu/  ← 系统库
├── usr/lib/aarch64-linux-gnu/
└── usr/include/            ← 头文件（如有需要）
```

### 3.3 Host machine installation and build dependencies

```
sudo apt update
sudo apt install -y \
  build-essential cmake ninja-build \
  python3-colcon-common-extensions \
  ros-jazzy-rosidl-default-generators \
  ros-jazzy-rclcpp
```

> ⚠️ Note: Installing ROS2 on the host machine is only to allow colcon to find the code generator. The compiled binary is ARM64 and has nothing to do with the host machine's ROS2.

---

## IV. Detailed Explanation of the Three Core Documents

> This is the most important part of the entire document. Understanding these three files will make cross-compilation a breeze.

### 4.1 Toolchain file `toolchain_rk3588.cmake`

Place the file `~/work/ros-robot/toolchain_rk3588.cmake` in the root directory of your workspace.

cmake

```
# ========== 1. 告诉 CMake：目标是什么系统 ==========
set(CMAKE_SYSTEM_NAME Linux)          # 目标是 Linux
set(CMAKE_SYSTEM_PROCESSOR aarch64)   # 目标是 ARM64

# ========== 2. 指定交叉编译器 ==========
set(TOOLCHAIN_DIR /opt/atk-dlrk3588-toolchain)
set(CMAKE_C_COMPILER   ${TOOLCHAIN_DIR}/bin/aarch64-buildroot-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER ${TOOLCHAIN_DIR}/bin/aarch64-buildroot-linux-gnu-g++)

# ========== 3. 指定工具链自带 sysroot ==========
set(CMAKE_SYSROOT ${TOOLCHAIN_DIR}/aarch64-buildroot-linux-gnu/sysroot)

# ========== 4. 控制 CMake 的搜索行为（非常关键！）==========
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)   # 找程序只在宿主机找
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)    # 找库只在 sysroot 找
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)    # 找头文件只在 sysroot 找
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)    # 找 CMake 包只在 sysroot 找
```

**Line-by-line interpretation:**

set up | What would happen if we didn't set it?
:-- | :--
`CMAKE_SYSTEM_NAME` | CMake assumes you are compiling for your local machine and will not add cross-compilation flags.
`CMAKE_C/CXX_COMPILER` | CMake, using the native `gcc` , compiles x86 binary code, but the board can't run it.
`CMAKE_SYSROOT` | The linker could not find `libc` for the target architecture and threw an error.
`PROGRAM NEVER` | CMake might be looking for Python in the sysroot, attempting to run ARM64 Python → leading to a crash.
`LIBRARY/INCLUDE ONLY` | CMake may be linking to the host machine's x86 version of the `.so` → linking error or runtime segmentation fault.

### 4.2 Build script `build-linux.sh`

Place it in the root directory of the workspace:

```
#!/bin/bash
set -e

# ========== 路径配置（按需修改）==========
ROOT_PWD="$(cd "$(dirname "$0")" && pwd)"
SYSROOT_ROS="${HOME}/software/rk_sysroot"
TOOLCHAIN_DIR="/opt/atk-dlrk3588-toolchain"
HOST_PYTHON3="$(which python3)"

# ========== 清理旧构建 ==========
rm -rf build install log

# ========== 开始构建 ==========
echo ">>> 开始交叉编译..."

colcon build \
  --packages-select eai_bot \
  --cmake-args \
    -DCMAKE_TOOLCHAIN_FILE="${ROOT_PWD}/toolchain_rk3588.cmake" \
    -DCMAKE_FIND_ROOT_PATH="${SYSROOT_ROS};${TOOLCHAIN_DIR}/aarch64-buildroot-linux-gnu/sysroot" \
    -DROS_SYSROOT="${SYSROOT_ROS}" \
    -DPython3_EXECUTABLE="${HOST_PYTHON3}" \
    -DTARGET_SOC=rk3588 \
    -DCMAKE_BUILD_TYPE=Release

echo ">>> 编译完成！产物在 install/ 目录下"
```

**Parameters broken down one by one:**

parameter | effect | Xiaobai's understanding
:-- | :-- | :--
`CMAKE_TOOLCHAIN_FILE` | Specify toolchain file path | Tell CMake where to read that instruction manual.
`CMAKE_FIND_ROOT_PATH` | Additional search root directory | "Besides the toolchain sysroot, also check the board-side sysroot."
`ROS_SYSROOT` | Custom variables | The path to the board-side sysroot must be used in CMakeLists.txt.
`Python3_EXECUTABLE` | Forced to use host machine Python | "Use the host machine's Python for code generation; don't look for ARM64-based code."
`TARGET_SOC` | Customize and identify the target chip. | "Making conditional compilation easier in CMakeLists.txt"
`CMAKE_BUILD_TYPE=Release` | Enable optimization | The compiled program is faster and smaller.

### 4.3 Package's `CMakeLists.txt` (Key Excerpts + Comments)

cmake

```
cmake_minimum_required(VERSION 3.16)
project(eai_bot)

if(NOT CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 17)
endif()

# ==================== 消息生成 ====================
# ⚠️ 禁用 Python 消息生成器
# 原因：交叉编译时 sysroot 里没有 Python 开发头文件，
#       如果不禁用，CMake 会报 "Could NOT find Python3"
set(CMAKE_DISABLE_FIND_PACKAGE_rosidl_generator_py TRUE)

find_package(rosidl_default_generators REQUIRED)
find_package(rclcpp REQUIRED)
find_package(std_msgs REQUIRED)
find_package(sensor_msgs REQUIRED)

# 定义自定义消息
set(msg_files
  "msg/Point2D.msg"
  "msg/Box.msg"
  "msg/DetectionResult.msg"
)

# ⚠️ 注意：不要加 "LANGUAGE cpp"，这不是合法参数！
rosidl_generate_interfaces(${PROJECT_NAME}
  ${msg_files}
  DEPENDENCIES std_msgs sensor_msgs
)

# ==================== OpenCV ====================
# 使用工具链 sysroot 中的 OpenCV（完整版）
set(TOOLCHAIN_SYSROOT /opt/atk-dlrk3588-toolchain/aarch64-buildroot-linux-gnu/sysroot)
set(OPENCV_INCLUDE_DIRS ${TOOLCHAIN_SYSROOT}/usr/include/opencv4)
set(OPENCV_LIB_DIR ${TOOLCHAIN_SYSROOT}/usr/lib)
set(OPENCV_LIBS
  ${OPENCV_LIB_DIR}/libopencv_core.so
  ${OPENCV_LIB_DIR}/libopencv_imgproc.so
  ${OPENCV_LIB_DIR}/libopencv_imgcodecs.so
  ${OPENCV_LIB_DIR}/libopencv_videoio.so
  ${OPENCV_LIB_DIR}/libopencv_highgui.so
)

# ==================== 源文件 ====================
file(GLOB EAI_BOT_SRC src/*.cpp)

# ==================== 可执行文件 ====================
add_executable(eai_bot_app ${EAI_BOT_SRC})

target_include_directories(eai_bot_app PRIVATE
  include
  ${OPENCV_INCLUDE_DIRS}
)

# 链接 ROS2 和 OpenCV
ament_target_dependencies(eai_bot_app rclcpp std_msgs sensor_msgs)
target_link_libraries(eai_bot_app ${OPENCV_LIBS})

# 让自定义消息头文件能被找到
rosidl_get_typesupport_target(cpp_typesupport_target ${PROJECT_NAME} rosidl_typesupport_cpp)
target_link_libraries(eai_bot_app "${cpp_typesupport_target}")

# ==================== 交叉编译链接修复 ====================
# 这是交叉编译最容易出错的地方！
if(DEFINED ROS_SYSROOT)
  target_link_options(eai_bot_app PRIVATE
    # 把链接器的 sysroot 切换到板端，
    # 这样链接器才能在板端目录里找到 ROS 依赖的系统库
    -Wl,--sysroot=${ROS_SYSROOT}

    # 告诉链接器：解析 .so 的间接依赖时，也去这些目录找找
    -Wl,-rpath-link,${TOOLCHAIN_SYSROOT}/usr/lib
    -Wl,-rpath-link,${TOOLCHAIN_SYSROOT}/lib
    -Wl,-rpath-link,${ROS_SYSROOT}/lib/aarch64-linux-gnu
    -Wl,-rpath-link,${ROS_SYSROOT}/usr/lib/aarch64-linux-gnu

    # 显式指定动态链接器路径
    -Wl,--dynamic-linker=/lib/aarch64-linux-gnu/ld-linux-aarch64.so.1
  )
endif()

# ==================== 安装规则 ====================
install(TARGETS eai_bot_app DESTINATION lib/${PROJECT_NAME})

# ⚠️ 用 CMAKE_SOURCE_DIR 避免相对路径层级算错
install(DIRECTORY ${CMAKE_SOURCE_DIR}/../../model/ DESTINATION model)

ament_package()
```

---

### 4.4 Relationship among the three

Please pay special attention to the location of `CMakeLists.txt` —it is the "main battlefield" of the entire cross-compilation process. The toolchain files only solve the problem of "what to compile," while "what to compile, how to chain, and where to install" are all in `CMakeLists.txt` .

**Division of labor among the three documents:**

document | Role | What does it matter? | No matter what
:-- | :-- | :-- | :--
`toolchain_rk3588.cmake` | Global infrastructure | Compiler selection, basic sysroot, search strategy | Which libraries are specifically linked, and how are messages generated?
`CMakeLists.txt` | Package-level build logic⭐ | Dependency lookup, message generation, link options, installation rules | Which compiler and search strategy to use?
`build-linux.sh` | Glue/Inlet | Assemble parameters, call colcon, and clean up the environment. | Any construction logic itself

---

## V. Real-life Experiences of Falling into Pitfalls

> Each issue is organized in the format of error message → one-sentence reason → fix method → ​​explanation of the underlying principle, making it easy for you to find the one that applies to you.

### Pitfall 1: `rosidl_generate_interfaces` reports that `LANGUAGE` file does not exist.

error message:

```
CMake Error:
  rosidl_generate_interfaces() the passed file 'LANGUAGE' doesn't exist
```

`LANGUAGE cpp` is not a valid parameter for this function; CMake treats `LANGUAGE` as a message file path.

repair:

```
# ❌ 错误写法
rosidl_generate_interfaces(${PROJECT_NAME} ${msg_files} LANGUAGE cpp)

# ✅ 正确写法：直接删掉 LANGUAGE cpp
rosidl_generate_interfaces(${PROJECT_NAME} ${msg_files})
```

`rosidl_generate_interfaces()` only accepts a list of message file paths and the `DEPENDENCIES` keyword. Unlike some CMake functions, it does not have a `LANGUAGE` option. CMake treats all unrecognized arguments as file paths.

### Pitfall 2: Unable to find Python 3 development components

error message:

```
Could NOT find Python3 (missing: Python3_INCLUDE_DIRS Python3_LIBRARIES)
```

Reason: ** ROS2 message generation includes the Python version by default, and it looks for Python development header files in sysroot—but they are not in sysroot.

Repair (three-pronged approach):

cmake

```
# ① CMakeLists.txt 中禁用 Python 生成器
set(CMAKE_DISABLE_FIND_PACKAGE_rosidl_generator_py TRUE)
find_package(rosidl_default_generators REQUIRED)
```

bash

```
# ② build-linux.sh 中指定宿主机 Python
-DPython3_EXECUTABLE=$(which python3)
```

cmake

```
# ③ 工具链文件中确保有这一行
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
```

`rosidl_default_generators` by default calls `rosidl_generator_py` to generate Python bindings. During cross-compilation, we don't need (and can't) run Python generation scripts on the board, so we disable it. `Python3_EXECUTABLE` ensures that other steps requiring Python (such as `ament_cmake` script) use Python that the host machine can run.

### Pitfall 3: The linker cannot find `libyaml` , `libspdlog` , and `liblttng-ust`

error message:

```
ld: warning: libyaml-0.so.2, needed by .../librcl.so, not found
ld: undefined reference to `spdlog::logger::log(...)'
```

Reason: The board-side sysroot only copied `/opt/ros/jazzy` , missing the system libraries that ROS2 depends on.

repair:

Step 1: Check which libraries are missing on the development board:

```
ldd /opt/ros/jazzy/lib/librcl.so | grep "not found"
```

Step 2: Copy the missing libraries from the development board to the host machine's sysroot:

```
scp firefly@192.168.1.100:/lib/aarch64-linux-gnu/libyaml-0.so.2 \
    ~/software/rk_sysroot/lib/aarch64-linux-gnu/
```

Step 3: Ensure that `-rpath-link` is present in `CMakeLists.txt` (see Section 4.3).

`-rpath-link` does not affect runtime; it only affects the resolution of indirect dependencies **during linking** . For example, if your program links to `librclcpp.so` , and `librclcpp.so` depends on `libyaml-0.so.2` , the linker needs to find `libyaml` to verify symbols—- `-rpath-link` tells it to "look in these directories".

### Pitfall 4: `cv::VideoCapture` is not defined

error message:

```
error: 'VideoCapture' is not a member of 'cv'
```

The OpenCV library included with the project is incomplete, lacking `videoio` module.

Fix: Instead of using the project's built-in OpenCV, use the full OpenCV toolchain from sysroot (see Section 4.3, OpenCV section).

Toolchain vendors typically provide a complete OpenCV version that is compatible with the compiler's ABI. Projects may include a trimmed version, lacking certain modules. Using the toolchain version also avoids ABI issues caused by GCC version incompatibility.

### Pitfall 5: Dynamic linker `ld-linux-aarch64.so.1` not found.

error message:

```
ld: cannot find /lib/ld-linux-aarch64.so.1 inside .../rk_sysroot
```

After switching to the board side using `--sysroot` , the linker searches for `/lib/ld-linux-aarch64.so.1` by default, but Ubuntu places it under `/lib/aarch64-linux-gnu/` .

repair:

```
target_link_options(eai_bot_app PRIVATE
  -Wl,--dynamic-linker=/lib/aarch64-linux-gnu/ld-linux-aarch64.so.1
)
```

This is a path layout specific to Ubuntu/Debian. `--dynamic-linker` specifies the `PT_INTERP` segment written to the ELF file, which determines which dynamic linker the kernel loads at runtime. The path must be an absolute path on the target board, not on the host machine.

### Pitfall 6: Model files not found during installation.

error message:

```
CMake Error: file INSTALL cannot find ".../src/eai_bot/../model/coco_80_labels_list.txt"
```

`../model` starts from `src/eai_bot` and actually points to `src/model` , but the file is located in `model/` directory of the workspace root directory.

repair:

```
# ❌ 容易算错层级
install(DIRECTORY ../model/ DESTINATION model)

# ✅ 用 CMAKE_SOURCE_DIR，不依赖相对层级
install(DIRECTORY ${CMAKE_SOURCE_DIR}/../../model/ DESTINATION model)

# ✅ 更好的做法：在 build-linux.sh 中传入路径
# -DMODEL_DIR=${ROOT_PWD}/model
```

In CMake, `CMAKE_SOURCE_DIR` points to the source directory of the current package (i.e., `src/eai_bot` ), and the working directory root is two levels above it. Passing the path using a variable is the least error-prone method.

---

## VI. Summary of Practice

- Sysroot Management: Clearly distinguish the roles of toolchain sysroot and board-side ROS sysroot, and make reasonable use of CMAKE_SYSROOT and -Wl,--sysroot,-rpath-link.
- Dependency integrity: Use ldd -r on the development board to check the ROS library dependencies and ensure that the corresponding files are in sysroot, and ensure that there are no `not found` .
- Prioritize using third-party libraries that come with the toolchain (such as OpenCV) to avoid ABI incompatibility.
- Path generalization: Use variables or CMake built-in variables as much as possible to reduce hard coding.
- Disable unnecessary features: For example, disable generators if Python message support is not needed, and avoid unnecessary dependencies.
