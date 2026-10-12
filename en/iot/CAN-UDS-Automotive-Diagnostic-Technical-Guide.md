**English** | [简体中文](../../iot/can_uds车载通信诊断技术文档.md)

<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2026 KY (kyshipit)
-->

# I. CAN Bus

## 1.1 Overview

CAN (Controller Area Network) is a **serial, asynchronous, multi-master fieldbus** standard.

**compatibility** :

- CAN FD controllers are compatible with and can recognize classic CAN messages, but classic CAN nodes cannot process CAN FD messages. In a hybrid network, all nodes need to support FD to use the FD function.
- The frame format of CAN XL differs from CAN FD and classic CAN, making it impossible to mix different frame types on the same network. However, CAN XL controllers are typically designed to be backward compatible, capable of recognizing and processing both CAN FD and classic CAN messages.

characteristic | Classic CAN (CAN 2.0) | CAN FD (Flexible Data Rate) | CAN XL
--- | --- | --- | ---
**Maximum bit rate** | **1 Mbps** | **Arbitration segment: 1 Mbps** , **Data segment:** up to 8 Mbps (some can reach 10 Mbps+). | **Arbitration segment: 1 Mbps** , **Data segment:** up to 20 Mbps (commonly 10-15 Mbps)
**Maximum data payload** | **8 bytes** | **64 bytes** | **2048 bytes**
**Protocol layer** | Data Link Layer | Data Link Layer | **Added network layer functionality**
**Frame format** | Standard Frame / Extended Frame | An improvement on the classic CAN, featuring an FDF bit. | The new frame format is incompatible with CAN/CAN FD.
**Main advantages** | Simple, stable, and low cost | **Higher bandwidth, longer data length** , and compatible with classic CAN | **Ultra-high bandwidth and ultra-large data packets make it suitable for interconnection in scenarios such as automotive Ethernet.**
**Main applications** | Low-speed control such as body control and ECU communication | Vehicle diagnostics, ECU remapping, in-vehicle network backbone | Autonomous driving, onboard high-speed sensor data, and interconnection of regional controllers

Load and speed relationship for the three types of CAN:

- CAN payload is 8 bytes per frame.
- A single CAN FD frame can carry a maximum of 64 bytes (data segment up to 8 Mbps).
- The CAN XL can carry a maximum of 2048 bytes per frame (data segment speed up to 20 Mbps).

The arbitration stage for all three is at a rate of 1 Mbps.

The ISO 11898 standard defines two physical layers:

- **ISO 11898-2** : High-speed closed-loop CAN, communication rate 125 Kbps～1 Mbps, maximum Mbps when bus length ≤ 40 meters.
- **ISO 11898-3** : Low-speed open-loop CAN (also called low-speed fault-tolerant CAN), communication rate 10-125 Kbps, bus distance up to 1000 meters at a transmission rate of 40 Kbps.

CAN uses **a bus topology** with a **120-ohm** terminating resistor at each end for impedance matching and signal reflection elimination.

**Bus topology diagram** :

```
 节点1     节点2     节点3         节点N
  |         |         |            |
  +---------+---------+----....-----+
  |                                |
 [120Ω]                          [120Ω]
  |                                |
 GND                              GND
```

- Each node is connected to the CAN_H and CAN_L differential signal lines via a CAN controller and CAN transceiver.
- Connect a 120Ω terminating resistor at each end of the bus.

## 1.2 Characteristics

1. Multiple nodes can communicate with each other, and the actual number of nodes can reach 110.
2. It adopts a short frame structure, and the effective bytes of the message frame are 8 (classic CAN).
3. The smaller the message ID value, the higher the priority.
4. Non-destructive bus arbitration mechanism (arbitration segment; wired-AND mechanism; the smaller the ID, the higher the priority; if arbitration fails, enter listen-only mode).
5. The reliable CRC check method results in an extremely low data transmission error rate.
6. There is an automatic retransmission mechanism in case of frame arbitration failure or corruption during transmission.
7. In the event of a severe error, the node has the function of automatically disconnecting from the bus, severing its connection with the bus, without affecting the normal operation of the bus.
8. The maximum communication distance is up to 10 km (with a speed of less than 5 Kbps).
9. The maximum communication rate is 1 Mbps (at which point the maximum distance is 40 m).
10. CAN nodes have low design costs and use twisted-pair cables as the communication medium.

**CAN node internal structure** :

```
         MCU/CPU
            |
    +------+------+
    |             |
  TX 引脚      RX 引脚
    |             |
    v             ^
 CAN 控制器 (内置或外挂，如 MCP2515)
    |             |
    v             ^
 CAN 收发器 (如 TJA1050 / SN65HVD230)
    |             |
    +------+------+
    |             |
  CAN_H        CAN_L
    |             |
    +-----+-------+
          |
      双绞线总线
```

### 1.2.1 Comparison of CAN and CAN FD

characteristic | Classic CAN (CAN 2.0) | CAN FD
--- | --- | ---
**Maximum speed** | Typically **1 Mbps** | **Arbitration segment** : Same as classic CAN (≤ 1 Mbps); **Data segment** : Up to **5 Mbps** (CAN FD Non-ISO) or **8 Mbps** (CAN FD ISO), practically up to 10 Mbps or more.
**Data field length** | **Maximum 8 bytes** | **Maximum 64 bytes**
**Frame format** | Standard frame (11-bit ID), extended frame (29-bit ID) | In addition to the standard/extended frames, new **FDF (FD Frame)** and **BRS (Bit Rate Switch)** bits were introduced.
**compatibility** | — | **Backward compatibility** : CAN FD nodes can correctly receive classic CAN messages, but classic CAN nodes cannot correctly parse CAN FD messages (they will report an error).
**CRC check** | 15-bit CRC | More robust CRC check: 17 bits (data length ≤ 16 bytes) or 21 bits (data length &gt; 16 bytes)

## 1.3 Physical Layer

CAN and CAN FD **are essentially the same** at the physical layer. They both use **differential signals** for data transmission, which gives them excellent anti-interference capabilities.

- **Transmission medium** : usually a pair of twisted pairs (CAN_H and CAN_L).
- **Logic level** :
    - **Dominant bit** : Represents logic '0', CAN_H approximately 3.5V, CAN_L approximately 1.5V, differential voltage approximately 2.0V (ISO 11898-2 threshold &gt; 0.9V).
    - **Recessive bit** : Represents logic '1'. Both CAN_H and CAN_L are biased to approximately 2.5V, and the differential voltage is close to 0V (typical value &lt; 0.5V).
- **Topology** : Bus topology with a **120-ohm** terminating resistor at each end for impedance matching and to eliminate signal reflection.
- **Node** : Each node is connected to the bus via a CAN controller and a CAN transceiver.

**Note** : Although the physical layer is the same, to support the higher data segment rate of CAN FD, more stringent requirements are placed on the latency and signal quality of the physical channels (transceivers, cables, etc.). Using a high-speed transceiver that supports CAN FD is a prerequisite.

**Logic level definition** :

Logical value | definition | CAN_H voltage | CAN_L voltage | Differential voltage (CAN_H - CAN_L)
--- | --- | --- | --- | ---
Dominant | Logical '0' | ~3.5V | ~1.5V | &gt; 1.5V
Recessive | Logical '1' | ~2.5V | ~2.5V | ≈ 0V

**Transceiver working principle** : The CAN transceiver is responsible for converting the logic level output from the MCU's TX pin into a differential signal of CAN_H/CAN_L, and converting the received differential signal into the logic level of the RX pin. The conversion between logic signals and physical signals uses a differential level method.

**Diagram showing the connection between the MCU and the CAN transceiver** :

```
  MCU 端                         CAN 收发器端
  ───────                        ────────────
  TX 引脚 ──── 逻辑电平 ────► 转换为 CAN_H/CAN_L 差分信号
  RX 引脚 ◄──── 逻辑电平 ◄──── 从 CAN_H/CAN_L 差分信号恢复
```

### 1.3.1 Frequently Asked Questions and Answers

**1. Why use a differential level signal with two wires (twisted pair)?**

A: When transmitting differential signals over twisted-pair cables, common-mode interference acts on both wires simultaneously. After differential processing at the receiving end, the level difference remains unchanged, and signal decoding proceeds normally. This is the core principle of differential signal anti-common-mode interference.

**2. How to reduce communication errors caused by baud rate errors?**

A: The CAN bus specifies that synchronization is performed at the transition edges of the signal to limit the accumulation of errors to between two transition edges and avoid continuous accumulation of errors.

**3. What happens when there are multiple consecutive 0s or 1s in the transmitted data, and there is no transition edge causing error accumulation?**

A: When multiple identical bits occur, there is no transition edge for synchronization, causing errors to accumulate. **Bit stuffing** is used: after 5 consecutive identical bits, a bit of opposite direction is inserted to generate a transition edge for synchronization.

**4. What can be done about signal reflection and waveform oscillation caused by impedance discontinuity and impedance mismatch, leading to signal crosstalk and information loss?**

A: High-speed CAN adds a terminating resistor (generally 120 ohms in automotive electronics) at each end of the bus to reduce reflections on the communication line and avoid transmission errors caused by level changes.

**5. All ECU nodes tested individually function normally, but the CAN function malfunctions after installation in the vehicle, potentially causing instrument malfunctions and frequent CAN errors. What should be done?**

Key considerations:

- Choose a high-performance isolated transceiver, or an external isolated transceiver.
- Increasing the twisted pair length of the CAN cable ensures better anti-interference capability for differential mode signals.
- Keep power cables and CAN cables away from each other during wiring to suppress periodic pulse interference.
- Add inductive protection devices with good surge immunity, such as common-mode filters, to the CAN terminal.

## 1.4 Link Layer

### 1.4.1 Detailed Explanation of CAN FD Data Frame Fields

Field Block | Field Name | Number of digits | Value types | Key Function Description
--- | --- | --- | --- | ---
**Frame start segment** | **SOF** (Start of Frame) | 1 | Dominant '0' | The frame start synchronization bit is used by all nodes to achieve hard synchronization and mark the start of a new frame.
**Arbitration Section** | **Arbitration Field** | 11/29 | — | **Message identifier** : 11 bits for standard frames; 29 bits for extended frames (11-bit base ID + 18-bit extended ID). Smaller values ​​indicate higher priority.
 | **RTR** (Remote Transmission Request) | 1 | Dominant '0' | Remote transmission request bit: always a dominant '0' in data frames; a recessive '1' in remote frames (rarely used nowadays).
 | **IDE** (Identifier Extension) | 1 | Standard frame: dominant '0', extended frame: recessive '1' | Identifier extension bit: Indicates whether the frame is a standard frame or an extended frame.
 | **FDF** (FD Format) | 1 | Recessive '1' | **CAN FD core flag bit** : Always recessive '1', indicating this is a CAN FD frame. A classic CAN node will report an error if it detects this bit.
 | **r0** (Reserved Bit 0) | 1 | Dominant '0' | Reserved bit: In CAN FD, the dominant bit '0' is always transmitted, reserved for future protocol extensions.
**control section** | **DLC** (Data Length Code) | 4 | 0–15 | **Data length code** : Encoding 0–8 corresponds to 0–8 bytes; encoding 9–15 corresponds to 12, 16, 20, 24, 32, 48, and 64 bytes respectively.
 | **BRS** (Bit Rate Switch) | 1 | Dominant '0' or recessive '1' | **Bit rate switching switch** : Dominant '0' for full arbitration rate; Recessive '1' for data segment switching to a higher rate.
 | **ESI** (Error State Indicator) | 1 | Dominant '0' or recessive '1' | **Error status indicators** : A dominant '0' node is in an active error state; a recessive '1' node is in a passive error state.
**Data segment** | **Data Field** | 0–64 bytes | — | **Effective data payload** : Length determined by the DLC field, maximum 64 bytes, 8 times that of classic CAN. This segment may use a higher transmission rate.
**Check segment** | **CRC field** (Cyclic Redundancy Check) | 17 or 21 | — | **Enhanced Cyclic Redundancy Check (CRC)** : 17-bit CRC is used for data length ≤ 16 bytes; 21-bit CRC is used for data length &gt; 16 bytes.
 | CRC **Delimiter** | 1 | Recessive '1' | The CRC field ends with a marker, at which point the baud rate switches back to the arbitration rate.
**Confirmation Section** | **ACK** Slot | 1 | Recessive '1' → Dominant '0' | Response slot: The transmitter sends a recessive '1', and the node that correctly receives it overwrites it with a dominant '0'.
 | ACK **Delimiter** | 1 | Recessive '1' | ACK delimiter: fixed as a hidden '1' to ensure the ACK slot is correctly defined.
**Ending paragraph** | **EOF** (End of Frame) | 7 | Recessive '1' | End-of-frame marker: Seven consecutive implicit '1's indicate the complete end of the frame transmission.

### 1.4.2 DLC Encoding Table

DLC Value | Data length (bytes)
--- | ---
0–8 | 0–8
9 | 12
10 | 16
11 | 20
12 | twenty four
13 | 32
14 | 48
15 | 64

### 1.4.3 CRC Sequence

A 17-bit CRC is used when the data length is ≤ 16 bytes, and a 21-bit CRC is used when it is &gt; 16 bytes. In addition, the CRC segment includes 3 fixed padding bits (inserted before the CRC sequence) to improve the reliability of high-speed transmission.

### 1.4.4, ESI bit

The ESI bit is an error status indicator for the transmitting node:

- ESI = 0: The sending node is in **an active error state** (TEC &lt; 128).
- ESI = 1: The sending node is in **a passive error state** (TEC &gt; 127).

A node can continue to communicate after entering a passive error state, but this will affect its error handling behavior.

### 1.4.5 Comparison of Classic CAN and CAN FD Frame Structures

Fields and paragraphs | Field Name | Classic CAN | CAN FD | Explanation and Differences
--- | --- | --- | --- | ---
**1. Start of Frame** | SOF | 1 '0' | 1 '0' | **Same** . A dominant bit, indicating the start of a frame.
**2. Arbitration Section** | Identifier (ID) | 11 or 29 bits | 11 or 29 bits | **Essentially the same** . Determine message priority. **A lower arbitration baud rate is used at this stage** .
 | RTR | 1 bit '0' (data frame) | 1 bit '0' (data frame) | **Same** . It is the dominant bit in the data frame.
**3. Control Section** | IDE | 1 person | 1 person | **Same** . Distinguish between standard frames and extended frames.
 | **FDF** | None (or considered recessive r0) | **1 '1'** | **The key difference** is that a hidden '1' indicates a CAN FD frame. A classic CAN node would see this bit, generate an error, and ignore the frame.
 | **BRS** | not applicable | **1 person** | **Key difference** : The '0' data segment is not accelerated; the '1' **data segment switches to a higher baud rate** .
 | **ESI** | not applicable | **1 person** | **Added** . '1' The sending node is in a passive error state; '0' The node is in an active error state.
 | DLC | 4 bits (0–8 bytes) | 4 bits (0–64 bytes) | **Extension** . The DLC encoding table for CAN FD has been extended to support up to 64 bytes of data.
**4. Data segment** | Data Field | **0–8 bytes** | **0–64 bytes** | **Key difference** : CAN FD significantly improves data load capacity. **Higher data segment baud rates may be used at this stage** .
**5. CRC segment** | CRC Sequence | **15 people** | **17 or 21 bits** | **Enhanced** . CAN FD uses a longer CRC to ensure reliability at larger data blocks and higher speeds.
 | CRC Delimiter | 1 '1' | 1 '1' | **Same** . One recessive bit.
**6. Response Section** | ACK Slot | 1 person | 1 person | **Same** . The transmitter sends '1', and the receiver overwrites it with '0' in response.
 | ACK Delimiter | 1 '1' | 1 '1' | **Same** . One recessive bit.
**7. End of frame** | EOF | 7 '1's | 7 '1's | **same** .

### 1.4.6 CAN FD Data Frame Segment Description

**1. Start of Frame (SOF)**

A **dominant** bit ('0'). Marks the start of a frame and is used to synchronize all nodes on the network.

**2. Arbitration Court**

Determines the priority of a message. The smaller the ID value, the higher the priority.

- **Identifier** : 11 bits for standard frames and 29 bits for extended frames (including 11-bit base ID + 18-bit extended ID).
- **RTR bit** : In a data frame, this bit is dominant ('0').
- **IDE bit** : Dominant ('0') for standard frames, recessive ('1') for extended frames.
- **FDF bit** : **CAN FD New!** This bit is **recessive ('1')** , indicating that this is a CAN FD frame. In a classic CAN frame, this bit is reserved and is usually dominant ('0'). This is the key to distinguishing between the two types of frames.
- **r0 bit** : Reserved bit, dominant ('0').

**3. Control Field**

Transmit information about the data length and control bits.

- **DLC** : 4 bits, representing **the number of bytes** in the data field. In CAN FD, the encoding method of DLC is different from that of classic CAN to support 0–64 bytes.
- **BRS bit** : **CAN FD added!** Bit rate switching switch.
    - Dominant ('0'): No switching; the same baud rate (arbitration rate) is used throughout the frame.
    - Recessive ('1'): Switch to a higher **data rate** from the BRS bit to the CRC delimiter.
- **ESI bit** : **CAN FD Added!** Error status indication.
    - Explicit ('0'): The node is in **an active error state** .
    - Implicit ('1'): The node is in **a passive error state** .

**4. Data Field**

The actual valid data to be transmitted. The length is specified by the DLC, and is **0 to 64 bytes** in CAN FD.

**5. CRC Field**

Cyclic redundancy check (CRC) is used to detect transmission errors. Enhancements to CAN FD:

- Because the data is longer and the rate is higher, the probability of errors increases.
- CAN FD uses a longer CRC sequence (17 or 21 bits) and protected padding bits, which greatly improves the verification capability.
- **CRC delimiter** : A fixed hidden bit ('1') that marks the end of the CRC field.

**6. Response Field**

The receiving node confirms whether it has correctly received the message.

- **ACK Slot** : The sending node sends a recessive bit ('1'). Any receiving node that **correctly receives** the frame (regardless of whether it is interested in the data) will send a dominant bit ('0') to the bus during this time period to overwrite it.
- **ACK Delimiter** : A hidden bit ('1') to ensure that the ACK Slot is correctly delimited.

**7. End of frame**

Seven consecutive recessive bits ('1') indicate the end of the frame transmission.

### 1.4.7 Message Frame Types

There are five types of CAN message frames:

Frame type | illustrate
--- | ---
**Data Frame** | The most frequently used frame type when a sending node transmits data to a receiving node.
**remote frames** | The receiving node requests data from a sending node.
**Error Frame** | When a node detects an error, it sends an error notification frame to other nodes.
**Overload frames** | Frames used by the receiving node to notify the sending node of its own receiving capability.
**Frame interval** | A frame that separates a data frame or remote frame from the preceding frame.

### 1.4.8 The 7-segment structure of standard frames and extended frames

Both standard frames and extended frames contain the following 7 segments:

Segment number | Section Name | illustrate
--- | --- | ---
1 | Start of Frame (SOF) | 1 dominant bit, indicating the start of a frame.
2 | Arbitration Section | Includes ID (11 or 29 bits), RTR, IDE, etc.
3 | control section | Includes DLC, FDF (CAN FD), BRS (CAN FD), ESI (CAN FD), etc.
4 | Data segment | Payload: 0–8 bytes (classic CAN) or 0–64 bytes (CAN FD)
5 | CRC segment | Cyclic Redundancy Check (CRC) + Delimiter
6 | Response segment (ACK) | ACK slot + ACK delimiter
7 | End of Frame (EOF) | 7 recessive bits

**Standard frame format (11-bit ID)** :

```
SOF | 11位ID | RTR | IDE(0) | r0 | DLC | 数据段(0-8字节) | CRC | ACK | EOF
```

**Extended frame format (29-bit ID)** :

```
SOF | 11位基ID | SRR(1) | IDE(1) | 18位扩展ID | RTR | r1 | r0 | DLC | 数据段 | CRC | ACK | EOF
```

### 1.4.9 Non-destructive arbitration mechanism

The CAN bus employs **a non-destructive bit-by-bit arbitration** mechanism (CSMA/CD + priority arbitration):

**Arbitration process** :

```
假设节点 A 发送 ID = 0x15 (0010101)，节点 B 发送 ID = 0x1F (0011111)

 位序号:   0    1    2    3    4    5    6
 A发送:   [0]  [0]  [1]  [0]  [1]  [0]  [1]
 B发送:   [0]  [0]  [1]  [1]  [1]  [1]  [1]
          |    |    |     |
        相同  相同 相同   不同!
                          |
                          v
               B 发送 1 (隐性), 但检测到总线上是 0 (显性)
               → B 仲裁失败，进入只听模式
               → A 继续发送，仲裁成功

 规则: 显性位 '0' 覆盖隐性位 '1'（线与机制）
       ID 越小 → 越早出现 '0' → 优先级越高
```

**Actions after arbitration fails** :

- Nodes that fail in arbitration immediately stop sending and enter "listen-only" mode.
- The node that successfully arbitrated continues sending unaffected.
- Nodes that fail to arbitrate will automatically retry after the current frame ends.

### 1.4.10 CAN Error Types and Handling

**Error status classification** :

state | condition | Behavior
--- | --- | ---
**Active error** | TEC &lt; 128 and REC &lt; 128 | It participates in communication normally, and sends **an active error flag** (6 consecutive dominant bits) when an error is detected.
**Passive error** | TEC ≥ 128 or REC ≥ 128 | It participates in communication normally, and sends **a passive error flag** (6 consecutive recessive bits) when an error is detected.
**Bus off** | TEC ≥ 256 | The node is disconnected from the bus and no longer participates in communication.

**CAN Error Counting Rules (Simplified Version)** :

Scene | Count changes
--- | ---
The receiving node detected an error. | REC + 1
The sending node detected an error. | TEC + 8
The receiving node sends an active error flag. | REC + 8 (under specific conditions)
One frame successfully sent | TEC - 1 (when TEC &gt; 0)
One frame successfully received | REC - 1 (when REC &gt; 0)

> For detailed rules, please refer to the error management section of ISO 11898-1.

**Error recovery process** :

```
主动错误状态 ──(TEC≥128)──► 被动错误状态 ──(TEC≥256)──► 总线关闭
     ▲                          │
     │        (TEC<128)         │
     └──────────────────────────┘
     
总线关闭后，节点需等待 128 次 11 位隐性位序列，才能恢复为主动错误状态（TEC 和 REC 清零）。
```

## 1.5 CAN FD Enhancement Features

CAN FD makes the following key enhancements based on classic CAN:

**Rate enhancement mechanism** :

```
仲裁段 (标准速率 ≤ 1 Mbps)               数据段 (高速率 ≤ 8 Mbps)              仲裁段 (标准速率)
  ◄──────────────────────────►  ◄──────────────────────────────────────►  ◄──────────────►
  SOF | ID | 控制 | BRS='1'  →  数据场 (0-64 字节) | CRC | CRC定界符  →  ACK | EOF
                                ↑ 速率切换点                        ↑ 切回仲裁速率
```

**The core advantages of CAN FD compared to classic CAN** :

Enhancement | Classic CAN | CAN FD | income
--- | --- | --- | ---
Data load | 8 bytes | 64 bytes | 8x load increase, reduced frame rate
Data segment rate | Same as the arbitration section | Can be independently upgraded to 8 Mbps | Effective throughput has been greatly improved
CRC check | 15 people | 17/21 bits + fixed padding bits | Enhanced error detection capabilities
Error status | Only within the node | ESI broadcast | Enhanced network diagnostic capabilities

## 1.6 Compatibility issues

**Precautions for hybrid networks of classic CAN and CAN FD** :

Scene | result
--- | ---
CAN FD frames are sent to classic CAN nodes. | A classic CAN node detects a recessive '1' in the FDF bit (which it interprets as a reserved bit error), generates an error frame, and ignores the message.
Classic CAN frames are sent to the CAN FD node. | The CAN FD node received the data correctly, with no compatibility issues.
Two types of nodes exist simultaneously in a hybrid network | All nodes participating in FD communication **must** support CAN FD; otherwise, FD frames will be corrupted by classic CAN nodes.

**CAN XL Compatibility** :

Scene | result
--- | ---
The CAN XL node receives CAN FD / classic CAN frames. | It can identify and process (backward compatible)
CAN FD / Classic CAN node receives CAN XL frame | Unrecognizable, will generate an error.
Hybrid Networks | The CAN XL frame format is completely different from CAN FD/classic CAN and cannot be mixed and matched on the same network.

---

# II. UDS Diagnostic Protocol

## 2.1 Overview

The UDS (Unified Diagnostic Services) diagnostic protocol, also known as the ISO 14229 protocol, is a diagnostic communication protocol used in automotive electronic control units (ECUs).

UDS is a **targeted communication protocol** (Request/Response). The diagnostic tester sends a service request, and the ECU returns a response (positive response/negative response).

**UDS request/response interaction flow** :

```
  Tester (诊断工具)                 ECU (电子控制单元)
       |                                    |
       |  ──── 请求 (Request) ────►         |
       |     SID + SubFunction + Data       |
       |                                    |
       |  ◄──── 响应 (Response) ────        |
       |     肯定响应: SID+0x40 + Data       |
       |     否定响应: 0x7F + SID + NRC      |
       |                                    |
```

> **Background information** : As of 2020, UDS diagnosis consists of the following 8 parts:
>
> - ISO 14229-1-2020: Specifications and Requirements
> - ISO 14229-2-2013: Session Layer Services
> - ISO 14229-3-2012: Unified diagnostic services implemented via CAN (UDSonCAN)
> - ISO 14229-4-2012: Unified Diagnostic Services Enabled by FlexRay (UDSonFR)
> - ISO 14229-5-2013: Unified Diagnostic Services as Implemented by Internet Protocol (UDSonIP)
> - ISO 14229-6-2013: Unified diagnostic service for K-line implementation (UDSonK-Line)
> - ISO 14229-7-2015: Unified diagnostic services implemented via local internet (UDSonLIN)
> - ISO 14229-8-2020: Unified diagnostic services implemented with clock extension peripheral interfaces (UDSonCXPI)

## 2.2 Service ID Overview

UDS services are categorized by functional units. Commonly used services are as follows:

SID (HEX) | Service Name | illustrate
--- | --- | ---
**10** | Diagnostic Session Control | Switch the ECU's diagnostic session mode (default/extended/programming).
**11** | ECU Reset | Reset the ECU; the default session will be activated after the reset.
**14** | Clear Diagnostic Information | Clear fault codes and diagnostic information stored in the ECU.
**19** | Read Diagnostic Trouble Code Information (DTC Information) | Read the fault codes (DTCs) and related status stored in the ECU.
**twenty two** | Read Data By Identifier | Data is read by identifier (DID), such as vehicle speed and voltage.
**twenty three** | Read Memory By Address | Read memory data by address
**twenty four** | Read Scaling Data By Identifier | Read data with conversion formulas by identifier
**27** | Secure Access | Secure unlocking, used for sensitive operations such as flashing software.
**28** | Communication Control | Controls the sending and receiving of ECU messages (mute/restore).
**2A** | Read Data By Periodic Identifier | Periodically read data
**2C** | Dynamically Define Data Identifiers | Dynamically define new data identifiers
**2E** | Write Data By Identifier | Data is written by identifier, such as modifying configuration.
**2F** | Input/output control based on identifier. | Control ECU's I/O ports
**31** | Routine Control | Trigger the ECU to execute specific routines, such as self-test.
**34** | Request Download | The client requests to transmit data to the ECU (flashing/reprogramming).
**35** | Request Upload | The client requests to read data from the ECU.
**36** | Transfer Data | Actual transmitted data blocks
**37** | Request Transfer Exit | Terminating data transmission
**38** | Request File Transfer | Request file transfer operation
**3D** | Write to memory (by address) | Write to memory by address
**3E** | Keep the connection alive (Tester Present) | Keep the ECU in a non-default diagnostic session to prevent S3 timeout.
**83** | Access Timing Parameter | Configure communication timing parameters (optional service, not supported by some ECUs)
**84** | Protected Data Transmission | Encrypted transmission of diagnostic data
**85** | Control Diagnostic Trouble Code Setting | Setting to enable or disable DTC
**86** | Event Response | Response configuration when the event is triggered
**87** | Link control | Control link layer behavior
**90** | Overall system diagnostic capability | Detecting the diagnostic capabilities of the ECU

### 2.2.1 Service Request/Response Format

UDS service requests and responses fall into two categories:

- **It has subfunctions** , such as 0x10 (diagnostic session control), 0x11 (ECU reset), and 0x31 (routine control).
- **Not having a subfunction** : such as 0x22 (read by identifier), 0x2E (write by identifier).

**A positive response format** is: (SID + 0x40) + Subfunction + Data

**Negative response format** : 0x7F + SID + NRC

**Example** :

- Requesting service 0x10, Subfunction 0x02:
    - Positive response: Byte 1 0x50, Byte 2 0x02
    - Negative response: Byte 1 is 0x7F, Byte 2 is 0x10, Byte 3 is NRC

### 2.2.2 Common NRC (Negative Response Codes)

NRC | meaning
--- | ---
0x10 | General Reject
0x11 | Service Not Supported
0x12 | Sub-Function Not Supported
0x13 | Incorrect Message Length
0x22 | Conditions Not Correct
0x31 | Request Out of Range
0x33 | Security Access Denied
0x7F | Service Not Supported in Active Session

> **Note** : 0x7F as an NRC means "the current session does not support this service", which is a different concept from 0x7F as a negative response SID prefix ( `0x7F + SID + NRC` ). Do not confuse them.

## 2.3 Frame Format (UDSonCAN)

UDS transmission over CAN uses the network layer protocol defined by ISO 15765-2 (DoCAN), which is responsible for splitting long UDS messages into CAN frames for transmission.

### 2.3.1 N_PCI (Network Layer Protocol Control Information)

The first byte of the CAN frame data field is N_PCI, which is used to identify the frame type:

Frame type | N_PCI bytes | illustrate
--- | --- | ---
**Single Frame (SF)** | `0x0N` (N = 0–7) | Data length ≤ 7 bytes, one frame completes the transmission. N represents the number of data bytes.
**First frame (FF)** | `0x1N + 后续1字节` | Data length &gt; 7 bytes, first frame. N + the following 1 byte, a total of 12 bits, represents the total data length (FF_DL).
**Continuous Frames (CF)** | `0x2N` (N = 1–15) | Subsequent data frames following the first frame. N is the sequence number (SN), incrementing from 1.
**Flow control frame (FC)** | `0x3N` (N = 0–2) | The receiver controls the transmission rate. N = 0: Continue Transmitting (CTS); N = 1: Wait (WT); N = 2: Overflow (OVFLW)

### 2.3.2 Multi-frame transmission process

**Normal multi-frame transmission process** :

```
  发送方 (Sender)                                 接收方 (Receiver)
       |                                                |
       |  ── 首帧 (FF) ──►                               |
       |    FF_DL = 总数据长度                           |
       |                                                |
       |  ◄── 流控帧 (FC) ──                             |
       |    FS = CTS (0), BS = 块大小, STmin = 最小间隔   |
       |                                                |
       |  ── 连续帧 (CF) SN=1 ──►                        |
       |  ── 连续帧 (CF) SN=2 ──►                        |
       |  ── 连续帧 (CF) SN=3 ──►                        |
       |       ...                                       |
       |  ── 连续帧 (CF) SN=N ──►                        |
       |                                                |
```

### 2.3.3 Detailed Explanation of the N_PCI Field

Fields | Location | illustrate
--- | --- | ---
**SF_DL** | Single frame N_PCI lower 4 bits | The length of a single frame of data in bytes, with a valid range of 0–7. SF_DL=0 indicates no data payload; SF_DL &gt; 7 is invalid.
**FF_DL** | First frame N_PCI lower 4 bits + next byte | The length of the first frame data in bytes (12 bits), valid range 8–4095. FF_DL &lt; 8 is invalid.
**SN** | The lower 4 bits of the consecutive frame N_PCI | Sequence number: 0–F, incrementing from 1, restarting from 1 after overflow. The receiver aborts reception if it detects a non-contiguous sequence number (SN).
**FS** | The lower 4 bits of the flow control frame N_PCI | Stream status: 0 = CTS (Continue Sending), 1 = WT (Wait), 2 = OVFLW (Overflow), 3-F = Reserved
**BS** | Flow control frame data 2nd byte | Block size: The number of CF frames that the sender is allowed to send consecutively. 0 indicates no limit.
**STmin** | Flow control frame data 3rd byte | Minimum interval between consecutive frames. 00–7F: milliseconds (ms); F1–F9: 100 microseconds (µs), e.g., F1 = 100 µs

### 2.3.4 Mapping of N_PDU to CAN Frame

Taking a standard address (11-bit ID) as an example:

```
 N_PDU 格式:
 +----------+----------+------+----------+
 | N_AI     | N_PCI    | Data | ...      |  N_AI = 地址信息 (可选)
 +----------+----------+------+----------+

 CAN 帧映射:
 +---------+----------+------+----------+
 | CAN ID  | N_PCI    | Data | ...      |  (最多 8 字节/经典CAN, 64字节/CAN FD)
 +---------+----------+------+----------+

 标准地址模式: N_AI 不占用数据场字节，通过 CAN ID 区分
 扩展地址模式: N_AI 占用数据场第 1 字节
 混合地址模式: 根据 CAN ID 范围决定是否使用地址字节
```

## 2.4 Session Mode

### 2.4.1 Three Session Modes

The UDS protocol defines three session modes, listed from lowest to highest privilege level:

Session mode | Sub-function code | Permissions | use
--- | --- | --- | ---
**Default Session** | 0x01 | lowest | The default state of the ECU after power-on. Minimal operational services are available, such as basic operations like reading DTCs and reading data.
**Extended Session** | 0x03 | medium | Most diagnostic functions are performed in this mode. It is used for writing VIN/serial numbers, controlling application communication, updating fault information, and unlocking high-privilege diagnostic services.
**Programming Session** | 0x02 | Highest | Used for ECU programming. Automatically redirects to the default session upon timeout or programming failure.

### 2.4.2 Session Switching Rules

**The switching relationship specified by the UDS standard** (ISO 14229) is that the three session modes are at the same level and are independent, and theoretically they can be switched between each other.

**Switching restrictions in practical engineering** (safety considerations):

```
                         默认会话 (Default)
                        /                \
                       /  (可以切换)       \  (禁止直接切换)
                      v                    v
              扩展会话 (Extended)      编程会话 (Programming)
                      \                    /
                       \  (禁止直接切换)   /
                        v                v
                         默认会话 (Default)

              S3 定时器超时 或 ECU 复位 (0x11) → 返回默认会话
```

**Summary of switching rules** :

Current Session | Target Session | Is it allowed? | reason
--- | --- | --- | ---
Default Session | Extended Session | ✅ Allowed | Normal privilege escalation
Default Session | Programming Session | ❌ Prohibited | Security unlocking must be performed via an extended session first.
Extended Session | Programming Session | ✅ Allowed | After secure unlocking, proceed with flashing.
Extended Session | Default Session | ✅ Allowed | Normal downgrade
Programming Session | Extended Session | ❌ Prohibited | Preventing the process from reverting to a high-privilege state during flashing
Programming Session | Default Session | ✅ Allowed | Flashing complete or exit

### 2.4.3 Why is it designed this way?

**Core Reason 1: Forced Intervention for Secure Access**

The secure access service (0x27) is the only key, and this key is only kept in the "Extended Session" room.

- **Why can't you go directly from "Default" to "Programming"?** The programming session (flashing) is the highest-risk operation and must be verified through secure access (0x27). In the ECU software design, secure access is only available in extended and programming sessions, and is disabled in the default session. Therefore, you must first enter the extended session to complete the secure unlock.

```c
// 伪代码：安全访问服务处理函数
void handleSecurityAccess(uint8_t* data) {
    // 【关键检查】如果不在扩展或编程会话，直接拒绝
    if ((currentSession != EXTENDED_SESSION) && (currentSession != PROGRAMMING_SESSION)) {
        sendNegativeResponse(0x27, NRC_SERVICE_NOT_IN_SESSION);
        return;
    }
    // ... 否则，继续处理种子和密钥
}
```

- **Why can't we go directly back to "Extended" from "Programming"?** This is to prevent "circling back" to another high-privilege state during the flashing process, which could potentially lead to unexpected operations and disrupt the rigorous flashing process. The Programming session is designed as a **single-purpose, clean environment** , dedicated solely to flashing-related tasks.

**Second core reason: The simplicity and reliability of state machines**

Engineers tend to design a **linear** , rather than mesh-like, clear state flow. Idealized safety process:

```
 默认会话 ──► 扩展会话 ──► 安全解锁(0x27) ──► 编程会话
    ▲                                           │
    │◄──────────── 刷写完成/复位(0x11) ──────────│
    │◄──────────── S3 超时 ──────────────────────│
```

- **The access path is linear and controlled** : Default → Extended → Secure Unlock → Programming. There are no shortcuts.
- **The exit path is predetermined** : after flashing, **the system returns to the default session directly** via ECU reset (0x11) or timeout. This is a "hard reset," ensuring the ECU returns to a clean, known initial state.

Allowing free switching between "programming" and "extending" creates a loop that complicates state management and requires handling more edge cases.

```c
// 伪代码：处理 0x10 诊断会话控制服务
void handleDiagnosticSessionControl(uint8_t* data) {
    requestedSession = data[1]; // 获取请求的子功能（目标会话）

    // 【规则1：禁止从默认直接到编程】
    if ((currentSession == DEFAULT_SESSION) && (requestedSession == PROGRAMMING_SESSION)) {
        sendNegativeResponse(0x10, NRC_CONDITIONS_NOT_CORRECT); // 0x22
        return;
    }

    // 【规则2：禁止从编程直接到扩展】
    if ((currentSession == PROGRAMMING_SESSION) && (requestedSession == EXTENDED_SESSION)) {
        sendNegativeResponse(0x10, NRC_CONDITIONS_NOT_CORRECT); // 0x22
        return;
    }

    // 【允许的切换路径】
    if (isSessionSupported(requestedSession)) {
        currentSession = requestedSession;
        startS3Timer();
        sendPositiveResponse(0x50, ...);
    } else {
        sendNegativeResponse(0x10, NRC_SUB_FUNC_NOT_SUPPORTED); // 0x12
    }
}
```

---

# III. The Relationship Between CAN and UDS

**UDS is an important set of "traffic rules" or "advanced communication protocols" that run on the CAN bus, the "information highway".**

- **Dependencies** : UDS relies on the CAN bus. CAN is the foundation of the physical layer and the underlying data link layer, while UDS is the application layer protocol. Without the CAN "highway," the UDS "communication manual" would be useless.
- **Division of labor and cooperation** :
    - **The CAN bus** operator says, "I have a data packet here with the subject '0x7E0', and I'm sending it to you now."
    - **The UDS protocol** is responsible for: when the ECU receives this data packet, it parses it and finds that the content is `0x22 0xF4 0x0C` , thus understanding: "Oh, the other party is asking me (using the 0x22 service) to read data (such as vehicle speed) with the identifier 0xF40C, and I need to prepare the data and reply to it."
- **analogy** :
    - **The CAN bus** is like **the TCP/IP protocol on the Internet** , responsible for sending data packets from your computer to the server.
    - **UDS,** like **the HTTP protocol** , defines whether you want to "GET" a webpage or "POST" data. The Internet (TCP/IP) is responsible for transmission, while HTTP is responsible for defining the meaning of the transmitted content.

**OSI layer correspondence** :

OSI layer | Protocol/Standard | illustrate
--- | --- | ---
**Application layer** | ISO 14229 (UDS) | Definition of diagnostic services
**Network layer** | ISO 15765-2 (DoCAN) | Multi-frame transmission, flow control
**Data Link Layer** | ISO 11898-1 (CAN 2.0 / CAN FD) | Frame format, arbitration, error handling
**Physical layer** | ISO 11898-2 / 11898-3 | Differential signals, level definitions, topology

### 3.1 Summary of core differences between classic CAN and CAN FD

Fields | Classic CAN | CAN FD | Difference Interpretation
--- | --- | --- | ---
**FDF position** | Reserved bit r0 ( **dominant '0'** ) | **FDF bit** (recessive '1') | **Identification identifier** . A classic CAN node will report an error if it sees '1'.
**Data Field** | Fixed **0–8 bytes** | Flexible **0–64 bytes** | **The load capacity** has been greatly improved.
**BRS position** | Does not exist | **Bit rate switching switch** | **Performance is key** . It achieves "slow arbitration, fast transmission".
**ESI position** | Does not exist | **Error status indicator** | It enhances the network's diagnostic capabilities.
**CRC field** | Fixed **15-bit** CRC | **17-bit or 21-bit** CRC | **Enhanced reliability** . Addresses the risk of errors in high-speed, long data frames.
**Transmission rate** | Single baud rate throughout | **Arbitration segment** : Standard rate; **Data/CRC segment** : High rate possible. | **Efficiency improvement** . Significantly increase effective data throughput without compromising the reliability of arbitration.

It is clear how CAN FD, while inheriting the robust arbitration and error handling mechanisms of classic CAN, has achieved a leap in performance and efficiency by introducing key control bits and flexible rate switching.

---

# IV. Test

## 4.1 CAN Analyzer Wiring

Connect the CAN analyzer (such as PCAN or Kvaser) to the target board:

Analyzer end | target board end | illustrate
--- | --- | ---
CAN_H | CAN_H | CAN high line
CAN_L | CAN_L | CAN low line
GND | GND | Must share land

**Termination resistors** : 120Ω are required at each end of the bus. Some analyzers have built-in termination resistors; please confirm whether they are enabled. If both the analyzer and the ECU have termination resistors enabled, the resistors may be connected in parallel at 60Ω, affecting communication.

## 4.2 J-Link SWD Debugging Wiring

If you are using J-Link to debug the MCU, the SWD wiring is as follows:

J-Link pin | Signal | Target board | illustrate
--- | --- | --- | ---
1 | VTref | VDD (Target Board) | Reference voltage is required! Used for level matching.
4 | GND | GND | The ground wire must be connected!
7 | TMS/SWDIO | SWDIO | The SWD data cable is a must!
9 | TCK/SWCLK | SWCLK | The SWD clock cable must be connected!
11 | nRESET | RESET | A reset signal is strongly recommended!

> **Note** : CAN analyzers and J-Links are two different devices. CAN analyzers are used to monitor CAN bus communication, while J-Links are used to debug MCU firmware. Do not confuse their connection methods.

## 4.3 Examples of Commonly Used UDS Test Commands

The following is an example of sending a UDS command using a CAN analyzer (using a standard 11-bit ID, diagnostic request ID = 0x7E0, and response ID = 0x7E8 as an example):

Purpose | Send data | Expecting a positive response
--- | --- | ---
Enter extended session | `02 10 03 00 00 00 00 00` | `02 50 03 00 00 00 00 00`
Enter programming session | `02 10 02 00 00 00 00 00` | `02 50 02 00 00 00 00 00`
Read VIN (DID 0xF190) | `03 22 F1 90 00 00 00 00` | `11 62 F1 90 [17字节VIN]`
Secure Access - Seed Request (Level 0x01) | `02 27 01 00 00 00 00 00` | `06 67 01 [4字节种子]`
Secure Access - Send Key (Level 0x01) | `06 27 02 [4字节密钥]` | `02 67 02 00 00 00 00 00`
Read DTC (0x19 service) | `03 19 02 08 00 00 00 00` | Includes the number of DTCs and their specific DTC codes.
Hardware reset (0x11 service) | `02 11 01 00 00 00 00 00` | `02 51 01 00 00 00 00 00`
Keep the connection alive (Tester Present) | `01 3E 00 00 00 00 00 00` | `01 7E 00 00 00 00 00 00`

**Data format description** :

- Byte 1: Single Frame N_PCI (e.g., `02` = single frame, 2 bytes of data; `03` = single frame, 3 bytes of data)
- 2nd byte: SID (Service ID)
- Subsequent bytes: Subfunction or data
- If the data is less than 8 bytes, it is padded with `00` (CAN classic frame has a fixed 8-byte data field).

## 4.4 Test Precautions

1. **Baud rate matching** : Confirm that the baud rate of the CAN analyzer matches that of the target ECU (commonly 500 Kbps or 250 Kbps).
2. **Termination resistors** : Confirm that there are 120Ω termination resistors at both ends of the bus, and that the internal termination resistors of the analyzer are enabled/disabled correctly.
3. **Common ground** : The CAN analyzer and ECU must share a common ground, otherwise communication will be unstable.
4. **Session timeout** : Extended sessions and programming sessions have an S3 timer (default 5 seconds) that needs to periodically send 0x3E to keep the connection open; otherwise, it will automatically fall back to the default session.
5. **Secure access** : You must access the device securely via 0x27 before flashing; otherwise, operations such as 0x34 (request to download) will be rejected.
6. **CAN ID filtering** : Confirm the correspondence between diagnostic request ID and response ID (usually the request ID is 0x7E0 and the response ID is 0x7E8; physical addressing).
