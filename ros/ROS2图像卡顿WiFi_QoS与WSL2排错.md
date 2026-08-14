# ROS2 图像卡顿：WiFi、QoS 与 WSL2排错

## 摘要

**问题**：ROS 2 开发板（RK3588）发布 640×480 原始图像，本地 ros2 topic hz 显示稳定 10Hz，但同一 WiFi 下的 WSL2 订阅端帧率骤降至 1–2Hz，画面严重卡顿，出现长达 4\.6 秒的接收间隙。

**原因**：

- QoS 策略不匹配：发布端默认使用 BEST\_EFFORT（允许丢包，不重传），而 WSL 端命令行工具（ros2 topic hz、rqt\_image\_view 默认配置）请求 RELIABLE（要求每包必达）。WiFi 环境下的任何丢包都会触发 DDS 重传机制，导致接收端持续等待重传分片，内核 IP 重组缓冲区满溢，最终表现为帧率归零、命令挂起。

- 发布端定时器阻塞：timer\_callback 中直接执行 cv2\.imencode（单帧编码耗时 30–50ms），导致定时器回调堆积，本地发布帧率从 10Hz 逐渐掉至 4–5Hz。

- 原始图像数据量过大：640×480 BGR8 图像带宽约 70Mbps，超过 WiFi 稳定承载能力。

**解决**：

- 压缩从源头做起：在摄像头节点中直接发布 sensor\_msgs/CompressedImage（JPEG，质量 60），带宽从 70Mbps 降至 4–5Mbps。

- 异步编码：将 cv2\.imencode 移至独立线程，定时器仅负责入队，确保发布端稳定 10Hz。

- 订阅端显式指定 QoS：使用 BEST\_EFFORT 策略（自定义脚本或 rqt\_image\_view \-p \_image\_transport:=compressed），消除重传阻塞。

## 环境信息

| 角色     | 硬件/系统                                             | ROS 2 版本 | IP 地址          |
| -------- | ----------------------------------------------------- | ---------- | ---------------- |
| 发布端   | RK3588 开发板 / Ubuntu 24\.04                         | Jazzy      | 192\.168\.1\.100 |
| 订阅端   | Windows 11 WSL2 / Ubuntu 24\.04                       | Jazzy      | 192\.168\.1\.101 |
| 网络     | 同一 WiFi 5GHz 路由器                                 | —          | —                |
| 图像参数 | 640×480 BGR8，10Hz，单帧 ≈ 0\.88MB，带宽需求 ≈ 70Mbps | —          | —                |

注意：IP 地址为示例，请根据实际网络环境替换。

# 第一部分：概念先修

新手请阅读此部分；老手可直接跳到第二部分。

## 1\.1 ROS 2 Topic 发布/订阅模型

ROS 2 的节点通过 Topic（话题） 进行通信。发布者（Publisher）将消息发送到话题，订阅者（Subscriber）从话题接收消息。这是一种解耦的、一对多的通信方式。

## 1\.2 QoS（Quality of Service，服务质量）

QoS 是 ROS 2 中控制通信行为的一组策略参数。不同节点可以请求不同的 QoS 策略，中间件（DDS）负责协调。

本节最重要的两个概念：

| 策略         | 含义                                       | 类比 | 适用场景                             |
| ------------ | ------------------------------------------ | ---- | ------------------------------------ |
| RELIABLE     | 可靠传输，确保每个消息都送达，丢包时会重传 | TCP  | 控制指令、参数更新、关键状态         |
| BEST\_EFFORT | 尽力传输，允许丢包，不重传                 | UDP  | 视频流、传感器数据（可容忍偶尔丢帧） |

关键点：如果发布端用 BEST\_EFFORT，订阅端请求 RELIABLE，中间件会尝试兼容，但在丢包环境下会触发大量重传，导致严重的性能问题。

ROS 2 预定义了几种 QoS Profile，其中 sensor\_data 专门为传感器数据设计，默认使用 BEST\_EFFORT 和 Volatile Durability。

## 1\.3 图像压缩

| 类型     | 消息类型                                     | 单帧大小   | 带宽需求（10Hz） |
| -------- | -------------------------------------------- | ---------- | ---------------- |
| 原始图像 | sensor\_msgs/Image（BGR8）                   | ≈ 0\.88MB  | ≈ 70Mbps         |
| 压缩图像 | sensor\_msgs/CompressedImage（JPEG 质量 60） | ≈ 50–100KB | ≈ 4–8Mbps        |

结论：压缩可以将带宽需求降低 10 倍以上，是 WiFi 环境下传输图像的必要手段。

## 1\.4 image\_transport

- image\_transport 是 ROS 2 中专门用于图像传输的插件框架。它允许发布者在同一个基础话题下，同时或选择性地发布多种格式（raw、compressed、theora 等）。

- 发布基础话题 /camera/image，并启用 compressed 插件 → 自动发布 /camera/image/compressed

- 订阅方可通过参数 \_image\_transport:=compressed 选择接收压缩流

# 第二部分：完整排查过程

## 完整时间线、动作与诊断

| 阶段               | 操作                                                         | 观察到的现象                                      | 错误分析                                                     |
| ------------------ | ------------------------------------------------------------ | ------------------------------------------------- | ------------------------------------------------------------ |
| 初始               | 发布原始图像（640×480 BGR8, 10Hz），WSL订阅                  | 开发板本地 hz 10Hz，WSL \<2Hz，卡顿               | 误认为是WiFi带宽不足（70Mbps）                               |
| 网络测试           | iperf3 \-u \-b 50M                                           | 丢包12%                                           | 进一步强化带宽不足的判断                                     |
| 首次压缩尝试       | 使用 image\_transport republish raw compressed \.\.\.        | 节点启动后 out\_transport 为空，命令卡死          | 命令格式错误，版本不兼容                                     |
| 源码修改（第一版） | 在 timer\_callback 中加入 cv2\.imencode，发布 /camera/image/compressed | 开发板本地 hz 开始10Hz，后掉到7\~8Hz；WSL依然卡顿 | 定时器阻塞（编码耗时）；QoS未考虑                            |
| 第二次网络测试     | iperf3 \-u \-b 4M（模拟压缩后流量）                          | 丢包率 0%                                         | 关键发现：WiFi完全能承载压缩流                               |
| 自定义订阅脚本     | 编写 hz\_counter\.py，显式设置 QoS = BEST\_EFFORT            | WSL接收 10\~12Hz 稳定                             | 真正根源：QoS不匹配（发布端默认BEST\_EFFORT，订阅端默认RELIABLE） |
| 异步编码改造       | 将编码移到独立线程，定时器仅负责入队                         | 开发板本地稳定10Hz，不再掉帧                      | 解决定时器阻塞问题                                           |
| 最终验证           | rqt\_image\_view 指定 \_image\_transport:=compressed         | 画面流畅，警告可忽略                              | 一切正常                                                     |

## 阶段 1：初步观察——本地正常，远端卡顿

### 操作

在开发板上（发布端）：

```bash
# 启动摄像头发布节点
ros2 run camera_pkg camera_pub

# 另开终端，查看发布频率
ros2 topic hz /camera/image_raw
```

期望输出（实际如此）：

```text
average rate: 10.01
        min: 0.098s max: 0.104s std dev: 0.002s window: 10
```

在 WSL（订阅端）：

```bash
ros2 topic hz /camera/image_raw
```

实际输出：

```text
average rate: 1.78
        min: 0.505s max: 0.610s std dev: 0.043s window: 3
...
average rate: 1.33
        min: 0.483s max: 4.683s std dev: 0.652s window: 42
```

### 分析

| 现象                 | 含义                           |
| -------------------- | ------------------------------ |
| 开发板本地 hz = 10Hz | 摄像头驱动、采集、发布逻辑正常 |
| WSL 端 hz ≈ 1–2Hz    | 网络传输存在严重问题           |
| 出现 4\.68s 长间隔   | 存在超时等待或重传阻塞         |

初步结论：问题出在网络传输环节，而非摄像头驱动或 ROS 2 节点逻辑。

## 阶段 2：网络基准测试——定位物理层瓶颈

### 操作

在 WSL 上启动 iperf3 服务端：

```bash
iperf3 -s
```

在开发板上运行客户端（模拟原始图像流量 50Mbps）：

```bash
iperf3 -c 192.168.1.101 -u -b 50M -t 10
```

实际输出：

```text
[ ID] Interval           Transfer     Bitrate         Jitter    Lost/Total Datagrams
[  5]   0.00-10.00  sec  59.6 MBytes  50.0 Mbits/sec  0.000 ms  0/43160 (0%)  sender
[  5]   0.00-11.46  sec  52.5 MBytes  38.4 Mbits/sec  0.328 ms  5173/43160 (12%)  receiver
```

### 分析：

- 发送端 50Mbps 无丢包（0/43160）

- 接收端统计丢包 12%（5173/43160）

- 结论：WiFi 链路在 50Mbps 下存在严重丢包。但图像流需要 70Mbps，初步怀疑带宽不足。

进一步测试（模拟压缩后流量 4Mbps）

```bash
iperf3 -c 192.168.1.101 -u -b 4M -t 30
```

实际输出：

```text
[ ID] Interval           Transfer     Bitrate         Jitter    Lost/Total Datagrams
[  5]   0.00-30.00  sec  14.3 MBytes  4.00 Mbits/sec  0.000 ms  0/10359 (0%)  sender
[  5]   0.00-27.32  sec  14.3 MBytes  4.39 Mbits/sec  3.636 ms  0/10358 (0%)  receiver
```

关键发现：4Mbps 下丢包率为 0%！这说明 WiFi 物理层完全能承载压缩后的数据流量。问题不在带宽本身，而在于 ROS 2/DDS 层对丢包的处理方式。

## 阶段 3：尝试使用 image\_transport republish——失败

### 操作

在开发板上尝试压缩转发：

```bash
ros2 run image_transport republish raw compressed --ros-args -r in:=/camera/image_raw
```

实际输出：

```text
[INFO] [image_republisher]: The 'in_transport' parameter is set to: raw
[INFO] [image_republisher]: The 'out_transport' parameter is set to:
```

命令卡住，out\_transport 为空，节点无法正常工作。

### 分析

错误原因：

- image\_transport republish 在 ROS 2 Jazzy 中，位置参数（raw compressed）已不再被正确解析

- 节点内部 out\_transport 参数未被设置，导致无法确定输出格式

- 工具本身存在版本兼容性问题

❌ 错误做法：继续尝试不同的命令格式组合，浪费大量时间调试一个有已知问题的工具。

✅ 正确做法：放弃 republish，直接在摄像头节点源码中实现压缩发布。

## 阶段 4：源码修改——发布压缩图像（第一版）

### 修改内容

在 camera\_pub 节点的 timer\_callback 中，添加 JPEG 编码并发布 CompressedImage。

核心代码片段：

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

### 结果

开发板本地：

```text
average rate: 10.01  # 开始稳定
...
average rate: 9.21   # 30秒后开始波动
average rate: 7.38   # 持续下降
...
average rate: 4.48   # 2分钟后降至 4-5Hz
```

WSL 端：仍只有 1–3Hz，卡顿未解决。

### 分析

| 现象                              | 原因                                                         |
| --------------------------------- | ------------------------------------------------------------ |
| 开发板本地从 10Hz 逐渐掉到 4\-5Hz | cv2\.imencode 是耗时操作（≈ 30\-50ms/帧），在定时器回调中执行导致回调堆积，定时器周期被拉长 |
| WSL 端仍然卡顿                    | 发布端本身已丢帧，且 QoS 问题尚未解决                        |

## 阶段 5：异步编码改造——解决发布端掉帧

### 修改内容

将编码和发布操作从定时器回调中移出，放入独立线程。定时器只负责将最新帧放入队列，编码线程从队列取帧、编码、发布。

核心代码结构：

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

### 结果

开发板本地：

```text
average rate: 10.00
        min: 0.098s max: 0.104s std dev: 0.002s window: 200
```

稳定 10Hz，不再掉帧。

WSL 端：仍只有 1–3Hz，发布端问题已解决，问题聚焦在订阅端。

## 阶段 6：排查订阅端——发现 QoS 不匹配

### 操作

编写一个简单的 Python 订阅节点 hz\_counter\.py，显式指定 QoS 为 BEST\_EFFORT：

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

运行：

```bash
python3 hz_counter.py
```

实际输出：

```text
[INFO] [hz_counter]: 3 Hz
[INFO] [hz_counter]: 11 Hz
[INFO] [hz_counter]: 11 Hz
[INFO] [hz_counter]: 12 Hz
[INFO] [hz_counter]: 11 Hz
[INFO] [hz_counter]: 11 Hz
... 持续稳定 10-12Hz
```

### 分析

| 订阅方式                               | QoS 设置                | 结果          |
| -------------------------------------- | ----------------------- | ------------- |
| ros2 topic hz /camera/image/compressed | 默认（通常为 RELIABLE） | 卡顿，1–2Hz   |
| hz\_counter\.py（显式 BEST\_EFFORT）   | BEST\_EFFORT            | 流畅，10–12Hz |

根本原因确认：

- 发布端（camera\_pub 节点）使用 create\_publisher\(CompressedImage, "/camera/image/compressed", 10\) 创建发布者。在 ROS 2 Jazzy 中，create\_publisher 的默认 QoS 是 rmw\_qos\_profile\_sensor\_data，即 BEST\_EFFORT。

- 订阅端（ros2 topic hz）的默认 QoS 策略在不同版本中表现不同。在较老版本或特定环境下，它可能默认使用 RELIABLE。

- 当 BEST\_EFFORT 发布端遇上 RELIABLE 订阅端：DDS 中间件会尝试协调，但本质上订阅端要求可靠传输。在 WiFi 环境下，任何丢包都会触发重传请求，导致：

    - 发送端需要缓存数据以支持重传

    - 接收端等待缺失的分片，缓冲区阻塞

    - 最终表现为帧率暴跌、命令卡死

这正是 StereoLabs 官方论坛和 ROS 2 设计指南中明确指出的经典问题。

## 阶段 7：最终验证——画面流畅

### 操作

使用 rqt\_image\_view 并正确指定 QoS：

```bash
ros2 run rqt_image_view rqt_image_view --ros-args \
  -p image_topic:=/camera/image \
  -p _image_transport:=compressed
```

### 结果

画面流畅，无卡顿

有警告（关于直接订阅压缩话题的提示），但可安全忽略，警告内容：

```text
[WARN] [rqt_gui_cpp_node]: [image_transport] It looks like you are trying to subscribe directly to a transport-specific image topic...
```

解释：rqt\_image\_view 通过 image\_transport 机制工作，期望订阅基础话题并通过参数指定传输类型。直接指定完整话题名虽然能工作（因为类型匹配），但不符合 image\_transport 的设计模式。警告不影响功能。

# 第三部分：本质与原理深度分析

## 本质原因

- 根本原因：QoS（服务质量）策略不匹配。

- 发布端（以及自定义订阅脚本）使用 BEST\_EFFORT（适用于流式数据），允许丢包不重传。

- 默认订阅命令（ros2 topic hz、rqt\_image\_view 不加参数）使用 RELIABLE，要求每包必达。

- 当 WiFi 丢包发生时，RELIABLE 会触发长时间重传等待，造成接收阻塞，帧率暴跌。

- 直接原因：发布端定时器内嵌编码操作，导致定时器周期被延长，丢帧。

- 间接原因：一开始错误地尝试 republish 工具，因参数格式问题浪费大量时间。

## 3\.1 QoS 不匹配为什么会导致卡顿？

正常情况（策略匹配）：

```text
发布端 (BEST_EFFORT) → 数据包 → 订阅端 (BEST_EFFORT)
                                     ↓
                              收到即处理，丢包则忽略
```

异常情况（策略不匹配）：

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

关键机制：

- DDS 的 RELIABLE 通过 NACK/ACK 机制 实现，类似 TCP 但更重

- WiFi 丢包率即使只有 1\-2%，也会触发频繁重传

- 接收端的 IP 分片重组缓冲区（默认 4MB）很快被填满，导致新数据无法接收

- 最终形成 重传风暴 → 缓冲区满 → 丢包 → 更多重传 的恶性循环

## 3\.2 为什么压缩是必要条件？

| 指标          | 原始图像              | 压缩图像（JPEG Q=60）  |
| ------------- | --------------------- | ---------------------- |
| 单帧大小      | \~0\.88MB             | \~60KB                 |
| 10Hz 带宽     | \~70Mbps              | \~5Mbps                |
| IP 分片数/帧  | \~600 个              | \~40 个                |
| WiFi 丢包影响 | 任一包丢失 → 整帧重传 | 丢失影响小，重传开销低 |

压缩减少了 90%\+ 的数据量，同时将每帧的 IP 分片数从 600 降至 40，大幅降低了丢包对传输的影响。

## 3\.3 为什么异步编码是必要的？

- cv2\.imencode 在软件编码 JPEG 时，640×480 的图像约需 30\-50ms。

- 定时器周期 = 100ms（10Hz）

- 如果回调中执行编码（\~40ms）\+ 其他操作，总耗时可能超过 100ms

- 导致定时器回调堆积，ROS 2 的执行器会尝试补偿，但最终会丢帧

- 异步编码：

    - 定时器只做轻量操作（复制帧、入队），耗时 \< 1ms

    - 编码在线程中并行执行，不阻塞定时器

    - 队列满时丢弃旧帧，保证实时性

# 第四部分：最终解决方案（完整步骤）

## 4\.1 发布端（开发板）

文件：camera\_pub\.py

关键代码（完整版见附录）：

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

启动命令：

```bash
ros2 run camera_pkg camera_pub
```

## 4\.2 订阅端（WSL）

### 方式 A：使用自定义订阅脚本（推荐用于测试）

文件：hz\_counter\.py（见阶段 6 完整代码）

运行：

```bash
python3 hz_counter.py
```

### 方式 B：使用 rqt\_image\_view（推荐用于观看）

```bash
ros2 run rqt_image_view rqt_image_view --ros-args \
  -p image_topic:=/camera/image \
  -p _image_transport:=compressed
```

注意：不要直接用 rqt\_image\_view /camera/image/compressed，虽然能工作但会产生警告。使用基础话题 \+ \_image\_transport 参数是符合 image\_transport 设计模式的正确用法。

### 方式 C：在代码中显式指定 QoS

```python
from rclpy.qos import QoSProfile, ReliabilityPolicy

qos = QoSProfile(depth=10, reliability=ReliabilityPolicy.BEST_EFFORT)
sub = self.create_subscription(CompressedImage, '/camera/image/compressed', callback, qos)
```

## 4\.3 验证命令

在开发板上验证发布端：

```bash
ros2 topic hz /camera/image/compressed
```

预期：稳定 10Hz

在 WSL 上验证接收端：

```bash
python3 hz_counter.py
```

预期：稳定 10–12Hz

# 第五部分：关键启示与最佳实践

## 5\.1 排查思路总结

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

## 5\.2 核心经验

| \#   | 经验                 | 说明                                                         |
| ---- | -------------------- | ------------------------------------------------------------ |
| 1    | 先用工具，再改代码   | 排查 ROS 2 传输问题优先使用 iperf3、ros2 topic hz、ros2 topic echo 等官方工具，快速区分物理网络、DDS 协议、代码逻辑问题，精准缩小故障范围，避免盲目改代码调试。 |
| 2    | 压缩从源头做起       | image\_transport republish 工具存在严重版本兼容性、参数解析异常问题，稳定性极差，无法用于正式工程；最优方案是直接在图像采集发布节点内完成 JPEG 编码，原生发布 CompressedImage 压缩话题。 |
| 3    | 定时器中避免耗时操作 | 图像编码、文件IO、复杂算法计算、数据序列化等耗时操作，禁止在 ROS 定时器回调中执行，必须独立线程异步处理，防止定时器阻塞、回调堆积、发布端掉帧。 |
| 4    | QoS 必须匹配         | 遵循 ROS 2 官方设计规范，传感器流式数据（图像、雷达、IMU）统一使用 BEST\_EFFORT 策略，牺牲极致可靠性保障实时性；机器人控制指令、参数配置、状态交互等关键数据使用 RELIABLE 可靠传输策略，收发两端策略必须完全匹配。 |
| 5    | 测试工具不一定中性   | ros2 topic hz、rqt 等官方工具的默认 QoS 策略随 ROS 2 版本、Fast DDS 中间件配置变化存在差异，测试结果存在偏差，疑难问题排查必须使用自定义脚本显式指定 QoS 对比验证。 |

## 5\.3 常见错误做法 vs 正确做法

| 场景         | ❌ 错误做法                                                   | ✅ 正确做法                                                   |
| ------------ | ------------------------------------------------------------ | ------------------------------------------------------------ |
| 图像远程卡顿 | 主观判定 WiFi 带宽不足、路由器性能差，盲目更换网络设备       | 先用 iperf3 分高低带宽档位测试网络实际吞吐、丢包率，区分物理网络瓶颈与 DDS 协议层、QoS 匹配问题 |
| 图像压缩失败 | 反复调试 image\_transport republish 命令参数、格式，适配工具兼容性问题 | 放弃工具转发方案，直接在摄像头源码中集成编码逻辑，原生发布 CompressedImage 压缩话题，稳定可靠 |
| 发布端掉帧   | 通过降低定时器发布频率、降低图像分辨率的方式缓解掉帧，牺牲实时性 | 改造异步编码架构，定时器仅负责帧数据入队，耗时编码逻辑独立线程执行，保障固定稳定帧率 |
| WSL 远端卡顿 | 默认归因为 WSL2 虚拟网络性能缺陷、环境兼容性问题             | 优先核对收发两端 QoS 策略一致性，绝大多数跨设备图像卡顿问题由 QoS 不匹配导致，与 WSL 性能无关 |
| 订阅帧率测试 | 仅依靠 ros2 topic hz 工具测试帧率，默认工具配置为准          | 搭配自定义 Python 脚本，显式指定对应场景的 QoS 策略，对比测试，规避工具版本差异带来的测试误差 |

# 附录

## A\. 完整代码

### A\.1 发布端 camera\_pub\.py（异步编码版本）

完整代码详见本文第四部分 4\.1 节，代码实现帧队列缓存、独立线程异步编码、队列满帧丢弃机制，彻底解决定时器阻塞、发布端掉帧问题，适配 ROS 2 Jazzy 版本，可直接编译运行。

### A\.2 订阅端 hz\_counter\.py

完整代码详见本文第二部分阶段 6 节，脚本手动指定 BEST\_EFFORT 专属 QoS 策略，可精准采集图像话题真实接收帧率，规避官方工具默认 QoS 不匹配导致的测试失真问题，是 ROS 2 图像流测试的专用工具脚本。

## B\. 所有命令汇总

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

# 结语

- 本文档从一个具体的"ROS 2 图像卡顿"问题出发，完整记录了从现象观察、网络测试、源码修改、性能优化到最终解决的整个排查过程，并对涉及的核心概念（QoS、压缩、异步编码）做了深入浅出的解释。

- 希望这份文档能帮助遇到类似问题的开发者少走弯路，也为 ROS 2 的工程实践提供一份可复用的排查模板。