<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2026 KY (kyshipit)
-->

# ROS2 image stuttering: Troubleshooting WiFi, QoS, and WSL2

## summary

**Problem** : When the ROS 2 development board (RK3588) publishes a 640×480 original image, the local ROS2 topic hz displays a stable 10Hz, but the frame rate of the WSL2 subscriber under the same WiFi suddenly drops to 1-2Hz, the picture is severely stuttered, and there is a reception gap of up to 4.6 seconds.

**reason** :

- QoS policy mismatch: The publisher defaults to BEST_EFFORT (allows packet loss, no retransmission), while the WSL command-line tools (ros2 topic hz, rqt_image_view default configuration) request RELIABLE (requires every packet to be delivered). Any packet loss in the WiFi environment will trigger the DDS retransmission mechanism, causing the receiver to continuously wait for retransmitted fragments, resulting in the kernel IP reassembly buffer overflowing, ultimately manifesting as a frame rate dropping to zero and commands being suspended.

- Release-side timer blocking: cv2.imencode is executed directly in timer_callback (single frame encoding takes 30-50ms), causing timer callbacks to accumulate, and the local release frame rate gradually drops from 10Hz to 4-5Hz.

- The original image data size is too large: the bandwidth of a 640×480 BGR8 image is approximately 70Mbps, which exceeds the stable carrying capacity of WiFi.

**solve** :

- Compression starts at the source: directly publishing sensor_msgs/CompressedImage (JPEG, quality 60) in the camera node reduces bandwidth from 70Mbps to 4–5Mbps.

- Asynchronous encoding: Move cv2.imencode to a separate thread, and the timer is only responsible for enqueuing, ensuring a stable 10Hz output on the publishing end.

- Subscribers can explicitly specify QoS: Use the BEST_EFFORT policy (custom script or rqt_image_view -p _image_transport:=compressed) to eliminate retransmission blocking.

## Environmental Information

Role | Hardware/System | ROS version 2 | IP address
--- | --- | --- | ---
Publishing end | RK3588 Development Board / Ubuntu 24.04 | Jazzy | 192.168.1.100
Subscription | Windows 11 WSL2/Ubuntu 24.04 | Jazzy | 192.168.1.101
network | Same WiFi 5GHz router | — | —
Image parameters | 640×480 BGR8, 10Hz, single frame ≈ 0.88MB, bandwidth requirement ≈ 70Mbps | — | —

Note: The IP address is an example; please replace it with the one appropriate for your actual network environment.

# Part 1: Conceptual Preparation

Beginners, please read this section; experienced users can skip directly to Part Two.

## 1.1 ROS 2 Topic Publish/Subscribe Model

In ROS 2, nodes communicate through topics. Publishers send messages to topics, and subscribers receive messages from topics. This is a decoupled, one-to-many communication method.

## 1.2 QoS (Quality of Service)

QoS is a set of policy parameters in ROS 2 that control communication behavior. Different nodes can request different QoS policies, and the middleware (DDS) is responsible for coordination.

The two most important concepts in this section:

Strategy | meaning | analogy | Applicable Scenarios
--- | --- | --- | ---
RELIABLE | Reliable transmission ensures every message is delivered; packets are retransmitted in case of loss. | TCP | Control commands, parameter updates, critical states
BEST_EFFORT | Try your best to transmit, allow packet loss, do not retransmit | UDP | Video stream, sensor data (occasional frame drops are tolerable)

Key point: If the publisher uses BEST_EFFORT and the subscriber requests RELIABLE, the middleware will attempt to be compatible, but in a packet loss environment, it will trigger a large number of retransmissions, leading to serious performance issues.

ROS 2 predefines several QoS Profiles, among which sensor_data is specifically designed for sensor data and uses BEST_EFFORT and Volatile Durability by default.

## 1.3 Image Compression

type | Message Type | Single frame size | Bandwidth requirement (10Hz)
--- | --- | --- | ---
Original image | sensor_msgs/Image (BGR8) | ≈ 0.88MB | ≈ 70Mbps
Compressed images | sensor_msgs/CompressedImage (JPEG quality 60) | ≈ 50–100KB | ≈ 4–8Mbps

Conclusion: Compression can reduce bandwidth requirements by more than 10 times, making it an essential means of transmitting images in a WiFi environment.

## 1.4 image_transport

- ImageTransport is a plugin framework in ROS 2 specifically designed for image transfer. It allows publishers to publish multiple formats (raw, compressed, theora, etc.) simultaneously or selectively under the same underlying topic.

- Publish the basic topic /camera/image and enable the compressed plugin → Automatically publish /camera/image/compressed

- Subscribers can choose to receive compressed streams via the parameter _image_transport:=compressed

# Part Two: The Complete Investigation Process

## Complete timeline, actions, and diagnosis

stage | operate | Observed phenomena | Error Analysis
--- | --- | --- | ---
initial | Published original image (640×480 BGR8, 10Hz), WSL subscription | The development board runs at 10Hz locally, while WSL runs at &lt;2Hz, resulting in stuttering. | It was mistakenly thought to be due to insufficient WiFi bandwidth (70Mbps).
Network testing | iperf3 -u -b 50M | Packet loss 12% | Further strengthen the judgment of insufficient bandwidth
First compression attempt | Use image_transport republish raw compressed ... | After the node starts, out_transport is empty, and the command is stuck. | Command format error, version incompatibility
Source code modification (first version) | Add cv2.imencode to timer_callback and publish to /camera/image/compressed. | The development board's local frequency started at 10Hz, then dropped to 7-8Hz; WSL still experienced stuttering. | Timer blocking (encoding time consumption); QoS not considered.
Second network test | iperf3 -u -b 4M (simulates compressed data volume) | Packet loss rate 0% | Key finding: WiFi can fully support compressed streams.
Custom subscription script | Write hz_counter.py to explicitly set QoS = BEST_EFFORT | WSL receives stable frequencies from 10 to 12 Hz. | The root cause: QoS mismatch (the publisher defaults to BEST_EFFORT, and the subscriber defaults to RELIABLE).
Asynchronous coding transformation | Move the coding to a separate thread, and let the timer only handle enqueueing. | The development board maintains a stable 10Hz refresh rate locally, with no more frame drops. | Solving the timer blocking problem
Final verification | rqt_image_view specifies_image_transport:=compressed | The game runs smoothly; warnings can be ignored. | Everything is normal

## Phase 1: Initial Observation – Local connection normal, remote connection experiencing lag

### operate

On the development board (release side):

```bash
# 启动摄像头发布节点
ros2 run camera_pkg camera_pub

# 另开终端，查看发布频率
ros2 topic hz /camera/image_raw
```

Expected output (as it is):

```text
average rate: 10.01
        min: 0.098s max: 0.104s std dev: 0.002s window: 10
```

In WSL (subscription side):

```bash
ros2 topic hz /camera/image_raw
```

Actual output:

```text
average rate: 1.78
        min: 0.505s max: 0.610s std dev: 0.043s window: 3
...
average rate: 1.33
        min: 0.483s max: 4.683s std dev: 0.652s window: 42
```

### analyze

Phenomenon | meaning
--- | ---
The development board's local frequency is 10Hz. | The camera driver, data acquisition, and publishing logic are functioning normally.
WSL terminal Hz ≈ 1–2Hz | There are serious problems with network transmission.
A long interval of 4.68 seconds occurred. | There is a timeout or retransmission blocking.

Preliminary conclusion: The problem lies in the network transmission process, not in the camera driver or the ROS 2 node logic.

## Phase 2: Network Benchmarking – Locating Physical Layer Bottlenecks

### operate

Start the iperf3 server on WSL:

```bash
iperf3 -s
```

Running the client on the development board (simulating raw image traffic of 50Mbps):

```bash
iperf3 -c 192.168.1.101 -u -b 50M -t 10
```

Actual output:

```text
[ ID] Interval           Transfer     Bitrate         Jitter    Lost/Total Datagrams
[  5]   0.00-10.00  sec  59.6 MBytes  50.0 Mbits/sec  0.000 ms  0/43160 (0%)  sender
[  5]   0.00-11.46  sec  52.5 MBytes  38.4 Mbits/sec  0.328 ms  5173/43160 (12%)  receiver
```

### analyze:

- Sending speed 50Mbps, no packet loss (0/43160)

- The receiver reported a packet loss rate of 12% (5173/43160).

- Conclusion: The WiFi link experiences severe packet loss at 50Mbps. However, the image stream requires 70Mbps, suggesting insufficient bandwidth.

Further testing (simulating compressed traffic of 4Mbps)

```bash
iperf3 -c 192.168.1.101 -u -b 4M -t 30
```

Actual output:

```text
[ ID] Interval           Transfer     Bitrate         Jitter    Lost/Total Datagrams
[  5]   0.00-30.00  sec  14.3 MBytes  4.00 Mbits/sec  0.000 ms  0/10359 (0%)  sender
[  5]   0.00-27.32  sec  14.3 MBytes  4.39 Mbits/sec  3.636 ms  0/10358 (0%)  receiver
```

Key finding: 0% packet loss at 4Mbps! This indicates that the WiFi physical layer can fully handle compressed data traffic. The problem isn't with the bandwidth itself, but with how the ROS 2/DDS layer handles packet loss.

## Phase 3: Attempt to republish using image_transport - failed

### operate

Try compressed forwarding on the development board:

```bash
ros2 run image_transport republish raw compressed --ros-args -r in:=/camera/image_raw
```

Actual output:

```text
[INFO] [image_republisher]: The 'in_transport' parameter is set to: raw
[INFO] [image_republisher]: The 'out_transport' parameter is set to:
```

The command is stuck, out_transport is empty, and the node cannot function properly.

### analyze

Error reason:

- In ROS 2 Jazzy, the position parameter (raw compressed) is no longer correctly resolved.

- The `out_transport` parameter inside the node is not set, making it impossible to determine the output format.

- The tool itself has version compatibility issues.

❌ Wrong approach: Continuing to try different combinations of command formats wastes a lot of time debugging a tool with known problems.

✅ Correct approach: Abandon republish and implement compressed publishing directly in the camera node source code.

## Phase 4: Source Code Modification – Release of Compressed Image (First Version)

### Modifications

In the timer_callback of the camera_pub node, add JPEG encoding and publish a CompressedImage.

Core code snippet:

```python
def timer_callback(self):
    if not self.frame_ready or self.frame is None:
        return
    frame_copy = self.frame.copy()
    encode_param = [int(cv2.IMWRITE_JPEG_QUALITY), 60]
    _, jpeg_data = cv2.imencode('.jpg', frame_copy, encode_param)
    
    msg = CompressedImage()
    msg.header.stamp = self.get_clock().now().to_msg()
    msg.header.frame_id = "camera"
    msg.format = "jpeg"
    msg.data = jpeg_data.tobytes()
    self.pub_compressed_.publish(msg)
```

### result

Local development board:

```text
average rate: 10.01  # 开始稳定
...
average rate: 9.21   # 30秒后开始波动
average rate: 7.38   # 持续下降
...
average rate: 4.48   # 2分钟后降至 4-5Hz
```

WSL version: still only 1–3Hz, stuttering problem remains unresolved.

### analyze

Phenomenon | reason
--- | ---
The development board's local frequency gradually dropped from 10Hz to 4-5Hz. | cv2.imencode is a time-consuming operation (≈ 30-50ms/frame). Executing it within a timer callback causes callback backlog and lengthens the timer period.
The WSL client is still lagging. | The publishing end itself is experiencing frame drops, and the QoS issue has not yet been resolved.

## Phase 5: Asynchronous Coding Transformation – Solving Frame Drops on the Deployment End

### Modifications

The encoding and publishing operations are moved out of the timer callback and placed in a separate thread. The timer is only responsible for adding the latest frame to the queue, and the encoding thread retrieves frames from the queue, encodes them, and publishes them.

Core code structure:

```python
class CameraPubNode(Node):
    def __init__(self):
        # ...
        self.frame_queue = queue.Queue(maxsize=2)
        self.encoder_thread = threading.Thread(target=self._encoder_loop, daemon=True)
        self.encoder_thread.start()
        self.timer = self.create_timer(0.1, self.timer_callback)

    def timer_callback(self):
        """定时器：只把最新帧放入队列，不阻塞"""
        if self.frame_ready and self.frame is not None:
            try:
                self.frame_queue.put_nowait(self.frame.copy())
            except queue.Full:
                pass  # 队列满则丢弃，保证实时性

    def _encoder_loop(self):
        """独立编码线程：从队列取帧，编码为JPEG并发布"""
        while self.running:
            try:
                frame = self.frame_queue.get(timeout=0.5)
                encode_param = [int(cv2.IMWRITE_JPEG_QUALITY), 60]
                _, jpeg_data = cv2.imencode('.jpg', frame, encode_param)
                # 构建并发布 CompressedImage
                # ...
            except queue.Empty:
                continue
```

### result

Local development board:

```text
average rate: 10.00
        min: 0.098s max: 0.104s std dev: 0.002s window: 200
```

Stable 10Hz, no more frame drops.

WSL client: Still only 1–3Hz. The issue on the publishing side has been resolved; the problem now lies with the subscription side.

## Phase 6: Investigate the subscription end – Discover QoS mismatches

### operate

Write a simple Python subscription node, hz_counter.py, that explicitly specifies the QoS as BEST_EFFORT:

```python
#!/usr/bin/env python3
import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy
from sensor_msgs.msg import CompressedImage

class HzCounter(Node):
    def __init__(self):
        super().__init__('hz_counter')
        qos = QoSProfile(depth=10, reliability=ReliabilityPolicy.BEST_EFFORT)
        self.sub = self.create_subscription(CompressedImage, '/camera/image/compressed', self.cb, qos)
        self.cnt = 0
        self.timer = self.create_timer(1.0, self.tick)

    def cb(self, msg):
        self.cnt += 1

    def tick(self):
        self.get_logger().info(f'{self.cnt} Hz')
        self.cnt = 0

def main():
    rclpy.init()
    node = HzCounter()
    rclpy.spin(node)

if __name__ == '__main__':
    main()
```

run:

```bash
python3 hz_counter.py
```

Actual output:

```text
[INFO] [hz_counter]: 3 Hz
[INFO] [hz_counter]: 11 Hz
[INFO] [hz_counter]: 11 Hz
[INFO] [hz_counter]: 12 Hz
[INFO] [hz_counter]: 11 Hz
[INFO] [hz_counter]: 11 Hz
... 持续稳定 10-12Hz
```

### analyze

Subscription method | QoS settings | result
--- | --- | ---
ros2 topic hz /camera/image/compressed | Default (usually RELIABLE) | Stuttering, 1–2Hz
hz_counter.py (Explicit BEST_EFFORT) | BEST_EFFORT | Smooth, 10–12Hz

Root cause confirmed:

- The publisher (camera_pub node) uses create_publisher(CompressedImage, "/camera/image/compressed", 10) to create the publisher. In ROS 2 Jazzy, the default QoS of create_publisher is rmw_qos_profile_sensor_data, which is BEST_EFFORT.

- The default QoS policy of the subscription client (ros2 topic hz) varies across different versions. In older versions or specific environments, it may default to RELIABLE.

- When a BEST_EFFORT publisher encounters a RELIABLE subscriber: the DDS middleware attempts to coordinate, but the subscriber inherently requires reliable transmission. In a WiFi environment, any packet loss will trigger a retransmission request, leading to:

    - The sending end needs to buffer data to support retransmission.

    - The receiver is waiting for a missing fragment, and the buffer is blocked.

    - The final result is a sharp drop in frame rate and command freezing.

This is a classic problem that is clearly pointed out in the StereoLabs official forum and the ROS 2 design guidelines.

## Phase 7: Final Verification – Smooth Visuals

### operate

Use rqt_image_view and specify QoS correctly:

```bash
ros2 run rqt_image_view rqt_image_view --ros-args \
  -p image_topic:=/camera/image \
  -p _image_transport:=compressed
```

### result

Smooth gameplay with no lag.

There is a warning (regarding direct subscription to compressed topics), but it can be safely ignored. The warning content is as follows:

```text
[WARN] [rqt_gui_cpp_node]: [image_transport] It looks like you are trying to subscribe directly to a transport-specific image topic...
```

Explanation: `rqt_image_view` works through the `image_transport` mechanism, expecting to subscribe to an underlying topic and specify the transport type via parameters. While specifying the full topic name directly will work (because of type matching), it doesn't conform to the design pattern of `image_transport`. Warnings do not affect functionality.

# Part Three: In-depth Analysis of Essence and Principles

## The fundamental reason

- Root cause: QoS (Quality of Service) policy mismatch.

- The publisher (and custom subscription scripts) uses BEST_EFFORT (suitable for streaming data), which allows for packet loss without retransmission.

- The default subscription command (ros2 topic hz, rqt_image_view without parameters) uses RELIABLE, which requires every package to be delivered.

- When WiFi packet loss occurs, RELIABLE will trigger a long retransmission wait, causing reception blockage and a sharp drop in frame rate.

- Direct cause: Embedded encoding operation in the timer on the publishing end caused the timer period to be extended, resulting in frame loss.

- Indirect cause: Initially, I mistakenly tried the republish tool, wasting a lot of time due to parameter format issues.

## 3.1 Why does QoS mismatch cause lag?

Normal situation (strategy matching):

```text
发布端 (BEST_EFFORT) → 数据包 → 订阅端 (BEST_EFFORT)
                                     ↓
                              收到即处理，丢包则忽略
```

Abnormal situation (policy mismatch):

```text
    发布端 (BEST_EFFORT) → 数据包 → 订阅端 (RELIABLE)
                                     ↓
                              检测到丢包 → 发送 NACK（负确认）
                                     ↓
                              发布端收到重传请求
                                     ↓
                    ┌────────────────┴────────────────┐
                    ↓                                 ↓
              缓存并重传数据包              订阅端等待缺失分片
                    ↓                                 ↓
              增加网络负载                    内核缓冲区阻塞
                    ↓                                 ↓
              更多丢包 → 更多重传           帧率暴跌、命令卡死
```

Key mechanisms:

- DDS's reliability is implemented through a NACK/ACK mechanism, similar to TCP but more complex.

- Even a WiFi packet loss rate of only 1-2% can trigger frequent retransmissions.

- The receiver's IP fragment reassembly buffer (default 4MB) quickly fills up, preventing new data from being received.

- This ultimately leads to a vicious cycle: retransmission storm → buffer full → packet loss → more retransmissions.

## 3.2 Why is compression a necessary condition?

index | Original image | Compressed image (JPEG Q=60)
--- | --- | ---
Single frame size | ~0.88MB | ~60KB
10Hz bandwidth | ~70Mbps | ~5Mbps
IP fragments/frames | ~600 | ~40
WiFi packet loss impact | If any packet is lost, the entire frame will be retransmitted. | Minimal impact from data loss and low retransmission overhead.

Compression reduces the amount of data by more than 90%, while reducing the number of IP fragments per frame from 600 to 40, significantly reducing the impact of packet loss on transmission.

## 3.3 Why is asynchronous coding necessary?

- When software encoding JPEG, cv2.imencode takes approximately 30-50ms to encode a 640×480 image.

- Timer period = 100ms (10Hz)

- If the callback performs coding (~40ms) plus other operations, the total time may exceed 100ms.

- This causes a backlog of timer callbacks. The ROS 2 executor will attempt to compensate, but will ultimately result in dropped frames.

- Asynchronous encoding:

    - The timer performs only lightweight operations (copying frames, enqueuing), taking less than 1ms.

    - The code executes in parallel within threads, without blocking timers.

    - When the queue is full, discard old frames to ensure real-time performance.

# Part Four: Final Solution (Complete Steps)

## 4.1 Deployment Platform (Development Board)

File: camera_pub.py

Key code (see appendix for the complete version):

```python
#!/usr/bin/env python3
import threading
import queue
import rclpy
from rclpy.node import Node
from sensor_msgs.msg import CompressedImage
import cv2
import numpy as np
# ... 其他导入

class CameraPubNode(Node):
    def __init__(self):
        super().__init__("camera_pub_node")
        # 只发布压缩话题
        self.pub_compressed_ = self.create_publisher(
            CompressedImage,
            "/camera/image/compressed",
            10
        )
        # ... 摄像头初始化
        
        # 编码队列（最多缓存2帧）
        self.frame_queue = queue.Queue(maxsize=2)
        self.encoder_thread = threading.Thread(target=self._encoder_loop, daemon=True)
        self.encoder_thread.start()
        
        # 定时器（10fps）
        self.timer = self.create_timer(0.1, self.timer_callback)

    def timer_callback(self):
        """定时器：只放入队列，不阻塞"""
        if self.frame_ready and self.frame is not None:
            try:
                self.frame_queue.put_nowait(self.frame.copy())
            except queue.Full:
                pass  # 队列满则丢弃

    def _encoder_loop(self):
        """独立编码线程"""
        while self.running:
            try:
                frame = self.frame_queue.get(timeout=0.5)
                encode_param = [int(cv2.IMWRITE_JPEG_QUALITY), 60]
                _, jpeg_data = cv2.imencode('.jpg', frame, encode_param)
                
                msg = CompressedImage()
                msg.header.stamp = self.get_clock().now().to_msg()
                msg.header.frame_id = "camera"
                msg.format = "jpeg"
                msg.data = jpeg_data.tobytes()
                self.pub_compressed_.publish(msg)
            except queue.Empty:
                continue
            except Exception as e:
                self.get_logger().error(f"Encoder error: {e}")
```

Startup command:

```bash
ros2 run camera_pkg camera_pub
```

## 4.2 Subscription Client (WSL)

### Method A: Use a custom subscription script (recommended for testing)

File: hz_counter.py (see Phase 6 for complete code)

run:

```bash
python3 hz_counter.py
```

### Method B: Use rqt_image_view (recommended for viewing)

```bash
ros2 run rqt_image_view rqt_image_view --ros-args \
  -p image_topic:=/camera/image \
  -p _image_transport:=compressed
```

Note: Do not directly use `rqt_image_view /camera/image/compressed`, although it will work but will generate warnings. Using the base topic + `_image_transport` parameter is the correct usage, conforming to the image_transport design pattern.

### Method C: Explicitly specify QoS in the code

```python
from rclpy.qos import QoSProfile, ReliabilityPolicy

qos = QoSProfile(depth=10, reliability=ReliabilityPolicy.BEST_EFFORT)
sub = self.create_subscription(CompressedImage, '/camera/image/compressed', callback, qos)
```

## 4.3 Verification Command

Verify the deployment client on the development board:

```bash
ros2 topic hz /camera/image/compressed
```

Expected: Stable 10Hz

Verify the receiver on WSL:

```bash
python3 hz_counter.py
```

Expected: Stable 10–12Hz

# Part Five: Key Insights and Best Practices

## 5.1 Summary of the investigation approach

```text
1. 本地 vs 远端对比
   ↓ 本地正常，远端异常
2. 网络基准测试（iperf3）
   ↓ 大流量丢包，小流量正常
3. 排除物理层 → 聚焦 ROS 2/DDS 层
   ↓
4. 压缩图像（减少数据量）
   ↓ 发布端掉帧
5. 异步编码（解决发布端性能）
   ↓ WSL 仍卡
6. 检查 QoS（自定义脚本 vs 默认工具）
   ↓ 发现不匹配
7. 显式指定 BEST_EFFORT
   ↓ 问题解决
```

## 5.2 Core Experience

# | experience | illustrate
--- | --- | ---
1 | Use the tools first, then modify the code. | To troubleshoot ROS 2 transmission issues, prioritize using official tools such as iperf3, ros2 topic hz, and ros2 topic echo to quickly differentiate between physical network, DDS protocol, and code logic problems, accurately narrowing down the scope of the fault and avoiding blindly modifying and debugging the code.
2 | Compression starts from the source | The image_transport republish tool suffers from severe version compatibility issues, parameter parsing errors, and extremely poor stability, making it unsuitable for use in production projects. The optimal solution is to perform JPEG encoding directly within the image acquisition and publishing node, and natively publish the CompressedImage compression topic.
3 | Avoid time-consuming operations in timers | Time-consuming operations such as image encoding, file I/O, complex algorithm calculations, and data serialization must not be executed in ROS timer callbacks. They must be processed asynchronously in an independent thread to prevent timer blocking, callback accumulation, and dropped frames on the publishing end.
4 | QoS must match | Following the official ROS 2 design specifications, sensor streaming data (images, radar, IMU) uniformly uses the BEST_EFFORT strategy, sacrificing extreme reliability to ensure real-time performance; critical data such as robot control commands, parameter configurations, and status interactions use the RELIABLE reliable transmission strategy, and the strategies at both the sending and receiving ends must be fully matched.
5 | Testing tools are not necessarily neutral | The default QoS policies of official tools such as ROS2 topic hz and rqt differ depending on the ROS 2 version and Fast DDS middleware configuration, resulting in biased test results. Troubleshooting requires using custom scripts to explicitly specify QoS for comparison and verification.

## 5.3 Common Mistakes vs. Correct Practices

Scene | ❌ Incorrect practice | ✅ Correct approach
--- | --- | ---
Image remote lag | Subjectively judging that the WiFi bandwidth is insufficient or the router performance is poor, blindly replacing network equipment. | First, use iperf3 to test the actual network throughput and packet loss rate at high and low bandwidth levels to distinguish between physical network bottlenecks and DDS protocol layer and QoS matching issues.
Image compression failed | Repeated debugging of image_transport republish command parameters and format, and compatibility issues with adaptation tools. | Instead of using forwarding tools, we directly integrated the encoding logic into the camera's source code, natively releasing the CompressedImage compression feature, ensuring stability and reliability.
Frame drops on the publishing end | Frame drops are mitigated by reducing the timer release frequency and lowering the image resolution, at the expense of real-time performance. | The asynchronous encoding architecture has been modified so that the timer is only responsible for enqueuing frame data, while time-consuming encoding logic is executed in a separate thread to ensure a fixed and stable frame rate.
WSL remote lag | The default cause is attributed to performance defects and environmental compatibility issues in WSL2 virtual networks. | Prioritize verifying the consistency of QoS policies at both the sending and receiving ends. The vast majority of cross-device image stuttering issues are caused by QoS mismatches and are unrelated to WSL performance.
Subscription Frame Rate Test | Frame rate was tested using only the ROS2 topic hz tool, with the default tool configuration as the standard. | By using custom Python scripts to explicitly specify QoS policies for specific scenarios, comparative testing can be conducted, avoiding testing errors caused by differences in tool versions.

# appendix

## A. Complete code

### A.1 Publishing client camera_pub.py (asynchronous encoding version)

For the complete code, please refer to Section 4.1 of Part 4 of this article. The code implements frame queue caching, asynchronous encoding in an independent thread, and a mechanism for discarding frames when the queue is full, which completely solves the problems of timer blocking and frame drops on the publishing end. It is adapted to ROS 2 Jazzy version and can be compiled and run directly.

### A.2 Subscriber hz_counter.py

For the complete code, please refer to Section 6 of Part 2 of this article. The script manually specifies the BEST_EFFORT exclusive QoS policy, which can accurately collect the real received frame rate of image topics and avoid the test distortion problem caused by the default QoS mismatch of the official tools. It is a dedicated tool script for ROS 2 image stream testing.

## B. Summary of all commands

```bash
# 1. 查看发布端原始图像话题频率
ros2 topic hz /camera/image_raw

# 2. 查看订阅端原始图像话题频率
ros2 topic hz /camera/image_raw

# 3. 网络带宽压力测试（模拟50Mbps大流量，原始图像高带宽场景）
iperf3 -c 192.168.1.101 -u -b 50M -t 10

# 4. 网络带宽常规测试（模拟4Mbps小流量，压缩图像低带宽场景）
iperf3 -c 192.168.1.101 -u -b 4M -t 30

# 5. 启动压缩节点（失败尝试，ROS2 Jazzy版本不兼容）
ros2 run image_transport republish raw compressed --ros-args -r in:=/camera/image_raw

# 6. 启动自研异步编码图像发布节点（最优方案）
ros2 run camera_pkg camera_pub

# 7. 自定义QoS帧率订阅测试
python3 hz_counter.py

# 8. 图形界面可视化观看图像（标准规范方式）
ros2 run rqt_image_view rqt_image_view --ros-args -p image_topic:=/camera/image -p _image_transport:=compressed

```

# Conclusion

- This document starts with a specific "ROS 2 image lag" problem and fully records the entire troubleshooting process, from symptom observation, network testing, source code modification, performance optimization to the final solution. It also provides in-depth and easy-to-understand explanations of the core concepts involved (QoS, compression, asynchronous encoding).

- Hopefully, this document can help developers who encounter similar problems avoid detours and provide a reusable troubleshooting template for ROS 2 engineering practices.


