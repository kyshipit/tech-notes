<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2026 KY (kyshipit)
-->

# x86 交叉编译 ROS2 Jazzy 到 ARM64：从零跑通 + 踩坑实录

## 一、为什么要在 x86 电脑上交叉编译？

板端 `colcon build` 仅适合早期验证 demo。随着项目依赖增多，板端全量编译耗时会从几分钟膨胀至十几分钟甚至更久；同时嵌入式开发板内存与存储有限，工程量大时易触发内存溢出或磁盘告警，编译还会挤占运行调试资源；此外接入 CI/CD 后，板端编译难以标准化，环境差异也易引入兼容问题。

交叉编译将构建从目标硬件解耦，以配置复杂度换取编译效率、产物一致性与板端资源释放。本文梳理了工具链、sysroot、自定义消息包等全流程踩坑点，助你一次跑通。

------

## 二、先搞懂几个核心概念

### 2.1 交叉编译是什么？

在 A 架构的电脑上，编译出能在 B 架构上运行的程序。

| 角色                | 本文对应                          | 说明                      |
| :------------------ | :-------------------------------- | :------------------------ |
| **宿主机 (Host)**   | x86_64 Ubuntu 24.04               | 你敲代码、跑编译的电脑    |
| **目标机 (Target)** | RK3588 (ARM64)                    | 最终运行程序的板子        |
| **交叉编译器**      | `aarch64-buildroot-linux-gnu-gcc` | 能生成 ARM64 指令的编译器 |

> 💡 类比：交叉编译器就像一个"翻译官"——你用中文（C++ 源码）写了一封信，翻译官直接把它翻译成英文（ARM64 机器码），收信人（ARM64 CPU）直接就能读懂。

### 2.2 sysroot 是什么？为什么需要两个？

sysroot = 目标板文件系统的"镜像副本"。

编译器在编译时需要两样东西：头文件（`.h`）告诉编译器"这个函数长什么样"；库文件（`.so`）在链接时把函数实现"拼"进去。交叉编译时，你总不能把开发板的 `/usr/lib` 整个搬过来用，所以我们需要一个精简版的根文件系统，这就是 sysroot。

为什么需要两个 sysroot？

| Sysroot 类型         | 位置             | 内容                                                         | 提供什么         |
| :------------------- | :--------------- | :----------------------------------------------------------- | :--------------- |
| ① 工具链自带 sysroot | 工具链目录内     | libc, libstdc++, 基础系统库, OpenCV（完整版）                | C/C++ 运行时基础 |
| ② 板端 ROS2 sysroot  | 自己从开发板提取 | `/opt/ros/jazzy` + ROS 依赖的系统库 (libyaml, libspdlog...) | ROS2 及项目依赖  |

> 💡 类比：工具链 sysroot 相当于"厨房里的锅碗瓢盆"（基础工具），板端 sysroot 相当于"菜谱和食材"（ROS2 库）。做菜两样都得有。

### 2.3 CMake 工具链文件是什么？

CMake 默认用宿主机的 `gcc`。交叉编译时，我们需要一份"说明书"告诉 CMake："别用本机的 gcc，用那个交叉编译器；头文件去这个目录找；库去那个目录找……"这份说明书就是工具链文件（Toolchain File），一个以 `.cmake` 结尾的脚本。

### 2.4 colcon 在中间做了什么？

`colcon` 本身不懂交叉编译，它只是把参数透传给 CMake。所有交叉编译的魔法都发生在工具链文件 + CMakeLists.txt里。流程如下：

1. 你运行 `./build-linux.sh`
2. 脚本调用 `colcon build --cmake-args ...`
3. colcon 对每个 ROS2 包执行 `cmake -DCMAKE_TOOLCHAIN_FILE=toolchain.cmake ..`
4. cmake 读取工具链文件和包的 CMakeLists.txt，生成 Makefile
5. make 编译、链接，生成 ARM64 ELF 文件

------

## 三、环境准备

### 3.1 需要什么

| 项目         | 说明                                                         |
| :----------- | :----------------------------------------------------------- |
| 宿主机       | x86_64 Ubuntu 24.04                                          |
| 目标板       | RK3588，运行 Ubuntu 24.04，已装 ROS2 Jazzy (ARM64)           |
| 交叉工具链   | `/opt/atk-dlrk3588-toolchain`（正点原子提供）                |
| 板端 sysroot | 从开发板提取，放在 `~/software/rk_sysroot`                   |
| ROS2 工作区  | `~/work/ros-robot`，含 `src/eai_bot` 等包                    |
| 宿主机工具   | `colcon`、`cmake`、`make`、`python3`、ROS2 Jazzy（仅用其代码生成工具） |

### 3.2 提取板端 sysroot（如果还没有）

在开发板上执行：

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

拷贝到宿主机后解压到 `~/software/rk_sysroot/`，保持目录结构：

```
~/software/rk_sysroot/
├── opt/ros/jazzy/          ← ROS2 本体
├── lib/aarch64-linux-gnu/  ← 系统库
├── usr/lib/aarch64-linux-gnu/
└── usr/include/            ← 头文件（如有需要）
```

### 3.3 宿主机安装构建依赖

```
sudo apt update
sudo apt install -y \
  build-essential cmake ninja-build \
  python3-colcon-common-extensions \
  ros-jazzy-rosidl-default-generators \
  ros-jazzy-rclcpp
```
> ⚠️ 注意：宿主机装 ROS2 只是为了让 colcon 能找到代码生成器，编译出来的二进制是 ARM64 的，跟宿主机 ROS2 无关。

------

## 四、三个核心文件详解

> 这是全文最重要的部分。理解了这三个文件，交叉编译就通了。

### 4.1 工具链文件`toolchain_rk3588.cmake`

放在工作区根目录 `~/work/ros-robot/toolchain_rk3588.cmake`：

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

**逐行解读：**

| 设置                   | 如果不设会怎样                                               |
| :--------------------- | :----------------------------------------------------------- |
| `CMAKE_SYSTEM_NAME`    | CMake 以为你在给本机编译，不会加交叉编译标志                 |
| `CMAKE_C/CXX_COMPILER` | CMake 用本机 `gcc`，编出 x86 二进制，板子跑不了              |
| `CMAKE_SYSROOT`        | 链接器找不到目标架构的 `libc`，直接报错                      |
| `PROGRAM NEVER`        | CMake 可能去 sysroot 里找 Python，试图运行 ARM64 的 Python → 崩溃 |
| `LIBRARY/INCLUDE ONLY` | CMake 可能链接宿主机的 x86 版 `.so` → 链接报错或运行时段错误 |

### 4.2 构建脚本`build-linux.sh`

放在工作区根目录：

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

**参数逐个拆解：**

| 参数                       | 作用                 | 小白理解                                      |
| :------------------------- | :------------------- | :-------------------------------------------- |
| `CMAKE_TOOLCHAIN_FILE`     | 指定工具链文件路径   | "告诉 CMake 去哪读那份说明书"                 |
| `CMAKE_FIND_ROOT_PATH`     | 额外的搜索根目录     | "除了工具链 sysroot，也去板端 sysroot 里找找" |
| `ROS_SYSROOT`              | 自定义变量           | "板端 sysroot 的路径，CMakeLists.txt 里要用"  |
| `Python3_EXECUTABLE`       | 强制用宿主机 Python  | "代码生成用宿主机的 Python，别去找 ARM64 的"  |
| `TARGET_SOC`               | 自定义，标识目标芯片 | "方便 CMakeLists.txt 里做条件编译"            |
| `CMAKE_BUILD_TYPE=Release` | 开启优化             | "编译出的程序更快更小"                        |

### 4.3 包的`CMakeLists.txt`（关键片段 + 注释）

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

------

### 4.4 三者关系

请特别注意 `CMakeLists.txt` 的位置——它是整个交叉编译的"主战场"，工具链文件只解决了"用什么编"的问题，而"编什么、怎么链、装到哪"全在 `CMakeLists.txt` 里。

**三个文件的分工：**

| 文件                     | 角色               | 管什么                                 | 不管什么                     |
| :----------------------- | :----------------- | :------------------------------------- | :--------------------------- |
| `toolchain_rk3588.cmake` | 全局基础设施       | 编译器选型、基础 sysroot、搜索策略     | 具体链接哪些库、消息怎么生成 |
| `CMakeLists.txt`         | 包级构建逻辑 ⭐   | 依赖查找、消息生成、链接选项、安装规则 | 用哪个编译器、搜索策略       |
| `build-linux.sh`         | 胶水/入口          | 组装参数、调用 colcon、清理环境        | 任何构建逻辑本身             |

------

## 五、踩坑实录

> 每个坑都按 错误信息 → 一句话原因 → 修复方法 → 原理解释的格式整理，方便你对号入座。

### 坑 1：`rosidl_generate_interfaces` 报 `LANGUAGE` 文件不存在

错误信息：

```
CMake Error:
  rosidl_generate_interfaces() the passed file 'LANGUAGE' doesn't exist
```

`LANGUAGE cpp` 不是这个函数的合法参数，CMake 把 `LANGUAGE` 当成了消息文件路径。

修复：

```
# ❌ 错误写法
rosidl_generate_interfaces(${PROJECT_NAME} ${msg_files} LANGUAGE cpp)

# ✅ 正确写法：直接删掉 LANGUAGE cpp
rosidl_generate_interfaces(${PROJECT_NAME} ${msg_files})
```

`rosidl_generate_interfaces()` 只接受消息文件路径列表和 `DEPENDENCIES` 关键字。它不像某些 CMake 函数那样有 `LANGUAGE` 选项。CMake 会把所有未识别的参数都当作文件路径来检查。

### 坑 2：找不到 Python3 开发组件

错误信息：

```
Could NOT find Python3 (missing: Python3_INCLUDE_DIRS Python3_LIBRARIES)
```

原因：** ROS2 消息生成默认包含 Python 版本，它会去 sysroot 里找 Python 开发头文件——但 sysroot 里没有。

修复（三管齐下）：

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

`rosidl_default_generators` 默认会调用 `rosidl_generator_py` 来生成 Python 绑定。交叉编译时我们不需要（也做不到）在板端运行 Python 生成脚本，所以直接禁掉。`Python3_EXECUTABLE` 保证其他需要 Python 的步骤（如 `ament_cmake` 脚本）用的是宿主机能跑的 Python。

### 坑 3：链接时找不到 `libyaml`、`libspdlog`、`liblttng-ust`

错误信息：

```
ld: warning: libyaml-0.so.2, needed by .../librcl.so, not found
ld: undefined reference to `spdlog::logger::log(...)'
```

原因：** 板端 sysroot 只拷了 `/opt/ros/jazzy`，漏掉了 ROS2 依赖的系统库。

修复：

Step 1：在开发板上查缺哪些库：

```
ldd /opt/ros/jazzy/lib/librcl.so | grep "not found"
```

Step 2：把缺失的库从开发板拷到宿主机 sysroot：

```
scp firefly@192.168.1.100:/lib/aarch64-linux-gnu/libyaml-0.so.2 \
    ~/software/rk_sysroot/lib/aarch64-linux-gnu/
```

Step 3：确保 `CMakeLists.txt` 中有 `-rpath-link`（见 4.3 节）。

`-rpath-link` 不影响运行时，只影响**链接时**解析间接依赖。比如你的程序链接了 `librclcpp.so`，而 `librclcpp.so` 又依赖 `libyaml-0.so.2`，链接器需要找到 `libyaml` 来验证符号——`-rpath-link` 就是告诉它"去这些目录找"。

### 坑 4：`cv::VideoCapture` 未定义

错误信息：

```
error: 'VideoCapture' is not a member of 'cv'
```

项目自带的 OpenCV 库不完整，缺少 `videoio` 模块。

修复：不用项目自带的，改用工具链 sysroot 中的完整 OpenCV（见 4.3 节 OpenCV 部分）。

工具链厂商通常会提供与编译器 ABI 兼容的完整 OpenCV。项目自带的可能是裁剪版，缺少某些模块。用工具链版本还能避免 GCC 版本不匹配导致的 ABI 问题。

### 坑 5：找不到动态链接器 `ld-linux-aarch64.so.1`

错误信息：

```
ld: cannot find /lib/ld-linux-aarch64.so.1 inside .../rk_sysroot
```

`--sysroot` 切换到板端后，链接器按默认路径 `/lib/ld-linux-aarch64.so.1` 查找，但 Ubuntu 把它放在 `/lib/aarch64-linux-gnu/` 下。

修复：

```
target_link_options(eai_bot_app PRIVATE
  -Wl,--dynamic-linker=/lib/aarch64-linux-gnu/ld-linux-aarch64.so.1
)
```

这是 Ubuntu/Debian 特有的路径布局。`--dynamic-linker` 指定的是写入 ELF 文件的 `PT_INTERP` 段，即程序运行时由内核加载哪个动态链接器。路径必须是目标板上的绝对路径，不是宿主机上的。

### 坑 6：安装阶段找不到模型文件

错误信息：

```
CMake Error: file INSTALL cannot find ".../src/eai_bot/../model/coco_80_labels_list.txt"
```

`../model` 从 `src/eai_bot` 出发，实际指向 `src/model`，但文件在工作区根目录的 `model/`。

修复：

```
# ❌ 容易算错层级
install(DIRECTORY ../model/ DESTINATION model)

# ✅ 用 CMAKE_SOURCE_DIR，不依赖相对层级
install(DIRECTORY ${CMAKE_SOURCE_DIR}/../../model/ DESTINATION model)

# ✅ 更好的做法：在 build-linux.sh 中传入路径
# -DMODEL_DIR=${ROOT_PWD}/model
```

CMake 的 `CMAKE_SOURCE_DIR` 指向当前包的源码目录（即 `src/eai_bot`），往上两级才是工作区根目录。用变量传入路径最不容易出错。

------

## 六、实践总结

- sysroot 管理：明确区分工具链 sysroot 和板端 ROS sysroot 的作用，合理使用 CMAKE_SYSROOT 和 -Wl,--sysroot、-rpath-link。
- 依赖完整性：在开发板上用 ldd -r 检查 ROS 库的依赖，并确保 sysroot 中都有对应文件，确保没有 `not found`。
- 优先用工具链自带的第三方库（如 OpenCV），避免 ABI 不兼容。
- 路径通用化：尽量使用变量或 CMake 内置变量，减少硬编码。
- 禁用不必要的功能：例如不需要 Python 消息支持时禁用生成器，避免不必要的依赖。