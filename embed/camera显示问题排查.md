<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2026 KY (kyshipit)
-->

# RK3588 Ubuntu 移植摄像头显示问题

## 一、问题现象

- 硬件平台：ATK-DLRK3588 开发板 + 5.5寸 MIPI 屏幕

- 系统环境：Ubuntu 24.04（从 Buildroot 系统移植的完整环境）

- 应用程序：edgeai_app（在 Buildroot 系统上能正常运行并显示摄像头画面）

- 初始错误现象：运行程序后无任何窗口弹出，终端日志显示摄像头已打开（CameraSource: opened index 71），但无显示画面

## 二、最终有效的解决命令汇总

```
# 1. 修改配置文件
# 编辑 /userdata/rknn_eai_rk3588/config/default.yaml
# 将 input.source 从 "/dev/video-camera0" 改为 "/dev/video45"

# 2. 设置环境变量
export DISPLAY=:0
export XAUTHORITY=/root/.Xauthority
export QT_QPA_PLATFORM_PLUGIN_PATH=/usr/lib/aarch64-linux-gnu/qt5/plugins
export QT_QPA_PLATFORM=xcb
```

### 环境变量永久保存（可选）

```
cat >> /root/.bashrc << 'EOF'
export DISPLAY=:0
export XAUTHORITY=/root/.Xauthority
export QT_QPA_PLATFORM_PLUGIN_PATH=/usr/lib/aarch64-linux-gnu/qt5/plugins
export QT_QPA_PLATFORM=xcb
EOF
source /root/.bashrc
```

**那是不是移植的时候直接放到原来对应的位置就没有问题？**

- 你无法轻易将插件“放到Buildroot原来的位置”，因为**Buildroot和Ubuntu的根文件系统目录结构完全不同**。

- Buildroot中Qt插件的默认安装路径通常是 /usr/lib/qt/plugins。而Ubuntu上Qt插件的实际位置是 /usr/lib/aarch64-linux-gnu/qt5/plugins。强行把插件复制到 /usr/lib/qt/plugins 会带来一系列问题：

1. 破坏系统规范：Ubuntu有自己严格的文件系统层级标准（FHS），把文件放到非标准位置可能会与其他软件包冲突，或导致系统工具无法识别。

1. 破坏包管理器数据库：dpkg 等包管理器会记录每个文件的归属。手动添加文件到系统目录，会导致包管理器数据库不一致，可能引发后续软件安装或升级失败。

1. 无法解决根本问题：Qt库本身在编译时就硬编码了插件路径。就算你把插件放过去，Qt库可能仍然会去它硬编码的另一个路径查找。

结论：与其费力去“还原”一个在Ubuntu上本就不存在的目录结构，**通过环境变量或 ****qt.conf**** 文件来“告诉”Qt插件的新位置，是更标准、更干净、更符合Qt设计哲学的解决方案**。通过设置 QT_QPA_PLATFORM_PLUGIN_PATH 环境变量成功解决了问题，这**本身就是Qt官方文档中明确指出的标准做法**。

- QT_QPA_PLATFORM_PLUGIN_PATH 用于**指定平台插件（platform plugin）安装的目录路径**

- 当 Qt 应用程序找不到平台插件（如libqxcb.so）时，需要通过这个环境变量告诉 Qt 去哪里找

- 平台插件（如 xcb）通常放在 platforms/ 子目录下，设置 QT_QPA_PLATFORM_PLUGIN_PATH=/usr/lib/aarch64-linux-gnu/qt5/plugins 正是告诉 Qt：xcb 平台插件在 /usr/lib/aarch64-linux-gnu/qt5/plugins/platforms/ 目录下。

## 三、所有有效的排查命令和操作（按时间顺序，含完整脚本）

### 操作 1：验证摄像头硬件和驱动正常

```
# 在开发板上抓取一帧
v4l2-ctl -d /dev/video45 --set-fmt-video=width=1920,height=1080,pixelformat=NV12 --stream-mmap --stream-to=/tmp/test.raw --stream-count=1

# 在 PC 上显示
scp root@192.168.124.3:/tmp/test.raw ~/
ffplay -f rawvideo -pixel_format nv12 -video_size 1920x1080 ./test.raw
```

**结果**：画面正常显示。

**结论**：摄像头硬件、驱动、/dev/video45 节点正常。

### 操作 2：检查 DISPLAY 环境变量

```
echo $DISPLAY
# 输出为空，发现问题
export DISPLAY=:0
```

### 操作 3：测试 OpenCV 简单显示

**创建 ****/tmp/test_show.py****：**

```
#!/usr/bin/env python3
import cv2
import numpy as np

img = np.zeros((300, 300, 3), dtype=np.uint8)
cv2.rectangle(img, (50, 50), (250, 250), (0, 255, 0), -1)
cv2.imshow("Test Window", img)
print("窗口已创建，按任意键关闭...")
cv2.waitKey(0)
cv2.destroyAllWindows()
```

**运行：**

```
export DISPLAY=:0
python3 /tmp/test_show.py
```

**结果**：绿色方块弹出。

**结论**：OpenCV 的 imshow 和 X11 环境正常。

### 操作 4：测试 OpenCV 直接打开摄像头

```
python3 -c "import cv2; cap=cv2.VideoCapture('/dev/video45', cv2.CAP_V4L2); print(cap.isOpened())"
# 输出 False
```

**结论**：OpenCV 的 V4L2 后端无法直接打开 /dev/video45（但不是最终问题，因为程序用了别的打开方式）。

### 操作 5：创建 v4l2-ctl 抓帧显示脚本验证通路

**创建 ****/userdata/show_camera.py****：**

```
#!/usr/bin/env python3
import subprocess
import numpy as np
import cv2
import time
import os

os.environ["DISPLAY"] = ":0"
os.environ["XAUTHORITY"] = "/root/.Xauthority"
os.environ["XDG_RUNTIME_DIR"] = "/run/user/0"
os.environ["QT_QPA_PLATFORM"] = "xcb"
os.environ["GDK_BACKEND"] = "x11"

DEVICE = "/dev/video45"
WIDTH, HEIGHT = 640, 480
FRAME_SIZE = WIDTH * HEIGHT * 3 // 2

CMD = [
    "v4l2-ctl", "-d", DEVICE,
    "--set-fmt-video", f"width={WIDTH},height={HEIGHT},pixelformat=NV12",
    "--stream-mmap", "--stream-to=-", "--stream-count=1"
]

cv2.namedWindow("Camera", cv2.WINDOW_NORMAL)
cv2.resizeWindow("Camera", WIDTH, HEIGHT)
print("按 'q' 键退出预览")

while True:
    proc = subprocess.Popen(CMD, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    raw_data, _ = proc.communicate()
    if len(raw_data) == FRAME_SIZE:
        yuv = np.frombuffer(raw_data, dtype=np.uint8).reshape((HEIGHT * 3 // 2, WIDTH))
        bgr = cv2.cvtColor(yuv, cv2.COLOR_YUV2BGR_NV12)
        cv2.imshow("Camera", bgr)
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break
cv2.destroyAllWindows()
```

**运行：**

```
export DISPLAY=:0
python3 /userdata/show_camera.py
```

**结果**：画面显示。

**结论**：通过 v4l2-ctl 子进程抓帧 + OpenCV 显示可行。

### 操作 6：运行 edgeai_app 查看日志

```
cd /userdata/rknn_eai_rk3588
./edgeai_app 2>&1 | tee /tmp/edgeai.log
```

日志显示：

```
[INFO] CameraSource: opened index 71 (path /dev/video71)
[INFO] CameraSource: capture resolution 640x480
[INFO] OpenCVDisplaySink: GUI ok, screen=1080x1920
```

程序打开了摄像头但无窗口。

### 操作 7：检查 X11 窗口

```
xwininfo -root -tree | grep -i "opencv\|camera\|edgeai"
# 没有输出
```

### 操作 8：授权 X11 连接

在 MIPI 屏幕的桌面终端（普通用户）执行：

```
xhost +
```

在串口 root 终端执行：

```
export XAUTHORITY=/root/.Xauthority
```

### 操作 9：测试 xclock

```
xclock
# 卡住，无窗口弹出
```

### 操作 10：重启窗口管理器

```
ps aux | grep xfwm4
pkill xfwm4
xfwm4 --replace &
sleep 2
xclock
```

**结果**：xclock 成功弹出时钟窗口。

**结论**：窗口管理器卡死，重启后恢复。

### 操作 11：再次运行 edgeai_app 发现 Qt 错误

```
qt.qpa.plugin: Could not find the Qt platform plugin "xcb" in ""
This application failed to start because no Qt platform plugin could be initialized.
```

### 操作 12：查找并设置 Qt 插件路径

```
find /usr -name "libqxcb.so" 2>/dev/null
# 输出：/usr/lib/aarch64-linux-gnu/qt5/plugins/platforms/libqxcb.so

export QT_QPA_PLATFORM_PLUGIN_PATH=/usr/lib/aarch64-linux-gnu/qt5/plugins
export QT_QPA_PLATFORM=xcb
```

### 操作 13：查看日志发现设备节点错误

日志显示：

```
[ERROR] Main: failed to open input source '/dev/video-camera0'
```

### 操作 14：确认 video71 无法工作

```
v4l2-ctl -d /dev/video71 --set-fmt-video=width=640,height=480,pixelformat=NV12 --stream-mmap --stream-to=/tmp/test.raw --stream-count=1
# 失败
```

### 操作 15：修改配置文件

```
vim /userdata/rknn_eai_rk3588/config/default.yaml
```

将 input.source 从 /dev/video-camera0 改为 /dev/video45。

### 操作 16：最终成功运行

```
export DISPLAY=:0
export XAUTHORITY=/root/.Xauthority
export QT_QPA_PLATFORM_PLUGIN_PATH=/usr/lib/aarch64-linux-gnu/qt5/plugins
export QT_QPA_PLATFORM=xcb
cd /userdata/rknn_eai_rk3588
./edgeai_app
```

**结果**：画面成功弹出。

### 操作 17：验证 camera-stream.service 是否多余

```
ps -ef | grep rkaiq_3A_server | grep -v grep
# 有输出，官方 3A 服务在运行

systemctl stop camera-stream.service
systemctl disable camera-stream.service

# 再次运行 edgeai_app，画面正常
```

**结论**：camera-stream.service 多余，可删除。

## 四、排查过程中的错误推断、错误操作及如何被推翻（完整清单）

### 错误推断 1：“OpenCV 的 V4L2 后端不支持 RK3588”

**AI 的推断**：

> “OpenCV 的 V4L2 后端无法处理 RK3588 ISP 驱动的 DMA/CMA 内存访问，导致 VideoCapture 打开失败。”


**实际验证**：

```
# 测试 OpenCV 直接打开 video45
python3 -c "import cv2; cap=cv2.VideoCapture('/dev/video45', cv2.CAP_V4L2); print(cap.isOpened())"
# 输出 False
```

**如何推翻**：

1. v4l2-ctl  能正常抓图，说明硬件和驱动正常。

1. edgeai_app 最终能正常打开 video45 并显示画面，证明 OpenCV 本身能正常工作。

1. 真正的问题不是 OpenCV 不支持 RK3588，而是程序用了错误的设备节点和缺少 Qt 环境变量。

**官方依据**：Rockchip 的 ISP 驱动（rockchip-isp1）基于标准 V4L2 和 Media Controller 框架，任何兼容 V4L2 的应用理论上都可以访问。OpenCV 的 V4L2 后端是标准实现，不存在“不支持”的问题。

### 错误推断 2：“GStreamer 插件没移植过来导致问题”

**AI 的推断**：

> “Buildroot 的 GStreamer V4L2 插件（libgstv4l2.so）没有移植到 Ubuntu，导致 GStreamer 后端无法工作，所以 OpenCV 打不开摄像头。”


**实际验证**：

```
# 找 libgstv4l2.so
find /usr -name "libgstv4l2*.so" 2>/dev/null
# 找不到
```

**如何推翻**：

1. 程序 ldd 显示链接的是 Buildroot 的 OpenCV 库（/lib/libopencv_*.so.409），这些库在 Buildroot 上编译时，通过 ldd 可以检查其依赖关系。

1. gst-launch 失败是工具本身的问题，与程序无关。

1. 程序使用 Qt 后端显示，不依赖 GStreamer 插件。

**官方依据**：OpenCV 的 highgui 模块可以编译为 Qt 后端或 GTK 后端，不依赖 GStreamer 显示。程序使用的是 Qt 后端，与 GStreamer 无关。

### 错误推断 3：“DMA/CMA 内存访问方式不兼容”

**AI 的推断**：

> “OpenCV 的 V4L2 后端只支持虚拟地址访问，不支持 RK3588 ISP 驱动要求的 DMA/CMA 物理地址访问，导致 VIDIOC_REQBUFS 失败。”


**实际验证**：

```
# v4l2-ctl 使用 MMAP 方式能正常抓图
v4l2-ctl -d /dev/video45 --set-fmt-video=width=640,height=480,pixelformat=NV12 --stream-mmap --stream-to=/tmp/test.raw --stream-count=1
# 成功
```

**如何推翻**：

1. v4l2-ctl 使用 MMAP 方式能正常抓图，说明 MMAP 模式是支持的。

1. edgeai_app 最终能正常显示画面，证明 OpenCV 能正常处理 DMA/CMA 内存。

1. 真正的问题是程序用了错误的设备节点（/dev/video71），而不是内存访问方式不兼容。

**官方依据**：v4l2-ctl 是 V4L2 官方测试工具，它成功使用 MMAP 模式说明驱动完全支持 MMAP。OpenCV 的 V4L2 后端同样使用 MMAP 模式，不存在“不支持”的问题。

### 错误推断 4：“Ubuntu 的 OpenCV 是 headless 版本”

**AI 的推断**：

> “Ubuntu 上通过 apt install python3-opencv 安装的 OpenCV 是 headless 版本，不支持 GUI 显示，所以 imshow 无法弹出窗口。”


**实际验证**：

```
# 检查程序链接的库
ldd /userdata/rknn_eai_rk3588/edgeai_app | grep opencv
# 输出：libopencv_core.so.409 => /lib/libopencv_core.so.409
```

**如何推翻**：

1. ldd 显示程序链接的是 Buildroot 的 OpenCV 库（/lib/libopencv_*.so.409），不是 Ubuntu 的 Python 包。

1. 之前 test_show.py 能正常弹出绿色方块窗口，证明 OpenCV 的 imshow 功能正常。

1. 问题不在 OpenCV 的 GUI 能力，而在环境变量和配置。

**官方依据**：OpenCV 的 highgui 模块编译时可以选择 Qt 或 GTK 后端。程序链接的 Buildroot 库带有完整的 Qt 后端支持，不是 headless 版本。

### 错误推断 5：“XFCE 不用 Wayland，Wayland 设置无效”

**AI 的推断**：

> “XFCE 是基于 X11 的桌面环境，不涉及 Wayland。用户设置 Wayland 相关环境变量是多余的，不会影响任何东西。”


**实际验证**：

```
# 用户之前设置过 Wayland 变量，消除了 OpenCV 的 "window disabled" 警告
export XDG_RUNTIME_DIR=/run/user/0
export WAYLAND_DISPLAY=wayland-0
```

**如何推翻**：

1. 用户通过设置 Wayland 变量成功消除了 OpenCV 的  OpenCVDisplaySink: no DISPLAY/WAYLAND_DISPLAY, window disabled 警告。

1. 虽然 XFCE 默认使用 X11，但系统可能同时存在 Wayland 兼容层或 Wayland 套接字。

1. 设置 Wayland 变量有效，说明系统确实涉及 Wayland 相关机制。

**官方依据**：Wayland 和 X11 可以在同一系统上共存（通过 XWayland）。XFCE 虽然基于 X11，但系统可能运行了 Wayland 合成器或相关服务。

### 错误推断 6：“移植过来的 OpenCV 库不兼容 Ubuntu 内核”

**AI 的推断**：

> “Buildroot 上编译的 OpenCV 库依赖于 Buildroot 内核的特定接口，在 Ubuntu 内核上运行会导致 V4L2 ioctl 调用失败。”


**实际验证**：

```
# 程序最终能正常运行
export QT_QPA_PLATFORM_PLUGIN_PATH=/usr/lib/aarch64-linux-gnu/qt5/plugins
./edgeai_app
# 画面成功弹出
```

**如何推翻**：

1. 程序在 Ubuntu 上最终能正常运行并显示摄像头画面，证明 Buildroot 的 OpenCV 库在 Ubuntu 上完全兼容。

1. V4L2 ioctl 是内核标准接口，应用程序不直接依赖内核版本。

1. 问题不在库的兼容性，而在环境变量和配置。

**官方依据**：V4L2 是 Linux 内核的标准接口，具有稳定的 ABI。应用程序通过 V4L2 ioctl 与驱动通信，不依赖于特定内核版本。glibc 保证库接口的向后兼容性。

### 错误推断 7：“camera-stream.service 是 ISP 3A 必须的服务”

**AI 的推断**：

> “ISP 3A（自动曝光、自动白平衡、自动对焦）需要持续的视频流来触发，所以 camera-stream.service 是必要的，它通过持续的 gst-launch 流来保持 3A 工作。”


**实际验证**：

```
# 检查官方 3A 服务
ps -ef | grep rkaiq_3A_server | grep -v grep
# 有输出：root 323 1 0 06:06 ? 00:00:27 /usr/bin/rkaiq_3A_server

# 停止并禁用自定义服务
systemctl stop camera-stream.service
systemctl disable camera-stream.service

# 再次运行 edgeai_app，画面正常
```

**如何推翻**：

1. Rockchip 官方 3A 服务 rkaiq_3A_server 已独立运行，不需要额外的流来触发。

1. 禁用 camera-stream.service 后，程序画面仍然正常，证明该服务对 3A 没有贡献。

1. 该服务使用的设备节点 /dev/video-camera0（指向 video71）本身就是错误的，服务从未真正工作过。

**官方依据**：Rockchip 官方文档明确说明，rkaiq_3A_server 是一个独立的后台守护进程，会自动完成 3A 调优，应用程序只需要从 /dev/videoX 节点读取数据流。不需要额外启动任何“触发流”。

### 错误推断 8：“需要从源码重新编译 OpenCV”

**AI 的推断**：

> “Ubuntu 上的 OpenCV 与 RK3588 不兼容，需要从源码重新编译 OpenCV，并添加 Rockchip 专用补丁。”


**实际验证**：

```
# 最终只改了配置和环境变量，没有重新编译任何东西
vim config/default.yaml   # 改设备节点
export QT_QPA_PLATFORM_PLUGIN_PATH=...  # 设环境变量
./edgeai_app  # 成功运行
```

**如何推翻**：

1. 最终解决方案不涉及任何编译操作。

1. Buildroot 的 OpenCV 库在 Ubuntu 上完全可用。

1. 重新编译是完全没有必要的操作。

**官方依据**：OpenCV 是跨平台的，编译好的二进制库在相同架构（aarch64）上可以跨系统运行（依赖 glibc 兼容性）。Buildroot 的库本身就在 aarch64 上编译，Ubuntu 也是 aarch64，不需要重新编译。

### 错误推断 9：“需要修改 V4L2 驱动或设备树”

**AI 的推断**：

> “RK3588 的摄像头驱动或设备树配置有问题，导致 OpenCV 无法正确识别摄像头设备节点。”


**实际验证**：

```
# v4l2-ctl 能正常抓图
# edgeai_app 最终能正常显示
# 没有任何驱动或设备树修改
```

**如何推翻**：

1. v4l2-ctl 抓图成功证明驱动和设备树完全正常。

1. 最终没有修改任何驱动或设备树。

1. 问题全在用户态环境配置。

**官方依据**：Rockchip 提供的设备树和驱动是经过验证的，v4l2-ctl 能正常工作就证明底层没有问题。

### 错误推断 10：“需要复制 Buildroot 的 GStreamer 插件”

**AI 的推断**：

> “Buildroot 的 GStreamer V4L2 插件需要复制到 Ubuntu，否则 OpenCV 的 GStreamer 后端无法工作。”


**实际验证**：

```
# 在 Buildroot 源码中找 libgstv4l2.so
find . -name "libgstv4l2*.so" 2>/dev/null
# 只找到 libgstv4l2codecs.so，没有 libgstv4l2.so

# 程序不依赖 GStreamer 插件
ldd edgeai_app | grep gst
# 没有任何 GStreamer 相关的输出（或者只有 Ubuntu 系统的 GStreamer 库）
```

**如何推翻**：

1. Buildroot 源码中不存在 libgstv4l2.so，只有 libgstv4l2codecs.so（这是编解码插件，不是源插件）。

1. 程序不依赖 GStreamer 插件显示。

1. 复制 GStreamer 插件对解决显示问题没有任何帮助。

**官方依据**：OpenCV 的 videoio 模块可以使用 GStreamer 后端，但 edgeai_app 通过 ldd 检查显示它链接的是直接 V4L2 访问的 OpenCV 库，而非 GStreamer 后端。Buildroot 中 GStreamer V4L2 源插件可能被命名为 libgstvideo4linux2.so 而非 libgstv4l2.so。

### 错误推断 11：“GStreamer 与 RK3588 ISP 驱动存在兼容性问题”

**AI 的推断**：

> “GStreamer 的 v4l2src 插件与 RK3588 ISP 驱动存在兼容性问题，导致 gst-launch 报错 Failed to allocate required memory，所以需要解决这个兼容性问题程序才能工作。”


**实际验证**：

```
# 尝试各种 io-mode 都失败
gst-launch-1.0 v4l2src device=/dev/video45 io-mode=1 ! ...
gst-launch-1.0 v4l2src device=/dev/video45 io-mode=4 ! ...
# 全部报错 Failed to allocate required memory

# 但 edgeai_app 能正常工作
```

**如何推翻**：

1. gst-launch 报错只影响 GStreamer 工具本身，与 edgeai_app 无关。

1. edgeai_app 不依赖 GStreamer 显示，所以不需要解决这个报错。

1. 该说法是社区现象归纳，非 Rockchip 官方原文。Rockchip 官方实际提供了专用插件 rkcamsrc 并持续为 v4l2src 提交补丁，但标准 v4l2src 配合正确的 media-ctl 配置也可以工作。

**官方依据**：

- Rockchip 官方文档提供了专用插件 rkcamsrc，修改自 v4l2src。

- 官方文档指出，使用标准 v4l2src 前必须通过 media-ctl 正确配置 media pipeline。

- 这不是“兼容性问题”，而是“需要正确配置”的问题。

### 错误推断 12：“OpenCV 不支持 DMA/CMA 内存访问”

**AI 的推断**：

> “OpenCV 的 V4L2 后端默认使用虚拟地址访问，不支持 RK3588 ISP 驱动要求的 DMA/CMA 物理地址访问。”


**实际验证**：

```
# OpenCV 最终能正常抓图和显示
./edgeai_app  # 成功显示画面
```

**如何推翻**：

1. v4l2-ctl 使用 MMAP 模式能正常抓图，证明驱动支持 MMAP。

1. OpenCV 的 V4L2 后端同样使用 MMAP 模式，没有理由不支持。

1. 程序最终能正常抓图并显示，证明 OpenCV 能正确处理 DMA/CMA 内存。

**官方依据**：MMAP 是 V4L2 标准的内存映射方式，所有兼容 V4L2 的驱动都必须支持。OpenCV 的 V4L2 后端使用标准的 MMAP 方式，不存在“不支持 DMA/CMA”的问题。

### 错误推断 13：“窗口管理器卡死是因为 X11 配置问题”

**AI 的推断**：

> “X11 的配置文件有问题，或者显示服务器配置错误，导致窗口无法创建。”


**实际验证**：

```
pkill xfwm4
xfwm4 --replace &
xclock  # 成功弹出
```

**如何推翻**：

1. 重启 xfwm4 后 xclock 能正常弹出，证明 X11 配置没问题。

1. 问题只是 xfwm4 进程本身卡死了。

1. 这是用户态进程问题，不是系统配置问题。

**官方依据**：xfwm4 是 XFCE 的窗口管理器，卡死可能是因为之前的窗口操作导致进程状态异常。重启进程即可恢复，与 X11 配置无关。

### 错误推断 14：“Qt 插件路径问题是因为 Qt 没有正确安装”

**AI 的推断**：

> “Ubuntu 系统上 Qt 没有正确安装，导致 Qt 平台插件缺失。”


**实际验证**：

```
find /usr -name "libqxcb.so" 2>/dev/null
# 输出：/usr/lib/aarch64-linux-gnu/qt5/plugins/platforms/libqxcb.so

export QT_QPA_PLATFORM_PLUGIN_PATH=/usr/lib/aarch64-linux-gnu/qt5/plugins
# 程序正常工作
```

**如何推翻**：

1. libqxcb.so 文件存在，说明 Qt 已正确安装。

1. 问题只是环境变量 QT_QPA_PLATFORM_PLUGIN_PATH 未设置，Qt 找不到插件路径。

1. 设置环境变量后程序正常工作，证明 Qt 本身没问题。

**官方依据**：Qt 的插件搜索路径默认在编译时指定。在交叉编译或移植环境中，可能需要通过 QT_QPA_PLATFORM_PLUGIN_PATH 环境变量显式指定插件路径。

### 错误推断 15：“xhost + 是多余的，应该通过 XAUTHORITY 解决”

**AI 的推断**：

> “xhost + 会降低安全性，应该通过正确设置 XAUTHORITY 环境变量来授权 root 用户连接 X Server。”


**实际验证**：

```
# 在桌面终端执行 xhost +
xhost +
# access control disabled, clients can connect from any host

# 在 root 终端执行
export XAUTHORITY=/root/.Xauthority
xclock  # 成功弹出
```

**如何推翻**：

1. xhost + 是解决问题的有效方法，简单直接。

1. XAUTHORITY 设置也是有效的，但需要先有授权文件。

1. 两者都是合法的方法，不存在谁对谁错。

**官方依据**：xhost 是 X11 的授权工具，xhost + 关闭访问控制是标准操作。在开发板上，安全性通常不是首要考虑。

## 五、根本原因总结

| 问题 | 发现方式 | 解决方案 | 
| -- | -- | -- |
| 设备节点错误 | 日志 failed to open /dev/video-camera0 | 配置文件改为 /dev/video45 | 
| Qt 插件路径未设置 | 报错 Could not find Qt platform plugin "xcb" | 设置 QT_QPA_PLATFORM_PLUGIN_PATH | 
| 窗口管理器卡死（关联） | xclock 卡住 | pkill xfwm4; xfwm4 --replace & | 
| DISPLAY 未设置（关联） | echo $DISPLAY 为空 | export DISPLAY=:0 | 


**核心只有两条：设备节点 + Qt 插件路径。**

## 六、实际编写的脚本文件清单

| 脚本路径 | 用途 | 
| -- | -- |
| /tmp/test_show.py | 测试 OpenCV 显示是否正常（绿色方块） | 
| /userdata/show_camera.py | 通过 v4l2-ctl 子进程抓帧显示摄像头画面 | 
