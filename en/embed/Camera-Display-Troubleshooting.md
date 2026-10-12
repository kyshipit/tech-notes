**English** | [简体中文](../../embed/camera显示问题排查.md)

<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2026 KY (kyshipit)
-->

# Camera display issue when porting RK3588 Ubuntu

## I. Problem Phenomenon

- Hardware platform: ATK-DLRK3588 development board + 5.5-inch MIPI screen

- System environment: Ubuntu 24.04 (a complete environment ported from Buildroot system)

- Application: edgeai_app (works normally on Buildroot systems and displays camera feed)

- Initial error: After running the program, no window pops up, and the terminal log shows that the camera is turned on (CameraSource: opened index 71), but no image is displayed.

## II. Summary of Ultimately Effective Solutions

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

### Permanently save environment variables (optional)

```
cat >> /root/.bashrc << 'EOF'
export DISPLAY=:0
export XAUTHORITY=/root/.Xauthority
export QT_QPA_PLATFORM_PLUGIN_PATH=/usr/lib/aarch64-linux-gnu/qt5/plugins
export QT_QPA_PLATFORM=xcb
EOF
source /root/.bashrc
```

**So, would it be fine to just place it in the original location during transplantation?**

- You cannot easily "put the plugin in the original location of Buildroot" because **Buildroot and Ubuntu's root file system directory structure are completely different** .

- In Buildroot, the default installation path for Qt plugins is usually `/usr/lib/qt/plugins`. However, on Ubuntu, the actual location of Qt plugins is `/usr/lib/aarch64-linux-gnu/qt5/plugins`. Forcibly copying plugins to `/usr/lib/qt/plugins` will cause a series of problems:

1. Violating system standards: Ubuntu has its own strict File System Hierarchy Standard (FHS). Placing files in non-standard locations may cause conflicts with other software packages or prevent system tools from recognizing them.

2. Disrupting package manager databases: Package managers like dpkg record the ownership of each file. Manually adding files to system directories can cause inconsistencies in the package manager database, potentially leading to installation or upgrade failures.

3. The fundamental problem remains unresolved: the Qt library hardcodes the plugin path during compilation. Even if you place the plugin there, the Qt library may still look for it in a different, hardcoded path.

In conclusion, instead of painstakingly "restoring" a directory structure that doesn't exist on Ubuntu, **using environment variables or the ****qt.conf**** file to "tell" the Qt plugin its new location is a more standard, cleaner, and Qt-inspired solution** . Setting the QT_QPA_PLATFORM_PLUGIN_PATH environment variable successfully resolved the issue, which **is a standard practice explicitly stated in the official Qt documentation** .

- QT_QPA_PLATFORM_PLUGIN_PATH specifies **the directory path for installing platform plugins.**

- When a Qt application cannot find a platform plugin (such as libqxcb.so), this environment variable is needed to tell Qt where to look for it.

- Platform plugins (such as xcb) are usually placed in the platforms/ subdirectory. Setting QT_QPA_PLATFORM_PLUGIN_PATH=/usr/lib/aarch64-linux-gnu/qt5/plugins tells Qt that the xcb platform plugin is located in the /usr/lib/aarch64-linux-gnu/qt5/plugins/platforms/ directory.

## III. All valid investigation commands and operations (in chronological order, including complete scripts)

### Step 1: Verify that the camera hardware and driver are working properly.

```
# 在开发板上抓取一帧
v4l2-ctl -d /dev/video45 --set-fmt-video=width=1920,height=1080,pixelformat=NV12 --stream-mmap --stream-to=/tmp/test.raw --stream-count=1

# 在 PC 上显示
scp root@192.168.124.3:/tmp/test.raw ~/
ffplay -f rawvideo -pixel_format nv12 -video_size 1920x1080 ./test.raw
```

**Result** : The screen displays normally.

**Conclusion** : The camera hardware, driver, and /dev/video45 node are normal.

### Step 2: Check the Display environment variable

```
echo $DISPLAY
# 输出为空，发现问题
export DISPLAY=:0
```

### Operation 3: Testing OpenCV with a simple display

**Create ****/tmp/test_show.py**** :**

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

**run:**

```
export DISPLAY=:0
python3 /tmp/test_show.py
```

**Result** : The green square popped up.

**Conclusion** : The OpenCV imshow and X11 environments are working correctly.

### Operation 4: Test OpenCV by directly opening the camera.

```
python3 -c "import cv2; cap=cv2.VideoCapture('/dev/video45', cv2.CAP_V4L2); print(cap.isOpened())"
# 输出 False
```

**Conclusion** : OpenCV's V4L2 backend cannot directly open /dev/video45 (but this is not the final problem, because the program uses another method to open it).

### Operation 5: Create a v4l2-ctl frame capture and display script to verify the path.

**Create ****/userdata/show_camera.py**** :**

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

**run:**

```
export DISPLAY=:0
python3 /userdata/show_camera.py
```

**Result** : Screen display.

**Conclusion** : Capturing frames using the v4l2-ctl subprocess and displaying them with OpenCV is feasible.

### Step 6: Run edgeai_app and view the logs.

```
cd /userdata/rknn_eai_rk3588
./edgeai_app 2>&1 | tee /tmp/edgeai.log
```

The log shows:

```
[INFO] CameraSource: opened index 71 (path /dev/video71)
[INFO] CameraSource: capture resolution 640x480
[INFO] OpenCVDisplaySink: GUI ok, screen=1080x1920
```

The program opened the camera but no window appeared.

### Operation 7: Inspect the X11 window

```
xwininfo -root -tree | grep -i "opencv\|camera\|edgeai"
# 没有输出
```

### Step 8: Authorize X11 connection

Execute the following on the desktop terminal (for regular users) of the MIPI screen:

```
xhost +
```

Execute the following in the serial port root terminal:

```
export XAUTHORITY=/root/.Xauthority
```

### Operation 9: Test xclock

```
xclock
# 卡住，无窗口弹出
```

### Operation 10: Restart the window manager

```
ps aux | grep xfwm4
pkill xfwm4
xfwm4 --replace &
sleep 2
xclock
```

**Result** : xclock successfully popped up the clock window.

**Conclusion** : The window manager froze and was restored after restarting.

### Step 11: Running edgeai_app again resulted in a Qt error.

```
qt.qpa.plugin: Could not find the Qt platform plugin "xcb" in ""
This application failed to start because no Qt platform plugin could be initialized.
```

### Step 12: Locate and set the Qt plugin path

```
find /usr -name "libqxcb.so" 2>/dev/null
# 输出：/usr/lib/aarch64-linux-gnu/qt5/plugins/platforms/libqxcb.so

export QT_QPA_PLATFORM_PLUGIN_PATH=/usr/lib/aarch64-linux-gnu/qt5/plugins
export QT_QPA_PLATFORM=xcb
```

### Operation 13: Checking the logs revealed a device node error.

The log shows:

```
[ERROR] Main: failed to open input source '/dev/video-camera0'
```

### Step 14: Confirm that video71 is not working.

```
v4l2-ctl -d /dev/video71 --set-fmt-video=width=640,height=480,pixelformat=NV12 --stream-mmap --stream-to=/tmp/test.raw --stream-count=1
# 失败
```

### Operation 15: Modify the configuration file

```
vim /userdata/rknn_eai_rk3588/config/default.yaml
```

Change input.source from /dev/video-camera0 to /dev/video45.

### Operation 16: Successfully completed.

```
export DISPLAY=:0
export XAUTHORITY=/root/.Xauthority
export QT_QPA_PLATFORM_PLUGIN_PATH=/usr/lib/aarch64-linux-gnu/qt5/plugins
export QT_QPA_PLATFORM=xcb
cd /userdata/rknn_eai_rk3588
./edgeai_app
```

**Result** : The screen popped up successfully.

### Operation 17: Verify if camera-stream.service is redundant.

```
ps -ef | grep rkaiq_3A_server | grep -v grep
# 有输出，官方 3A 服务在运行

systemctl stop camera-stream.service
systemctl disable camera-stream.service

# 再次运行 edgeai_app，画面正常
```

**Conclusion** : camera-stream.service is redundant and can be deleted.

## IV. Erroneous inferences and operations during the investigation process, and how they were overturned (complete list)

### Incorrect assumption 1: "OpenCV's V4L2 backend does not support RK3588"

**AI's inference** :

> "The V4L2 backend of OpenCV cannot handle DMA/CMA memory accesses of the RK3588 ISP driver, causing VideoCapture to fail to open."

**Actual verification** :

```
# 测试 OpenCV 直接打开 video45
python3 -c "import cv2; cap=cv2.VideoCapture('/dev/video45', cv2.CAP_V4L2); print(cap.isOpened())"
# 输出 False
```

**How to overturn** :

1. The fact that v4l2-ctl can capture images normally indicates that the hardware and drivers are working properly.

2. The edgeai_app was finally able to open video45 and display the image normally, proving that OpenCV itself can work normally.

3. The real problem isn't that OpenCV doesn't support RK3588, but that the program is using the wrong device node and lacking Qt environment variables.

**Official basis** : Rockchip's ISP driver (rockchip-isp1) is based on the standard V4L2 and Media Controller framework, and theoretically any V4L2-compatible application can access it. OpenCV's V4L2 backend is a standard implementation, so there is no "unsupported" issue.

### Incorrect assumption 2: "The problem is caused by the GStreamer plugin not being ported over."

**AI's inference** :

> “Buildroot’s GStreamer V4L2 plugin (libgstv4l2.so) has not been ported to Ubuntu, causing the GStreamer backend to malfunction, so OpenCV cannot open the camera.”

**Actual verification** :

```
# 找 libgstv4l2.so
find /usr -name "libgstv4l2*.so" 2>/dev/null
# 找不到
```

**How to overturn** :

1. The ldd program shows that it links to the Buildroot OpenCV library (/lib/libopencv_*.so.409). When these libraries are compiled on Buildroot, their dependencies can be checked using ldd.

2. The failure of gst-launch is a problem with the tool itself, and has nothing to do with the program.

3. The program uses a Qt backend for display and does not depend on the GStreamer plugin.

**Official basis** : OpenCV's highgui module can be compiled as a Qt backend or a GTK backend, and does not depend on GStreamer for display. The program uses a Qt backend, which is unrelated to GStreamer.

### Incorrect assumption 3: "DMA/CMA memory access methods are incompatible"

**AI's inference** :

> "OpenCV's V4L2 backend only supports virtual address access and does not support DMA/CMA physical address access required by the RK3588 ISP driver, causing VIDIOC_REQBUFS to fail."

**Actual verification** :

```
# v4l2-ctl 使用 MMAP 方式能正常抓图
v4l2-ctl -d /dev/video45 --set-fmt-video=width=640,height=480,pixelformat=NV12 --stream-mmap --stream-to=/tmp/test.raw --stream-count=1
# 成功
```

**How to overturn** :

1. The fact that v4l2-ctl can capture images normally using the MMAP method indicates that the MMAP mode is supported.

2. The fact that edgeai_app was able to display the image correctly proves that OpenCV can handle DMA/CMA memory.

3. The real problem is that the program is using the wrong device node (/dev/video71), not that the memory access methods are incompatible.

**Official basis** : v4l2-ctl is the official testing tool for V4L2. Its successful use of MMAP mode proves that the driver fully supports MMAP. The OpenCV V4L2 backend also uses MMAP mode, so there is no "not supported" issue.

### Incorrect assumption 4: "Ubuntu's OpenCV is a headless version."

**AI's inference** :

> "The OpenCV installed on Ubuntu via apt install python3-opencv is a headless version and does not support GUI display, so imshow cannot pop up a window."

**Actual verification** :

```
# 检查程序链接的库
ldd /userdata/rknn_eai_rk3588/edgeai_app | grep opencv
# 输出：libopencv_core.so.409 => /lib/libopencv_core.so.409
```

**How to overturn** :

1. The ldd command indicates that the program is linking to Buildroot's OpenCV library (/lib/libopencv_*.so.409), not the Ubuntu Python package.

2. Previously, test_show.py could successfully pop up the green square window, proving that OpenCV's imshow function was working properly.

3. The problem isn't with OpenCV's GUI capabilities, but with environment variables and configuration.

**Official documentation states** that the OpenCV highgui module can be compiled with either a Qt or GTK backend. The Buildroot library linked by the program comes with full Qt backend support, not a headless version.

### Incorrect assumption 5: "XFCE does not use Wayland, Wayland settings are invalid"

**AI's inference** :

> "XFCE is a desktop environment based on X11 and does not involve Wayland. Setting Wayland-related environment variables is unnecessary and will not affect anything."

**Actual verification** :

```
# 用户之前设置过 Wayland 变量，消除了 OpenCV 的 "window disabled" 警告
export XDG_RUNTIME_DIR=/run/user/0
export WAYLAND_DISPLAY=wayland-0
```

**How to overturn** :

1. The user successfully eliminated the OpenCV warning "OpenCVDisplaySink: no DISPLAY/WAYLAND_DISPLAY, window disabled" by setting the Wayland variable.

2. Although XFCE uses X11 by default, the system may also have a Wayland compatibility layer or Wayland sockets.

3. Setting the Wayland variable to work indicates that the system does indeed involve Wayland-related mechanisms.

**Official basis** : Wayland and X11 can coexist on the same system (via XWayland). Although XFCE is based on X11, the system may be running Wayland synthesizers or related services.

### Incorrect assumption 6: "The ported OpenCV library is incompatible with the Ubuntu kernel".

**AI's inference** :

> "The OpenCV library compiled on Buildroot depends on specific interfaces of the Buildroot kernel, and running it on the Ubuntu kernel will cause V4L2 ioctl calls to fail."

**Actual verification** :

```
# 程序最终能正常运行
export QT_QPA_PLATFORM_PLUGIN_PATH=/usr/lib/aarch64-linux-gnu/qt5/plugins
./edgeai_app
# 画面成功弹出
```

**How to overturn** :

1. The program eventually ran correctly on Ubuntu and displayed the camera feed, proving that Buildroot's OpenCV library is fully compatible with Ubuntu.

2. V4L2 ioctl is a kernel standard interface, and applications do not directly depend on the kernel version.

3. The problem isn't with library compatibility, but with environment variables and configuration.

**Official justification** : V4L2 is the standard interface for the Linux kernel and has a stable ABI. Applications communicate with drivers via V4L2 ioctl, independent of specific kernel versions. glibc ensures backward compatibility of the library interface.

### Incorrect assumption 7: "camera-stream.service is a required service for ISP 3A"

**AI's inference** :

> "ISP 3A (auto exposure, auto white balance, auto focus) requires a continuous video stream to trigger, so camera-stream.service is necessary, which keeps 3A working through a continuous gst-launch stream."

**Actual verification** :

```
# 检查官方 3A 服务
ps -ef | grep rkaiq_3A_server | grep -v grep
# 有输出：root 323 1 0 06:06 ? 00:00:27 /usr/bin/rkaiq_3A_server

# 停止并禁用自定义服务
systemctl stop camera-stream.service
systemctl disable camera-stream.service

# 再次运行 edgeai_app，画面正常
```

**How to overturn** :

1. Rockchip's official 3A service, rkaiq_3A_server, is already running independently and does not require additional streams to trigger.

2. The program still displays normally after disabling camera-stream.service, proving that this service does not contribute to 3A.

3. The device node /dev/video-camera0 (pointing to video71) used by the service is itself incorrect, and the service never actually worked.

**Official basis** : Rockchip's official documentation clearly states that rkaiq_3A_server is a standalone background daemon that automatically performs 3A tuning. Applications only need to read the data stream from the /dev/videoX node. No additional "trigger stream" needs to be started.

### Incorrect assumption 8: "OpenCV needs to be recompiled from source code"

**AI's inference** :

> "OpenCV on Ubuntu is incompatible with RK3588 and needs to be recompiled from source code with the Rockchip-specific patch added."

**Actual verification** :

```
# 最终只改了配置和环境变量，没有重新编译任何东西
vim config/default.yaml   # 改设备节点
export QT_QPA_PLATFORM_PLUGIN_PATH=...  # 设环境变量
./edgeai_app  # 成功运行
```

**How to overturn** :

1. The final solution does not involve any compilation operations.

2. Buildroot's OpenCV library is fully available on Ubuntu.

3. Recompiling is completely unnecessary.

**Official justification** : OpenCV is cross-platform; pre-compiled binary libraries can run across systems on the same architecture (aarch64) (depending on glibc compatibility). Buildroot's libraries are compiled on aarch64, and Ubuntu is also aarch64, so recompilation is not required.

### Error 9: "Requires modification of V4L2 driver or device tree"

**AI's inference** :

> "There is a problem with the camera driver or device tree configuration of the RK3588, which is causing OpenCV to be unable to correctly identify the camera device node."

**Actual verification** :

```
# v4l2-ctl 能正常抓图
# edgeai_app 最终能正常显示
# 没有任何驱动或设备树修改
```

**How to overturn** :

1. The successful screenshot taken by v4l2-ctl proves that the driver and device tree are completely normal.

2. Ultimately, no drivers or device trees were modified.

3. The problem lies entirely in the user-mode environment configuration.

**Official basis** : The device tree and drivers provided by Rockchip are verified, and the fact that v4l2-ctl works normally proves that there are no problems at the underlying level.

### Incorrect assumption 10: "The GStreamer plugin for Buildroot needs to be copied."

**AI's inference** :

> "Buildroot's GStreamer V4L2 plugin needs to be copied to Ubuntu, otherwise the OpenCV GStreamer backend will not work."

**Actual verification** :

```
# 在 Buildroot 源码中找 libgstv4l2.so
find . -name "libgstv4l2*.so" 2>/dev/null
# 只找到 libgstv4l2codecs.so，没有 libgstv4l2.so

# 程序不依赖 GStreamer 插件
ldd edgeai_app | grep gst
# 没有任何 GStreamer 相关的输出（或者只有 Ubuntu 系统的 GStreamer 库）
```

**How to overturn** :

1. The Buildroot source code does not contain libgstv4l2.so, only libgstv4l2codecs.so (this is the codec plugin, not the source plugin).

2. The program does not rely on the GStreamer plugin for display.

3. Copying the GStreamer plugin does not help resolve the display issue.

**Official documentation states** that OpenCV's videoio module can use a GStreamer backend, but edgeai_app's ldd analysis shows that it links to the OpenCV library that directly accesses V4L2, rather than the GStreamer backend. The GStreamer V4L2 source plugin in Buildroot may be named libgstvideo4linux2.so instead of libgstv4l2.so.

### Incorrect assumption 11: "GStreamer has compatibility issues with the RK3588 ISP driver".

**AI's inference** :

> "The v4l2src plugin for GStreamer has a compatibility issue with the RK3588 ISP driver, causing gst-launch to report an error: 'Failed to allocate required memory.' Therefore, this compatibility issue needs to be resolved for the program to work."

**Actual verification** :

```
# 尝试各种 io-mode 都失败
gst-launch-1.0 v4l2src device=/dev/video45 io-mode=1 ! ...
gst-launch-1.0 v4l2src device=/dev/video45 io-mode=4 ! ...
# 全部报错 Failed to allocate required memory

# 但 edgeai_app 能正常工作
```

**How to overturn** :

1. The gst-launch error only affects the GStreamer tool itself and is unrelated to edgeai_app.

2. edgeai_app does not rely on GStreamer for display, so there is no need to resolve this error.

3. This statement is a summary of community phenomena and not an official Rockchip statement. Rockchip does provide a dedicated plugin, rkcamsrc, and continues to submit patches for v4l2src, but the standard v4l2src can also work with the correct media-ctl configuration.

**Official basis** :

- Rockchip's official documentation provides a dedicated plugin called rkcamsrc, which is modified from v4l2src.

- The official documentation states that the media pipeline must be correctly configured via media-ctl before using the standard v4l2src.

- This is not a "compatibility issue," but rather a "needs to be configured correctly" problem.

### Incorrect assumption 12: "OpenCV does not support DMA/CMA memory access"

**AI's inference** :

> "OpenCV's V4L2 backend uses virtual address access by default and does not support DMA/CMA physical address access required by the RK3588 ISP driver."

**Actual verification** :

```
# OpenCV 最终能正常抓图和显示
./edgeai_app  # 成功显示画面
```

**How to overturn** :

1. The fact that v4l2-ctl can capture images normally in MMAP mode proves that the driver supports MMAP.

2. OpenCV's V4L2 backend also uses MMAP mode, so there's no reason not to support it.

3. The program was able to capture and display images successfully, proving that OpenCV can correctly handle DMA/CMA memory.

**Official justification** : MMAP is the standard memory mapping method for V4L2, and all V4L2-compatible drivers must support it. OpenCV's V4L2 backend uses the standard MMAP method, and there is no issue of "not supporting DMA/CMA".

### Incorrect assumption #13: "The window manager is freezing because of an X11 configuration problem."

**AI's inference** :

> "There is a problem with the X11 configuration file, or the server configuration is incorrect, which prevents the window from being created."

**Actual verification** :

```
pkill xfwm4
xfwm4 --replace &
xclock  # 成功弹出
```

**How to overturn** :

1. After restarting xfwm4, xclock can pop up normally, proving that the X11 configuration is correct.

2. The problem is simply that the xfwm4 process itself is stuck.

3. This is a user-mode process issue, not a system configuration issue.

**Official explanation** : xfwm4 is the window manager for XFCE. The freeze may be due to an abnormal process state caused by previous window operations. Restarting the process will restore normal operation; it is unrelated to X11 configuration.

### Incorrect assumption 14: "The Qt plugin path problem is because Qt is not installed correctly."

**AI's inference** :

> "Qt is not installed correctly on the Ubuntu system, resulting in missing Qt platform plugins."

**Actual verification** :

```
find /usr -name "libqxcb.so" 2>/dev/null
# 输出：/usr/lib/aarch64-linux-gnu/qt5/plugins/platforms/libqxcb.so

export QT_QPA_PLATFORM_PLUGIN_PATH=/usr/lib/aarch64-linux-gnu/qt5/plugins
# 程序正常工作
```

**How to overturn** :

1. The existence of the libqxcb.so file indicates that Qt has been installed correctly.

2. The problem is simply that the environment variable QT_QPA_PLATFORM_PLUGIN_PATH is not set, and Qt cannot find the plugin path.

3. The program works normally after setting the environment variables, proving that Qt itself is not the problem.

**Official documentation states** that Qt's plugin search path is specified at compile time by default. In cross-compilation or porting environments, it may be necessary to explicitly specify the plugin path through the QT_QPA_PLATFORM_PLUGIN_PATH environment variable.

### Incorrect assumption 15: "xhost + is redundant and should be resolved using XAUTHORITY".

**AI's inference** :

> “xhost + will reduce security. You should grant root user access to the X Server by properly setting the XAUTHORITY environment variable.”

**Actual verification** :

```
# 在桌面终端执行 xhost +
xhost +
# access control disabled, clients can connect from any host

# 在 root 终端执行
export XAUTHORITY=/root/.Xauthority
xclock  # 成功弹出
```

**How to overturn** :

1. xhost + is an effective, simple, and direct way to solve the problem.

2. The XAUTHORITY setting is also effective, but an authorization file is required first.

3. Both are legitimate methods, and neither is right or wrong.

**Official explanation** : xhost is the licensing tool for X11, and using xhost with access control disabled is standard practice. On development boards, security is usually not a primary concern.

## V. Summary of Root Causes

question | Discovery method | Solution
--- | --- | ---
Device node error | Log failed to open /dev/video-camera0 | Change the configuration file to /dev/video45
Qt plugin path not set | Error message: Could not find Qt platform plugin "xcb" | Set QT_QPA_PLATFORM_PLUGIN_PATH
Window manager frozen (related) | xclock stuck | pkill xfwm4; xfwm4 --replace &amp;
Display is not set (associated). | echo $DISPLAY is empty | export DISPLAY=:0

**There are only two core elements: device nodes and Qt plugin paths.**

## VI. List of Script Files Actually Written

script path | use
--- | ---
/tmp/test_show.py | Test if OpenCV displays correctly (green square).
/userdata/show_camera.py | Capture and display camera footage using a v4l2-ctl subprocess.
