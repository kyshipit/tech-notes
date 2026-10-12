**English** | [简体中文](../../iot/蓝牙低功耗完整通信原理解析.md)

<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2026 KY (kyshipit)
-->

# From loudspeakers to private messages: The principles of Bluetooth Low Energy communication technology

**Disclaimer:** This article is based on the Bluetooth Core Specification, publicly released by the Bluetooth Special Interest Group (Bluetooth SIG). The "typical designs" and "common practices" mentioned are publicly available general engineering practices in the embedded systems and IoT industries, **and do not represent proprietary implementations for any specific product, nor do they constitute a disclosure of product specifications or trade secrets** . This article is not an official SIG document and is for educational purposes only, provided as is (AS-IS).

## Table of contents

- [Introduction: Let's start with the overall picture; what does a complete Bluetooth communication look like?](#chapter-intro)
- [I. Low-power design (Bluetooth Low Energy / Advertising Interval / Connection Interval)](#chapter1-lowpower)
- [II. Physical Channel and Protocol Stack (Physical Channel / GAP / GATT / L2CAP / ATT)](#chapter2-phys-protocol)
- [III. Broadcasting and Scanning (Advertising / Scanning / ADV_IND / ADV_NONCONN_IND)](#chapter3-adv-scan)
- [IV. Connection and Encryption (Connection / LTK / LE-ACL)](#chapter4-connect-encrypt)
- [V. Authentication (Challenge-Response)](#chapter5-auth)
- [VI. Command Interaction (Command / Response / TLV / CRC16)](#chapter6-command)
- [VII. Security Mechanisms (RPA / Replay Attack / Whitelist / IRK / CSRK)](#chapter7-security)
- [8. Power Consumption and Fault Tolerance (Dynamic Interval / OTA A/B Partition)](#chapter8-power-fault)
- [Conclusion](#chapter-conclusion)
- [appendix](#chapter-appendix)

<a id="chapter-intro"></a>

## Introduction: Let's start with the overall picture; what does a complete Bluetooth communication look like?

You take out your car key and press the button, and the door opens.

How does the key know where the car is? How does the car know it's your key? What happens in between?

The whole process is as follows:

The key is usually asleep. You press a button, it wakes up, and starts calling out, "Any cars looking for me?" The car, always listening intently, responds, "Yes, let's talk privately." Thus, a private chat channel is established. Once the channel is open, they exchange a code word to confirm the other party is the right person. Only after the code word matches will the command you pressed be executed. Once the task is completed, the connection is closed, and the key goes back to sleep.

These are the steps: **wake up → shout → hear → private chat → exchange passwords → execute → disconnect → sleep.**

Let's break it down.

<a id="chapter1-lowpower"></a>

## I. Low-power design (Bluetooth Low Energy / Advertising Interval / Connection Interval)

### 1.1 Why do we need to "sleep"?

The key is usually asleep.

"Sleeping" means that Bluetooth is completely turned off—no broadcasting, no connection, no data transmission or reception; only an ultra-low-power sensor is still listening for external sounds. The overall current consumption is reduced to the microampere level.

Why is this necessary? Button batteries have limited capacity. If the Bluetooth radio frequency is continuously operating, the current is in the milliamp range, and the battery will run out in a few days. To allow the device to last for years, it must be in sleep mode more than 99% of the time, only waking up to work when necessary, and then immediately going back to sleep afterward.

This is the fundamental meaning of the name Bluetooth Low Energy – “low power” is not a marketing term, but a design principle that runs through the entire process from the physical layer to the application layer.

### 1.2 Hibernation and Wake-up

When entering sleep mode, all Bluetooth radio frequencies are turned off. It does not broadcast, scan, connect, or process any communication transactions. Only the wake-up detection circuit remains active.

Wake-up is triggered only by pressing a button.

Why not use motion wake-up? When the device is in your pocket, walking, bending over, or sitting all cause changes in acceleration. If you use a motion sensor to wake it up, it could be falsely woken up hundreds of times a day, draining the battery. Only pressing a button provides a clear signal that the user is using the device.

Some designs also include additional measures to prevent accidental touches: a short press is ineffective; the button must be held down for a certain duration, or both buttons must be pressed simultaneously, to activate the function.

### 1.3 Broadcast Interval

After the device is woken up, it enters broadcast mode and begins sending broadcast packets.

Broadcasting is not continuous transmission—after sending a broadcast packet, the device shuts down its radio frequency and enters a brief sleep state, waiting for the next broadcast opportunity to arrive before sending the next one. The time between the start of two consecutive broadcast events is called **the advertising interval** .

The essence of broadcast intervals is a trade-off between power consumption and response speed:

interval | Effect
:-- | :--
short | A higher number of broadcasts per unit time allows for faster detection and response by the scanner, but also results in higher average power consumption.
long | It broadcasts fewer times per unit time and consumes less power, but the scanner needs to wait longer to detect the device.

The device uses different broadcast intervals at different stages. Short intervals are used when a fast response is needed, long intervals are used when there is no urgent need to be detected in order to reduce power consumption, and the intervals are automatically extended when the battery is low to extend the remaining battery life.

### 1.4 Connection Spacing

Once a connection is established, communication occurs in units of **connection events** . During each connection event, both parties simultaneously wake up, exchange data packets on the agreed data channel, and then return to sleep mode until the next connection event arrives.

The time between the start of two consecutive connection events is called **the connection interval** .

The Bluetooth specification defines connection intervals ranging from 7.5 milliseconds to 4 seconds. Shorter intervals result in higher data throughput and faster response times, but also higher average power consumption. Longer intervals result in lower power consumption, but also increased data latency.

Typical designs support dynamic adjustment of connection intervals: short intervals are used when there is frequent data exchange; long intervals are used when there is no data exchange for a long time; and connections are actively disconnected after idle timeout.

### 1.5 The Essence of Power Management

Adjusting the broadcast interval and connection interval essentially controls the proportion of radio frequency operating time to the total time—that is, **the duty cycle** .

The lower the duty cycle, the lower the average power consumption. The core mechanism by which BLE achieves microampere-level average power consumption is to keep the device in sleep mode during all non-essential times, and only turn on the radio frequency during a predetermined short window.

<a id="chapter2-phys-protocol"></a>

## II. Physical Channel and Protocol Stack (Physical Channel / GAP / GATT / L2CAP / ATT)

### 2.1 ISM band

Bluetooth Low Energy operates in the 2.4GHz ISM band.

The ISM (Industrial, Scientific and Medical) band is a radio frequency band designated globally by the International Telecommunication Union Radiocommunication Sector (ITU-R) for free use by industrial, scientific research, and medical equipment. The 2.4 GHz band covers the range from 2.400 GHz to 2.4835 GHz, with a total bandwidth of 83.5 MHz, and is universally applicable without requiring a license.

The price of free use is congestion. Wi-Fi, ZigBee, Bluetooth, and microwave ovens all operate on this frequency band, and devices must coexist in the shared band through technical means.

### 2.2 Channel Allocation

BLE divides the 2.4GHz band into 40 physical channels, each with a width of 2MHz, numbered from 0 to 39 according to the center frequency.

These 40 channels are divided into two categories:

**3 advertising channels:**

Channel number | Center frequency
:-- | :--
37 | 2402 MHz
38 | 2426 MHz
39 | 2480 MHz

The three broadcast channels are distributed across the frequency band—one each at the low, mid, and high ends. This design is to prevent all three broadcast channels from being interfered with by Wi-Fi signals simultaneously. Wi-Fi channels typically occupy the middle or specific locations within the frequency band, and this distributed layout ensures that at least one broadcast channel can operate normally without interference.

**37 data channels:**

Numbered 0 to 36, covering the range of 2404MHz to 2478MHz, they are used for data transmission after the connection is established.

### 2.3 Operating Mode of Broadcast Channel

When the device is in broadcast mode, it sequentially sends the same broadcast packet on three broadcast channels during each broadcast event.

A typical transmission sequence for a broadcast event is as follows: a broadcast packet is sent on channel 37, then switched to channel 38, and then switched to channel 39. The broadcast event ends after transmission is completed on all three channels. The next broadcast event then begins again on channel 37.

It should be noted that if the broadcaster receives a connection request (CONNECT_REQ) midway through a broadcast event, the broadcast event will terminate immediately and will no longer send broadcast packets for the remaining channels.

Why send it on all three channels? Because the scanner might be listening on any channel. The scanner switches between listening on the three broadcast channels in turn, and the broadcaster sends on the three channels in turn. As long as both parties match on the same channel at the same time, a broadcast reception can be completed.

### 2.4 Data Channel and Frequency Hopping

After the connection is established, communication switches to 37 data channels. Data communication uses **Adaptive Frequency Hopping (AFH)** .

The basic process of frequency hopping:

- When establishing a connection, the master and slave devices agree on the frequency hopping sequence generation algorithm and initial seed through parameters in CONNECT_REQ.
- At the start of each connection event, both parties independently use the same algorithm to calculate the channel number to be used.
- Both parties switch to the same channel at the same time to complete the data exchange.
- In the next connection event, both parties calculate the next channel and continue hopping.

Frequency hopping solves two problems:

**First, it resists interference.** The 2.4GHz band is congested, and devices such as Wi-Fi can cause sudden interference. Frequency hopping allows communication to switch between 37 channels continuously. When one channel is interfered with, communication can quickly switch to another channel to continue.

**Second, security.** Frequency hopping makes it impossible for attackers to predict which channel the next packet will appear on.

### 2.5 Protocol Stack Layered Architecture

The Bluetooth protocol stack employs a strictly layered architecture. Each layer has clearly defined responsibilities, and lower layers provide standard service interfaces to upper layers.

hierarchy | name | Duties
:-- | :-- | :--
Level 1 | Physical layer (PHY) | Modulation/demodulation converts bitstreams into wireless signals.
2nd floor | Link Layer (LL) | Device address management, assembly and parsing of broadcast/data PDUs, automatic retransmission, and link layer encryption.
Level 3 (Host) | L2CAP | Protocol reuse, data packetization and reassembly, flow control
Level 3 (Host) | ATT | Property protocols define property read and write operations in a client-server model.
Level 3 (Host) | GAP | Broadcast, scan, connect, and pairing process management
Level 3 (Host) | GATT | Based on the ATT service framework, define the data organization methods for feature values ​​and services.
Level 3 (Host) | SM | Security management, pairing process, key generation and distribution

### 2.6 GAP layer

GAP (Generic Access Profile) is the core layer for BLE device discovery and connection management.

GAP defines four device roles:

Role | Behavior
:-- | :--
Broadcaster | Only broadcasts, does not accept connections.
Observer | Only receive broadcasts, do not initiate connections.
Peripheral devices | Broadcastable and connectable
Central facilities | Can scan and initiate connections

In a typical key-vehicle scenario, the key acts as a peripheral device broadcasting information, while the vehicle acts as a central device performing scanning and initiating connections.

### 2.7 GATT Layer

GATT (Generic Attribute Profile) defines how data is exchanged after a connection is established.

The core concepts of GATT:

- **Service:** A set of related characteristics that represents a complete logical functional module.
- **Characteristic:** The smallest unit of data interaction, containing a value and zero or more descriptors.
- **Descriptor:** An additional attribute that describes a feature value.

In actual product design, a dedicated service with a 128-bit UUID can be defined, containing two characteristic values: one for issuing commands and the other for responding to reports and notifications.

GAP manages "how to connect," while GATT manages "how to transmit data after connection." Both operate at the same level in the protocol stack, but their responsibilities are separated.

<a id="chapter3-adv-scan"></a>

## III. Broadcasting and Scanning (Advertising / Scanning / ADV_IND / ADV_NONCONN_IND)

### 3.1 Broadcast State and Scan State

After the device is woken up, it enters broadcast mode and begins to send broadcast PDUs sequentially on three broadcast channels.

The core behavior of broadcast mode is that the device periodically sends broadcast PDUs and enters a brief sleep state between two broadcast events to reduce power consumption.

The scanning device is in scanning mode, listening sequentially on three broadcast channels.

There are two scanning modes:

- **Passive scanning:** Only receives broadcast PDUs and does not send any requests.
- **Active Scanning:** Upon receiving a broadcast PDU, a SCAN_REQ (scan request) is sent to the broadcaster. The broadcaster, upon receiving this, replies with additional data using a SCAN_RSP (scan response).

In a typical design, the scanner uses active scanning to obtain complete broadcast data.

### 3.2 Broadcast PDU Types

The Bluetooth specification defines several PDU types for broadcast channels. Two commonly used types are:

**ADV_IND: Connectable, scannable, non-directional broadcast.**

ADV_IND is the most common broadcast PDU. It indicates that the broadcaster can be connected to and will also respond with SCAN_REQ. After receiving ADV_IND, the scanner can send SCAN_REQ to request more data or send CONNECT_REQ to establish a connection.

**ADV_NONCONN_IND: Unconnectable, unscannable, non-directional broadcast.**

ADV_NONCONN_IND indicates that the broadcaster only sends signals, does not accept connection requests, and does not respond to SCAN_REQ. This type is characterized by being the most efficient—the broadcaster does not need to reserve time for any response.

These two PDU types can be selected according to different business scenarios.

### 3.3 Broadcast Data Format

Broadcast data consists of one or more Ad Structures. Each Ad Structure follows the LTV (Length-Type-Value) format:

- **Length (1 byte):** Total number of bytes for AD Type and AD Data
- **AD Type (1 byte):** Data type identifier, defined by the Bluetooth Core Specification Supplement.
- **AD Data (Length-1 byte):** Specific data payload

Common AD Type values ​​include:

AD Type | meaning
:-- | :--
0x01 | Flags (Device Discovery Mode, LE Capability Flags)
0x03 | Complete List of 16-bit Service UUIDs
0x09 | Complete Local Name
0xFF | Manufacturer Specific Data

**Regarding AD Type 0xFF (Manufacturer Specific Data):**

This is a vendor-defined data type reserved in the Bluetooth core specification. When AD Type is 0xFF, the first two bytes of AD Data are the Company ID (a vendor ID assigned by the Bluetooth SIG), and the subsequent bytes are defined by the vendor. WeChat's AirSync protocol, iBeacon protocol, and others all use this field to carry custom data.

The receiver identifies the broadcast source by checking the AD Type and Company ID.

### 3.4 Implementation Mechanism of Broadcast Interval

The broadcast interval is the time between the start of two consecutive broadcast events.

A broadcast event refers to the process of sequentially sending all broadcast PDUs on three broadcast channels. For ADV_IND, a broadcast event consists of the transmission of three broadcast packets, located on channels 37, 38, and 39 respectively.

The broadcast interval is controlled by a link-layer timer. After each broadcast event ends, the link layer starts a counter, and the next broadcast event is triggered when the counter overflows.

### 3.5 Address Type

The broadcast PDU contains the address of the sending Bluetooth device. The Bluetooth specification defines several address types; typical designs use the following two:

**Static address:**

A 48-bit address is randomly generated during device initialization and stored in non-volatile memory. It remains unchanged throughout the device's lifetime.

Features: Long-term stability, easy for other devices to identify and bind. Disadvantage: May be used for location tracking.

**Resolvable Private Address (RPA):**

The RPA is updated periodically by the device—typically every 15 minutes or after each connection is lost. It consists of a 24-bit hash and a 24-bit prand. The lower 22 bits of the prand are random numbers, and the highest 2 bits are address type flags. Only devices with the correct IRK (Identity Resolving Key) can resolve the RPA to their true identity.

Features: Cannot be recognized by devices without IRK, and cannot be used for long-term location tracking.

<a id="chapter4-connect-encrypt"></a>

## IV. Connection and Encryption (Connection / LTK / LE-ACL)

<a id="chapter4-connect-encrypt"></a>

### 4.1 Connection Initiation

After receiving ADV_IND, the scanning party sends CONNECT_REQ (connection request) on the same broadcast channel. Upon receiving CONNECT_REQ, the broadcaster immediately terminates the current broadcast event, and both parties simultaneously enter the connected state.

CONNECT_REQ contains the key parameters required to establish a connection:

- **Access Address:** A 32-bit random value used to uniquely identify the connection in the data channel.
- **Frequency hopping algorithm parameters:** including the initial seed of the frequency hopping sequence and the channel mapping table.
- **Connection interval:** The time interval between connection events.
- **Slave latency:** The maximum number of connection events that a slave device can skip without responding.
- **Timeout period:** The threshold for determining connection loss.
- **Channel mapping:** Marking which of the 37 data channels are available and which are not.

Once the connection is established, the broadcaster stops broadcasting.

### 4.2 Connection Events and Connection Intervals

Communication in the connected state is measured in units of connection events.

Definition of a connection event: The master and slave devices simultaneously wake up from hibernation at an agreed-upon time, switch to the agreed-upon data channel, and exchange data packets. A single connection event can contain multiple round trips of data packets.

At the start of each connection event, the master device sends a data packet, and the slave device replies after a pre-agreed time. If the master device has no data to send, it can send an empty packet to maintain the connection. If the slave device has no data to send, it can skip the connection event (subject to the slave device's delay parameter).

The choice of connection interval involves trade-offs in three aspects:

Connection interval | Power consumption | Response delay | Data throughput
:-- | :-- | :-- | :--
short | high | Low | high
long | Low | high | Low

### 4.3 Device Delay

Slave latency is another key power-saving parameter for BLE.

Definition: The maximum number of consecutive connection events that a slave device can skip without responding when there is no data to send.

This mechanism allows the slave device to further reduce power consumption when idle—it does not need to wake up for every connection event and can skip multiple connection events in succession to continue sleeping.

### 4.4 LE Data Connection

Once a BLE connection is established, communication uses LE-ACL logical transmission. All commands, responses, and notifications are carried through LE-ACL.

LE-ACL is an asynchronous transmission that supports packet retransmission. It does not guarantee fixed latency, but it guarantees reliable delivery.

### 4.5 LTK Generation Mechanism

When a connection is established, both parties perform a Bluetooth secure pairing process.

The matching process consists of three stages:

**Phase 1: Pairing Feature Exchange**

Both parties exchange I/O capabilities, authentication requirements, and key distribution requirements.

**Phase 2: Key Generation**

Based on the information exchanged in Phase 1, temporary and short keys are generated using Elliptic Curve Key Negotiation (ECDH) or standard key negotiation methods. LE Secure Connections use ECDH to generate single-use keys, independent of temporary (TK) or short-use (STK) keys.

**Phase 3: Key Distribution**

After authentication is complete, both parties distribute keys for subsequent encrypted connections:

- **LTK (Long Term Key):** A 128-bit key used to encrypt all data packets after the connection is established.
- **IRK (Identity Resolving Key):** Used to resolve RPA addresses.
- **CSRK (Connection Signature Resolving Key):** Used for data signing and verification.

Once pairing is complete, LTK is stored in the non-volatile memory of both devices.

### 4.6 Link Layer Encryption

LTK is managed by the link layer and is completely transparent to the upper layers.

When the upper layer has data to send, the data is directly handed over to the link layer. The link layer encrypts the data packet using the current link layer session key and then sends it through the physical layer. Upon receiving the data, the receiving link layer automatically decrypts it and delivers the plaintext data to the upper layer.

Encryption uses the AES-CCM algorithm, a combined encryption and message integrity check mode. AES-CCM uses a 128-bit key to generate a message integrity check code (MIC) while encrypting the data, ensuring that the data is both confidential and intact.

<a id="chapter5-auth"></a>

## V. Authentication (Challenge-Response)

### 5.1 Why is application layer authentication needed?

LTK protects the confidentiality and integrity of communication channels—it ensures that the data in the channel is not eavesdropped on or tampered with.

However, LTK does not solve the identity problem. Any device can establish a Bluetooth connection with another device and negotiate LTK because BLE's link-layer encryption does not verify the application-layer identity of the other device.

Therefore, an **application layer authentication** is needed on top of the LTK-protected channel to verify the legitimate identity of the communicating peer.

### 5.2 Challenge-Response Mechanism

Application layer authentication employs **a challenge-response** mechanism. This is a standard authentication method widely used in IoT and embedded device authentication—the authenticator proves they possess the correct key material without needing to transmit the key directly over the channel.

The basic logic of the authentication process is as follows:

1. The verifier generates a random number (challenge value) and sends it to the verifier via an encrypted channel.
2. After receiving the random number, the verified party performs calculations in secure hardware using internally stored key materials, and sends the calculation result back along with its own random number.
3. The verifier performs the same calculation using its own stored key material.
4. The calculation results from both parties are compared; if they match, authentication is successful; otherwise, the connection is closed.

Key security attributes:

- The actual key material was never transmitted over the channel.
- Only random numbers and calculation results are transmitted over the channel.
- Even if an attacker captures the complete authentication process data packet, they cannot deduce the key material.
- Each authentication uses a new random number to prevent replay attacks.

### 5.3 Security Hardware Isolation

Key storage and cryptographic computation are performed in secure hardware (Secure Element / Hardware Security Module).

Security attributes of security hardware:

- **Isolated execution:** Encrypted computation is performed internally within secure hardware, and the main CPU cannot read the internal state or intermediate results.
- **Key protection:** The key is stored in the non-volatile memory of secure hardware, which is inaccessible from the external bus.
- **Physical tamper protection:** Secure hardware has a physical protection layer.
- **Protection against side-channel attacks:** The encryption operations of secure hardware are designed to execute in a constant-time manner.

Application layer software only calls the security hardware interface and does not access the key itself.

### 5.4 Authentication Mode

Typical system designs define multiple authentication modes based on business scenarios:

**Standard authentication mode:** Verifies identity only, without altering any stored content. Suitable for everyday use.

**Establishment Mode:** Used for establishing a trust relationship for the first time. After successful authentication, the verified party writes the key material, and the state changes from unestablished to established.

**Forced Mode:** Used in special cases (such as when the peer module is replaced, resulting in the loss of the original key information). Forces the overwriting of the new key. If the process fails midway, the original key materials must be retained.

<a id="chapter6-command"></a>

## VI. Command Interaction (Command / Response / TLV / CRC16)

### 6.1 Request-Response Model

After authentication is successful, both parties enter the instruction exchange phase.

The command interaction adopts **a request-response** model:

- The requester sends instructions
- The responder executes the instruction and returns the result.
- Each request must correspond to a response.

If the requester does not receive a response within a preset time, a timeout will be processed.

### 6.2 Application Layer Protocol Framework

On top of the general data channels provided by GATT, the application layer can define its own protocol framework to organize data.

A typical custom protocol framework includes:

- **Frame structure:** includes frame start flag, length field, control field, sequence number field, and payload.
- **Control fields:** include packet identifier, synchronous/asynchronous mode flag, encryption flag, and direction flag.
- **Payload format:** Data is organized using TLV (Tag-Length-Value) format.

Key design considerations for frame structure:

- **Packet segmentation** is used to support large message splitting: when the message length exceeds the capacity of a single frame, it is split into a start packet, an intermediate packet, and an end packet.
- **The sequence number field** is used by the receiver to reassemble the fragments in the correct order.
- In **synchronous mode** , the receiver must return a response immediately; in **asynchronous mode** , the receiver can reply with an acknowledgment first, and then send the execution result separately later.
- **The encryption flag** controls whether the payload is encrypted using the application-layer session key.

### 6.3 TLV Format and CRC Check

Load TLV format:

- **Tag:** Identifies data type
- **Length:** The number of bytes in the value.
- **Value:** Specific data

Multiple TLV units can be spliced ​​together in the same load.

The advantages of TLV format:

- **Extensible:** Adding new data types only requires defining a new Tag.
- **Self-description:** The recipient can identify the meaning of the data through the tag.
- **Flexible:** The arrangement order of different TLV units is not restricted.

A typical design adds a check field to the end of the frame and performs CRC16 check (CCITT standard polynomial) on the frame header and payload.

After receiving a frame, the receiver first calculates the CRC16 of the frame header and payload and compares it with the checksum field in the frame. If they do not match, it is determined to be a transmission error, and the frame is discarded.

CRC16 can detect single-bit errors and most burst errors.

<a id="chapter7-security"></a>

## VII. Security Mechanisms (RPA / Replay Attack / Whitelist / IRK / CSRK)

### 7.1 RPA Address Update Mechanism

The generation and resolution of resolvable random private addresses (RPAs) are based on IRK.

RPA generation logic:

- prand is a 24-bit field: the lower 22 bits are random numbers, and the highest 2 bits are address type flags.
- Using the ah() function (based on the AES-CMAC-128 algorithm), with IRK as the key, prand is calculated.
- Take the first 24 bits of the calculation result as the hash value.
- RPA = 24-bit hash + 24-bit prand, totaling 48 bits.

RPA parsing logic:

- Extract prand (24-bit) from RPA
- Calculate the expected hash value using the same ah() function.
- If the expected hash value matches the hash value in the RPA, the parsing is successful.

Only devices with the correct IRK can resolve RPA to their true identity.

### 7.2 Prevention of replay attacks

The basic principle of **a replay attack** is that the attacker records the command signals sent by the legitimate device and then retransmits the recorded signals after the legitimate device leaves.

In a typical design, each critical instruction carries a strictly incrementing sequence number. The receiver maintains the last received sequence number:

- The sequence number is incremented by 1 each time the sending end sends a command.
- After receiving the instruction, the receiving end checks the sequence number: if the sequence number is less than or equal to the last received sequence number, it is determined to be a replay attack, and the instruction is discarded.
- The sequence number is reset at the start of each connection.

### 7.3 Whitelist Filtering

A whitelist is a list of authenticated devices maintained by the authenticator, storing the identity identifiers of all devices with whom a trust relationship has been established.

The whitelist can be effective at both the data link layer and the application layer:

- Link layer: Scanning and filtering only responds to broadcasts from device addresses within the whitelist.
- Application layer: Devices not on the whitelist during the authentication phase are directly rejected.

Whitelist management: Add devices to the whitelist in creation mode; remove devices from the whitelist when deleting them through the management terminal.

<a id="chapter8-power-fault"></a>

## 8. Power Consumption and Fault Tolerance (Dynamic Interval / OTA A/B Partition)

### 8.1 Dynamic Adjustment of Broadcast Intervals

The broadcast interval can be automatically adjusted according to the equipment status:

- Normal broadcast state: Use the preset interval corresponding to the current stage.
- Low battery state: Automatically extends the interval to a longer time to prolong battery life.
- Transitional state: Use shorter intervals to ensure successful connection establishment.

The adjustment is automatically completed by the link layer based on instructions from the upper layer.

### 8.2 Dynamic adjustment of connection interval

The connection interval is dynamically adjusted based on data activity during the connected state:

- Use short intervals when there is frequent data exchange to ensure throughput and response speed.
- Gradually increase the interval when there is no data exchange for a long time to reduce power consumption.
- Actively disconnect after exceeding the idle threshold

Connection interval updates can be performed through the link layer or the L2CAP layer, depending on the Bluetooth version.

### 8.3 Multi-level power management

Typical system designs implement multi-level power management strategies, using different power parameters in different states:

- Normal operation: Using default parameters
- Short idle time: extending the broadcast interval or connection interval
- Long period of inactivity: Actively disconnect.
- Low battery: Force an extended broadcast interval and disable unnecessary functions.

Automatic switching between levels is achieved through timers or external conditions.

### 8.4 Connection Timeout and Loss Handling

The link layer maintains a connection timeout timer. If no data packets are received within the timeout period, the link layer determines that the connection has been lost, exits the connection state, and returns to standby.

After the connection is lost, the device re-enters broadcast mode.

### 8.5 Firmware Upgrade and Fault Tolerance

Firmware upgrades utilize an A/B dual-partition design, also known as **a Ping-pong update** . The device has two independent storage partitions:

- **Area A:** Current running version
- **Area B:** Spare Partition

Upgrade process:

1. The new firmware is transmitted to the device in packets via wireless connection.
2. Receive and write to area B, and verify each packet.
3. After receiving the complete firmware, perform an overall integrity check.
4. After successful verification, switch the startup flag to area B.
5. Device reset, boot from area B to run new firmware.

Fault tolerance guarantees during the upgrade process:

- If the upgrade process fails at any stage, the system will automatically revert to the original version in Region A.
- The original version is intact, and the device continues to work normally.

The core advantage of this design is that "upgrades are uninterrupted and failures can be rolled back".

<a id="chapter-conclusion"></a>

## Conclusion

From broadcast discovery to connection establishment, from link encryption to application authentication, from command interaction to power management, this system is designed around two core objectives:

**Energy saving** – the device is powered by a battery. Hibernation mechanisms, dynamic broadcast intervals, dynamic connection intervals, and multi-level power management all minimize power consumption.

**Security** —preventing outsiders from impersonating, eavesdropping, or replaying. LTK link encryption, application-layer challenge-response authentication, sequence number anti-replay, RPA anti-tracking, whitelist filtering, and secure hardware isolation constitute a multi-layered defense.

These eight parts constitute the complete communication framework: **Sleep → Wake up → Broadcast → Scan → Connect → Link encryption → Application authentication → Command interaction → Disconnect → Return to low power.**

<a id="chapter-appendix"></a>

## appendix

### Appendix A: Bluetooth Broadcast Data Format Reference

Broadcast data consists of one or more AD Structures.

**AD Structure format:**

Fields | length | illustrate
:-- | :-- | :--
Length | 1 byte | Total length of AD Type + AD Data
AD Type | 1 byte | Data types
AD Data | Length-1 byte | Specific data

**Commonly used AD Type values:**

AD Type value | name | use
:-- | :-- | :--
0x01 | Flags | Device discovery mode, LE capability mark
0x03 | Complete List of 16-bit Service UUIDs | Complete list of 16-bit service UUIDs
0x09 | Complete Local Name | Full local name of the device
0x16 | Service Data - 16-bit UUID | Service data corresponding to 16-bit UUID
0xFF | Manufacturer Specific Data | Manufacturer-defined data

**Manufacturer Specific Data (0xFF) format:**

Fields | length | illustrate
:-- | :-- | :--
Company ID | 2 bytes | Vendor ID assigned by Bluetooth SIG
Manufacturer Data | variable | Manufacturer Customization

### Appendix B: Bluetooth ATT Protocol Reference

ATT (Attribute Protocol) PDU format:

Fields | length | illustrate
:-- | :-- | :--
Opcode | 1 byte | Operating method
Attribute Parameters | variable | Determined by Opcode
Authentication Signature | Optional | 13 bytes

**Common ATT Opcode types:**

Opcode value | name | use
:-- | :-- | :--
0x02 | Exchange MTU Request | Exchange MTU size
0x03 | Exchange MTU Response | Exchange MTU response
0x04 | Find Information Request | Information search request
0x08 | Read By Type Request | Read requests by type
0x09 | Read By Type Response | Read response by type
0x0A | Read Request | Read request
0x0B | Read Response | Read response
0x12 | Write Request | Write request
0x13 | Write Response | Write response
0x1B | Handle Value Notification | Handle value notification
0x1D | Handle Value Indication | Handle value indicator

### Appendix C: Bluetooth L2CAP and CID Reference

**Main Fixed Channel ID (CID):**

CID value | use
:-- | :--
0x0004 | ATT Protocol
0x0005 | L2CAP signaling
0x0006 | Safety Management (SM)
0x0007 | Security Management Signaling (LE)

### Appendix D: BLE Air Packet Structure Reference

**Broadcast Channel PDU Header: PDU Type**

PDU Type value | name | illustrate
:-- | :-- | :--
0x00 | ADV_IND | Connectable and scannable non-directional broadcast
0x01 | ADV_DIRECT_IND | Can connect to directional broadcast
0x02 | ADV_NONCONN_IND | Unconnectable, unscannable, non-directional broadcast
0x03 | SCAN_REQ | Scan request
0x04 | SCAN_RSP | Scan response
0x05 | CONNECT_REQ | Connection request

**Complete air interface packet format (1M PHY):**

Fields | length | illustrate
:-- | :-- | :--
Preamble | 1 byte | Preamble, used for clock synchronization at the receiver.
Access Address | 4 bytes | Broadcast packets have fixed values; the data packets are specified by CONNECT_REQ.
PDU | 2-257 bytes | Broadcast channel PDU or data channel PDU
CRC | 3 bytes | 24-bit CRC check value

---

The above formats are all publicly defined in the Bluetooth Core Specification. For details regarding field length, end order, etc., in the specific implementation, please refer to the Bluetooth Core Specification and the corresponding chip's technical manual.

---

📝 Related content is hosted on GitHub, and updates are subject to the repository.<br> 📌 Please feel free to point out any omissions or errors.<br> 🔗 GitHub repository: [kyshipit/tech-notes](https://github.com/kyshipit/tech-notes)

---
