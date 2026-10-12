**English** | [简体中文](../../iot/NFC技术原理与汽车钥匙应用.md)

<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2026 KY (kyshipit)
-->

# NFC Technology Principles and Car Key Applications: A Complete Explanation from Hardware to Protocol

## Chapter 1 Statement

This article explains the principles of NFC technology, the general hardware architecture of automotive NFC key systems, and diagnostic communication protocols. All content is based on publicly available standards (ISO 14229, ISO 15765-2, NFC Forum specifications) and general engineering knowledge. This article **does not involve any specific vehicle model, manufacturer, or non-public business details, and does not constitute product specifications or commercial disclosure** . It is for technical reference only and is provided on an "as is" basis (AS-IS).

## Chapter 2 NFC Technology Fundamentals

### 2.1 What is NFC?

NFC (Near Field Communication) is a short-range wireless communication technology that operates at a frequency of 13.56MHz and typically has a communication range of less than 10 centimeters. Compared to Bluetooth (typically within 10 meters) and Wi-Fi (typically within 100 meters), NFC's communication range is extremely short—a characteristic that is both its limitation and its security advantage.

NFC is not a new technology. Its physical layer foundation (13.56MHz RFID) was standardized as early as the 1990s. After the NFC Forum was established in 2004, it standardized the high-frequency subset of RFID, defining a more complete protocol stack and application scenarios. Currently, NFC is widely used in mobile payments, access control, public transportation, and other fields.

NFC communication speeds are typically available in three tiers: 106kbps, 212kbps, and 424kbps, with some newer standards supporting even higher speeds. For car key applications, 106kbps is usually sufficient—because the amount of data generated in each interaction is extremely small, typically only tens to hundreds of bytes, eliminating the need for high-speed transmission.

### 2.2 The Relationship Between NFC and RFID

RFID (Radio Frequency Identification) is a broader technology that encompasses all technologies that identify target objects using radio waves. RFID operates across multiple frequency bands, including low frequency (125kHz), high frequency (13.56MHz), ultra-high frequency (800-900MHz), and microwave (2.45GHz), with communication distances ranging from a few centimeters to tens of meters.

NFC is a subset of RFID, specifically referring to RFID systems that operate at a high frequency of 13.56MHz, have an extremely short communication range (within 10 cm), and support two-way interaction. Traditional RFID is typically unidirectional—the reader actively sends signals, and the tag passively responds; the tag cannot initiate communication itself. NFC, on the other hand, supports two-way communication, allowing both NFC devices to actively send data (depending on the operating mode).

Simply put: all NFC devices are RFID devices, but not all RFID devices are NFC devices. NFC = high frequency 13.56MHz + extremely short range + two-way communication capability.

### 2.3 Three Working Modes of NFC

NFC devices can operate in three different modes, each corresponding to a different application scenario:

**Reader/Writer Mode**

Reader mode is the most basic operating mode of NFC. The device actively transmits a 13.56MHz carrier signal to generate a radio frequency field, reading or writing data from passive tags (such as NFC cards or NFC tag stickers). In this mode, the reader is an active device (powered by a battery), and the tag is a passive device (relying on the electromagnetic field of the reader to obtain operating power).

The card reader sends a command frame, which the tag receives, parses, performs an operation (reading or writing data), and then sends the response data back to the card reader via load modulation. The entire process is led by the card reader, with the tag only responding passively.

Typical applications: checking bus card balance on mobile phone, reading bank card information on POS machine.

**Card Emulation Mode**

Card emulation mode is the opposite: the device emulates itself as a card (or tag) and waits for an external card reader to read it. In this mode, the device is passive—it does not actively emit signals and answers whatever the card reader asks.

Card emulation modes are divided into two types: Host Card Emulation (HCE) and Secure Element-based card emulation. HCE is a software solution introduced in Android 4.4, which processes NFC data in user space. It has lower security but is more flexible to implement. The Secure Element-based solution stores the key in separate hardware, which is more secure.

Typical applications: using mobile phones to access control systems and subway turnstiles.

**Peer-to-Peer Mode**

In peer-to-peer mode, both NFC devices are active and can transmit data bidirectionally. The two devices negotiate their communication roles after being brought close together, and then send data to each other.

Peer-to-peer mode was originally used for "tap-to-transfer contacts" and "tap-to-transfer photos" between Android phones. However, NFC's data transfer rate is only up to 424kbps, which is too slow for transferring large files, so it was later replaced by Bluetooth and Wi-Fi Direct. Now, peer-to-peer mode is mainly used for "tap-to-pair"—two devices tap each other, NFC exchanges Bluetooth or Wi-Fi pairing information, then the NFC connection is disconnected, and subsequent large data transfers are completed via Bluetooth or Wi-Fi.

### 2.4 NFC Physical Layer Communication Principle

**2.4.1 Electromagnetic Induction and 13.56MHz Carrier**

The physical basis of NFC communication is electromagnetic induction. The reader has an antenna coil, which generates a magnetic field when energized. This magnetic field is not static, but changes rapidly at a frequency of 13.56 MHz – this is the "carrier wave".

Faraday's law of electromagnetic induction tells us that a changing magnetic field will induce an electromotive force in a nearby conductor coil. When a card is brought close to a card reader, the card's antenna coil is placed in the alternating magnetic field generated by the reader, and an induced voltage appears across the coil. This induced voltage is then processed by the card's internal rectification and voltage regulation circuitry to provide power to the card's chip.

The coupling between the card reader and the card is essentially a loosely coupled air-core transformer. The primary coil is on the reader side, and the secondary coil is on the card side. The coupling coefficient depends on the distance between them and their relative orientation—the communication distance requirement of less than 10 centimeters is precisely to ensure a sufficient coupling coefficient so that the card can obtain enough induced voltage.

**2.4.2 Power Supply Mechanism for Passive Devices**

NFC cards do not have batteries; their power comes entirely from the radio frequency field emitted by the reader. The AC voltage induced by the card's antenna coil is rectified into DC by a rectifier bridge, then stabilized by a voltage regulator circuit to the chip's operating voltage (usually 1.8V or 3.3V), which then powers the card's digital circuitry and memory.

The NFC Forum specification requires that card readers provide sufficient radio frequency field strength to ensure that passive devices can reliably draw power from a magnetic field strength of at least 1.5 A/m within a communication distance of 10 cm. Actual chip sensitivity is usually better than this requirement, but the antenna size and coil turns determine the actual induced voltage—the size of a mobile phone's NFC antenna is limited, and its power-drawing capability is not as good as a dedicated card. Therefore, some operations of the mobile phone in card emulation mode still require battery assistance.

**2.4.3 Load Modulation and Data Backhaul**

Passive devices cannot actively transmit radio frequency signals—they lack their own radio frequency transmitter, and even a weak current is insufficient to drive signal transmission. So how does the card send data back to the card reader? The answer is load modulation.

The card has a load resistor, which is controlled by a switch to be connected to the antenna circuit. When the switch is closed, the additional resistor is connected to the antenna circuit, changing the total impedance of the antenna; when the switch is open, the impedance returns to normal. This impedance change alters the amplitude of the reader's antenna current—the reader detects these minute current fluctuations, demodulates them, and recovers the data transmitted by the card.

The card modulates its data onto the reader's carrier wave by controlling the on/off rhythm of the switch (on/off corresponds to 0/1 in binary data). The energy source for this data transmission is still the field transmitted by the reader; the card merely changes the load characteristics of this field, rather than generating its own signal to transmit.

### 2.5 NFC Protocol Stack Layers

The NFC protocol stack can be roughly divided into the following layers from the physical layer to the application layer:

- **Physical layer** : 13.56MHz carrier, ASK modulation, Manchester coding or improved Miller coding, defining the modulation method, coding method and data rate of the radio frequency signal.
- **Link layer** : Responsible for frame format definition, collision detection and handling, flow control and error detection.
- **LLCP** : Logical Link Control Protocol defined by the NFC Forum, responsible for connection management, data exchange, and service discovery.
- **NDEF** : A data exchange format defined by the NFC Forum, consisting of multiple records, each containing type, length, and payload.
- **SNEP** : An application layer protocol used for exchanging NDEF messages between two NFC devices.

In automotive NFC key systems, not all scenarios fully implement the protocol stack defined by the NFC Forum. Some implementations directly run custom data formats based on the physical and data link layers—automotive key interactions involve small amounts of data, high security requirements, and fixed interaction processes, making streamlined custom protocols more controllable and lightweight than the complete protocol stack.

## Chapter 3 Hardware Architecture of Car NFC Key System

### 3.1 Overall Topology

In a vehicle equipped with an NFC digital key, the NFC subsystem is positioned as follows within the overall vehicle network: the NFC module is connected to the CAN bus as an independent ECU node, communicating with nodes such as the body domain controller, door lock controller, and PEPS (Passive Entry/Passive Start) system.

The core hardware components inside the NFC module include: NFC antenna (usually installed inside the door handle, B-pillar, or center console), NFC radio frequency controller chip (responsible for physical layer signal modulation and demodulation), main control MCU (responsible for protocol stack and application logic), hardware security module (HSM, responsible for key storage and encryption operations), and CAN transceiver (responsible for CAN bus physical signal conversion).

The NFC module works as follows: When a user brings an NFC card or mobile phone close to the car door antenna, the radio frequency controller detects the change in field strength and wakes up the main control MCU; the MCU reads the card data through the radio frequency controller and calls the HSM for encryption authentication; after successful authentication, the MCU sends an unlock command to the body domain controller through the CAN bus; the body domain controller then executes the door lock action.

### 3.2 NFC Antenna and RF Controller

An NFC antenna is a coil wound on a ferrite sheet. The antenna's inductance, Q-factor (quality factor), and resonant frequency determine its radiation efficiency and communication range. The antenna and matching capacitor together form an LC resonant circuit, and the resonant frequency must be precisely tuned to 13.56MHz.

Key parameters for antenna design include:

parameter | illustrate
:-- | :--
Inductance | To determine the resonant frequency, an external capacitor is needed to adjust it to 13.56MHz.
Q value | A high Q value affects bandwidth and radiation efficiency, and is sensitive to temperature changes and surrounding metals.
Field strength distribution | The size and directionality of the effective communication area are affected.
Antenna impedance | It needs to be matched with the output impedance of the RF controller to achieve maximum power transfer.

In automotive environments, NFC antennas are typically mounted inside metal door handles, surrounded by metal and plastic structures. The metal provides shielding and eddy current loss to the 13.56MHz magnetic field, significantly impacting the antenna's radiation efficiency. Therefore, it's common practice to install a ferrite sheet on the back of the antenna to isolate the magnetic field from the metal structure, and to optimize the antenna layout using finite element simulation software.

The radio frequency (RF) controller is a chip responsible for physical layer and some link layer functions. Its work includes:

- Generates a 13.56MHz carrier signal
- Data is transmitted via modulated carrier (ASK modulation).
- Demodulation load modulation signal received data
- The detection card is brought close (by field strength or phase change).
- Handling multi-card collisions (arbitration when multiple cards are close together simultaneously)
- Control the transmit power (adjust the radio frequency output strength)
- Supports low-power card detection mode (extremely low-power monitoring when the vehicle is in sleep mode).

The controller and the main MCU are typically connected via an SPI or I2C interface. The MCU sends commands to the controller through this interface (such as "start RF field", "send data frame", "read received data"), and the controller reports RF layer events (such as "card enters field area" and "data frame reception completed") to the MCU.

### 3.3 Main Control MCU

The main control MCU is the "brain" of the NFC module. It runs an embedded real-time operating system and is responsible for task scheduling, interrupt management, peripheral drivers, and protocol stack processing.

The core responsibilities of an MCU:

- UDS Diagnostic Protocol Processing: Receives and parses diagnostic requests from the CAN bus, calls the corresponding service processing function, constructs and sends a diagnostic response.
- NFC State Machine Management: Manages the configuration and operational states of the NFC module.
- RF controller driver: Interacts with the RF controller via SPI/I2C interface to send and receive NFC data.
- HSM Scheduling: Forwards encryption operation requests to the HSM and retrieves the operation results.
- CAN Communication Management: Communicates with the vehicle network via a CAN transceiver to send commands and report status.
- Power management: Manages the power modes (run/sleep/wake-up) of the module and monitors the power status.
- Diagnostic data storage: Manages configuration and diagnostic information stored in Flash/EEPROM.

Automotive-grade MCUs generally employ a multi-core architecture, with different cores working collaboratively: one core is responsible for application logic, protocol stack, and state machine management, while the other core is responsible for security-related key storage, encryption operations, and physical attack protection. The two cores exchange data through shared memory and inter-core interrupts, and the application core cannot directly access the private storage area of ​​the security core.

### 3.4 Hardware Security Module (HSM)

HSM (Hardware Security Module) is an independent security subsystem integrated within the main control MCU. It is not a software-level security isolation, but a hardware-level isolation—it has its own CPU, memory area, clock domain, and power domain.

The core feature of HSM is physical isolation. The main CPU (the core that runs application logic) cannot directly read the storage contents inside the HSM. The interaction between the main CPU and HSM is a "request-response" model—the main CPU sends a computation request to the HSM, the HSM completes the calculation internally and returns the result, and the main CPU does not participate in the calculation process or access intermediate data.

**Main functions of HSM:**

Function | illustrate
:-- | :--
Secure key storage | The root key is stored in HSM's dedicated secure Flash memory, which the main CPU cannot access in any way.
Accelerating encryption operations | Integrated hardware encryption engine, supporting algorithms such as AES, RSA, and ECC.
Safe Boot | Verify firmware digital signature upon power-on to prevent malicious code from running.
Physical attack protection | Voltage/temperature/frequency anomaly detection, metal protective layer, photosensitive detection, etc.

**Communication mechanism between main CPU and HSM:**

The main CPU sends commands to the HSM via a dedicated hardware communication channel (such as a mailbox mechanism or shared registers). Each command includes an opcode, parameters, and the length of the data. Upon receiving the command, the HSM parses and executes it. After execution, it notifies the main CPU via an interrupt or status register and writes the result to the shared area.

Communication protocols typically include the following security measures:

- The command format is fixed, and illegal commands are rejected.
- Access permission checks (some commands require specific permission levels)
- Timestamps or counters to prevent replay attacks
- Communication integrity verification (such as CRC or MAC)

### 3.5 CAN Bus Transceiver

The CAN bus transceiver is an interface chip between the MCU and the CAN physical bus. Its functions are: to convert the TX digital signal (TTL/CMOS level) sent by the MCU into a differential signal (the voltage difference between CAN_H and CAN_L) and send it to the bus; and to receive the differential signal on the bus and convert it into an RX digital signal for the MCU.

The transceiver also has the following characteristics:

characteristic | illustrate
:-- | :--
Bus protection | Prevent damage from short circuits and overvoltage
Common-mode suppression | Suppress common-mode interference and enhance noise immunity
Standby mode | Maintain bus wake-up capability in low power mode
Wake-up remote | Wake up the MCU after detecting bus activity

Automotive-grade CAN transceivers typically conform to the ISO 11898-2 standard and support classic CAN (up to 1 Mbps) or CAN FD (up to 5 Mbps). The transceivers generally operate within a temperature range of -40°C to 125°C, meeting automotive environmental requirements.

The NFC module connects to the vehicle's CAN bus network via a CAN transceiver, communicating with nodes such as the body domain controller, BCM, and PEPS. The NFC module is an independent node on the bus, possessing a unique node address and message filtering configuration.

## Chapter 4 Fundamentals of Automotive Diagnostic Communication Protocols

### 4.1 Overview of UDS Diagnostic Protocol

**4.1.1 What is UDS?**

UDS (Unified Diagnostic Services) is a set of automotive diagnostic communication protocols defined by the ISO 14229 standard. It specifies the communication rules between the diagnostic tool (typically production line equipment or aftermarket diagnostic tools) and the ECU—including request format, response format, service ID definition, parameter encoding, execution flow, and error handling.

UDS's "unification" is reflected in two aspects:

- **Unified service** : All ECUs support the same service ID, eliminating the need for diagnostic tools to write different protocol codes for different ECUs.
- **Unified Interface** : UDS defines a consistent application-layer interface, allowing diagnostic tools to access different ECUs using the same process.

UDS is a protocol layer independent of the physical transmission medium. It does not care whether the data is transmitted via CAN bus, LIN bus, FlexRay or Ethernet. The application layer of UDS is defined in ISO 14229-1, and the rules for the transport layer to adapt to the specific bus are defined in the corresponding protocol (CAN corresponds to ISO 15765-2, Ethernet corresponds to ISO 13400, etc.).

**4.1.2 Request/Response Model**

UDS uses a client-server model, and communication is always initiated by the client (diagnostic instrument):

1. The diagnostic tool sends a request message containing the service ID and parameters.
2. After receiving the request, the ECU will perform the corresponding operation.
3. The ECU returns a response message containing the execution result.

**A positive response** : Returned after the ECU successfully executes the request. The response code is the requested service ID + 0x40. For example, if the request is 0x10, the positive response is 0x50.

**Negative Response** : Returned when the ECU cannot execute the request. The response format is 0x7F + original service ID + negative response code (NRC). Common NRCs include:

NRC | meaning
:-- | :--
0x10 | General Refusal
0x11 | Service not supported
0x12 | Sub-function not supported
0x13 | Message length error
0x22 | Conditions not met
0x31 | Request out of scope
0x33 | Secure access denied
0x35 | Invalid key
0x36 | More than the number of attempts
0x37 | Waiting time not yet
0x78 | Response pending

### 4.2 ISO 15765-2 Network Layer Protocol

**4.2.1 Why is a transport layer needed?**

The data field of a classic CAN data frame is at most 8 bytes. UDS diagnostic requests and responses often exceed 8 bytes—for example, reading a DID may return tens of bytes of data, and writing certain data may carry a dozen or even more bytes.

ISO 15765-2 defines how to transmit data of indeterminate length over a CAN bus. It adds a network layer between the UDS application layer and the CAN data link layer, responsible for:

Function | illustrate
:-- | :--
Subcontracting | The long data transmitted from the application layer is split into multiple CAN frames and sent.
Package | The received multiple CAN frames are reassembled into complete data and delivered to the application layer.
flow control | The receiver controls the sender's transmission rhythm to avoid receive buffer overflow.
Error handling | Detect errors during transmission (such as frame loss or out-of-order frames).

ISO 15765-2 is a connectionless, unacknowledged transport layer protocol. "Unacknowledged" means the protocol itself does not provide an end-to-end acknowledgment mechanism—after the sender transmits data, the protocol layer is not responsible for confirming that the recipient has received all the data. The responsibility for acknowledgment lies with the application layer (UDS layer), where a positive response from the UDS is an acknowledgment that "data has been received and processed."

**4.2.2 Four Frame Types**

ISO 15765-2 defines four frame types, distinguished by the high four bits of the first byte of N_PDU (N_PCItype):

Frame type | N_PCItype value | use
:-- | :-- | :--
Single frame (SF) | 0 | Used when data length is ≤7 bytes, completed in one frame.
First frame (FF) | 1 | The first frame of a long data transmission declares the total length.
Continuous Frames (CF) | 2 | Data frames following the first frame include a sequence number (SN).
Flow control frame (FC) | 3 | The receiver sends data, controlling the sender's sending rhythm.

Single frame: Used when the total length of the data does not exceed 7 bytes. One CAN frame contains all the data.

First frame: When the total data length exceeds 7 bytes, the first frame is the first frame, used to declare the total length of the data transmitted. The receiver prepares a buffer based on the total length, waiting for subsequent consecutive frames.

Consecutive frames: Data frames following the first frame are all consecutive frames. Consecutive frames are numbered sequentially (SNs start from 0 and increment), and the receiver assembles the data based on the SNs. If a skipped SN is detected, the receiver discards the entire multi-frame message.

Flow control frame: After receiving the first frame, the receiver sends a flow control frame to the sender to control the sender's transmission rhythm through the BS and STmin parameters.

**4.2.3 Flow control parameters BS and STmin**

parameter | Full name | meaning
:-- | :-- | :--
BS | Block Size | The sender pauses and waits for flow control frames after sending N consecutive frames; 0 indicates that no further waiting is needed.
STmin | Separation Time Minimum | Minimum interval time between two consecutive frames
FS | Flow Status | Stream status: 0 = Continue sending, 1 = Wait, 2 = Overflow

The value of BS can be 0x00-0xFF:

- 0x00: The sender transmits all consecutive frames at once, without requiring additional flow control frames.
- 0x01-0xFF: The sender pauses after sending N consecutive frames, waiting for the receiver to send new flow control frames.

The value of STmin can be:

- 0x00-0x7F: Absolute time, in milliseconds (ms)
- 0xF1-0xF9: Microsecond values ​​(0xF1=100μs, 0xF9=900μs)

The value of FS:

- 0 (CTS): Continue sending
- 1 (WT): Wait, sender pauses
- 2 (OVFLW): Overflow, sender aborts.

### 4.3 Introduction to Commonly Used UDS Services

The following service descriptions are based on the ISO 14229 standard and do not involve specific business scenarios.

**4.3.1 Diagnostic Session Control (0x10)**

The 0x10 service is used to switch the diagnostic session mode of the ECU. The diagnostic session determines which diagnostic services the ECU exposes to the outside world.

Sub-function | Session mode | illustrate
:-- | :-- | :--
0x01 | Default Session | In normal operating mode, only basic diagnostic services are available.
0x03 | Extended Session | Open up more diagnostic services
0x04 | Programming Session | Open bootloader and Flash programming services

Request format: 0x10 + sub-function number. Upon receiving the request, the ECU switches session modes and returns a positive response: 0x50 + sub-function number + optional parameters. The ECU can only be in one diagnostic session mode at a time; it defaults to the default session after power-on or reset.

**4.3.2 Reading data by ID (0x22)**

The 0x22 service is used to read data inside the ECU via DID. DID is a 2-byte identifier (0x0000-0xFFFF), and each DID corresponds to a specific data object inside the ECU—which may be a configuration value, a status register, the contents of a storage area, or a calculation result.

Request format: 0x22 + DID_High + DID_Low. Positive response format: 0x62 + DID_High + DID_Low + data. Negative response format: 0x7F + 0x22 + NRC.

**4.3.3 Writing data by ID (0x2E)**

The 0x2E service is used to write data to the ECU via DID.

Request format: 0x2E + DID_High + DID_Low + data to be written. Positive response format: 0x6E + DID_High + DID_Low. Negative response format: 0x7F + 0x2E + NRC.

Write operations typically require the ECU to be in extended session or programming session mode, and some sensitive DIDs require secure access authentication first.

**4.3.4 Secure Access (0x27)**

The 0x27 Secure Access Service implements a Challenge-Response authentication mechanism.

operate | Sub-function type | illustrate
:-- | :-- | :--
Request seed | Odd numbers (0x01/0x03/0x05...) | The diagnostic tool requests a seed, and the ECU returns a random number.
Send key | Even number (0x02/0x04/0x06...) | The diagnostic tool sends a key, which is then verified by the ECU.

Sub-function numbers are used in pairs: 0x01/0x02 is one pair, 0x03/0x04 is one pair, and 0x05/0x06 is one pair. Different pairs can represent different security levels or different access permissions.

Authentication process:

1. The diagnostic tool sends a seed request with 0x27 + odd sub-function number.
2. The ECU generates a random number seed (usually 4 or 8 bytes) and returns 0x67 + sub-function number + seed.
3. The diagnostic instrument calculates the key using its internal algorithm and sends 0x27 + an even-numbered sub-function number + the key.
4. The ECU verifies the key; a successful verification returns 0x67 + an even-numbered sub-function number, while a negative response is returned upon failure.

A negative response code of 0x35 indicates an invalid key, 0x33 indicates secure access denied, 0x36 indicates the number of attempts exceeded, and 0x37 indicates the waiting time has not elapsed.

**4.3.5 Routine Control (0x31)**

The 0x31 Routine Control Service is used to start, stop, and query predefined routines within the ECU. A routine is not a simple read/write operation, but a process that needs to be executed—it may involve multiple steps, may take a long time, and may generate intermediate states.

RID (Routine Identifier) ​​is a 2-byte routine identifier, and each RID corresponds to a specific function routine inside the ECU.

Sub-function | operate | Request format | Response format
:-- | :-- | :-- | :--
0x01 | Startup routine | 0x31 0x01 + RID + Parameters | 0x71 0x01 + RID + Status
0x02 | Stop routine | 0x31 0x02 + RID + Parameters | 0x71 0x02 + RID + Status
0x03 | Request result | 0x31 0x03 + RID | 0x71 0x03 + RID + Result

Routine control is suitable for any internal operation that needs to be executed asynchronously or requires polling progress. After starting the routine, progress is polled via 0x03, and stopped via 0x02 upon completion.

**4.3.6 Clear diagnostic information (0x14)**

Service 0x14 is used to clear fault codes stored in the ECU. The request carries the clearing range and grouping parameters. Upon receiving the request, the ECU clears the fault code records that match the criteria and returns a positive response of 0x54.

## Chapter 5 Diagnostic Protocol Format Analysis

### 5.1 ISO 15765-2 frame format

**5.1.1 Single Frame (SF) Format**

Use a single frame when the total length of the data does not exceed 7 bytes.

Byte position | content | bit7-4 | bit3-0
:-- | :-- | :-- | :--
N_PCI bytes 0 | Frame type + data length | 0000 | SF_DL (1-7)
N_PCI bytes 1~N | Valid data | — | —

SF_DL indicates the number of valid data bytes carried in this frame. For example, if the first byte is 0x03, it means that this frame carries 3 bytes of valid data.

**5.1.2 First Frame (FF) Format**

When the total length of the data exceeds 7 bytes, the first frame is the first frame.

Byte position | content | bit7-4 | bit3-0
:-- | :-- | :-- | :--
N_PCI bytes 0 | Frame type + total length (high 4 bits) | 0001 | FF_DL[11:8]
N_PCI bytes 1 | The lower 8 bits of the total length | FF_DL[7:0] | —
N_PCI bytes 2~N | Partial valid data | — | —

Total length FF_DL = (lower 4 bits of byte 0 &lt;&lt; 8) + byte 1, ranging from 1 to 4095 bytes. The first frame carries a maximum of 6 bytes of valid data (8-byte CAN frame minus 2 bytes N_PCI).

**5.1.3 Continuous Frame (CF) Format**

The data frames following the first frame are consecutive frames.

Byte position | content | bit7-4 | bit3-0
:-- | :-- | :-- | :--
N_PCI bytes 0 | Frame type + sequence number | 0010 | SN (0-15)
N_PCI bytes 1~N | Valid data | — | —

The serial number (SN) starts at 0 and increments by 1 with each frame sent, returning to 0 after reaching 15. The receiver checks the continuity of the SN; if it finds a skipped number, it discards the entire multi-frame message.

**5.1.4 Flow Control Frame (FC) Format**

After receiving the first frame, the receiver sends a flow control frame to the sender.

Byte position | content | bit7-4 | bit3-0
:-- | :-- | :-- | :--
N_PCI bytes 0 | Frame type + Stream status | 0011 | FS
N_PCI bytes 1 | block size | BS | —
N_PCI bytes 2 | Minimum Interval Time | STmin | —

FS stream status values: 0 = Continue sending (CTS), 1 = Wait (WT), 2 = Overflow (OVFLW).

### 5.2 Secure Access Protocol Format (0x27)

**5.2.1 Request seed format**

direction | Format | illustrate
:-- | :-- | :--
ask | 0x27 + odd sub-function number | Sub-function numbers are 0x01/0x03/0x05...
A positive response | 0x67 + sub-function number + seed data | Seeds are typically 4 or 8 bytes.
negative response | 0x7F 0x27 + NRC | NRC such as 0x33/0x36/0x37

**5.2.2 Sending Key Format**

direction | Format | illustrate
:-- | :-- | :--
ask | 0x27 + even-numbered sub-function number + key data | Sub-function numbers are 0x02/0x04/0x06...
A positive response | 0x67 + even-numbered sub-function number | Verification passed
negative response | 0x7F 0x27 + NRC | NRC=0x35 indicates that the key is invalid.

**5.2.3 Explanation of Negative Response Codes**

NRC | meaning
:-- | :--
0x33 | Security access denied (session mode mismatch or locked)
0x35 | Invalid key (calculated value does not match expected value)
0x36 | The number of attempts has exceeded the limit (the account is locked due to exceeding the failure limit).
0x37 | The waiting time has not expired (the lockout delay timer has not expired).

### 5.3 Routine Control Protocol Format (0x31)

**5.3.1 Startup routine (0x01)**

direction | Format | illustrate
:-- | :-- | :--
ask | 0x31 0x01 + RID (2 bytes) + Optional parameters | RID range 0x0000-0xFFFF
A positive response | 0x71 0x01 + RID + Status Information | Status flags indicate startup result
negative response | 0x7F 0x31 + NRC | —

**5.3.2 Request Result (0x03)**

direction | Format | illustrate
:-- | :-- | :--
ask | 0x31 0x03 + RID (2 bytes) | —
A positive response | 0x71 0x03 + RID + Status/Result Data | Includes progress percentage/execution status/result
negative response | 0x7F 0x31 + NRC | —

This sub-function is often used to poll the execution progress of time-consuming operations.

**5.3.3 Stop routine (0x02)**

direction | Format | illustrate
:-- | :-- | :--
ask | 0x31 0x02 + RID (2 bytes) + Optional parameters | —
A positive response | 0x71 0x02 + RID + Stopped State | Final state flag at stop
negative response | 0x7F 0x31 + NRC | —

## Chapter 6 NFC Security Mechanism Principles

### 6.1 Physical security of short-range communication

NFC communication has an extremely short range (within 10 centimeters), which provides the first line of defense at the physical level. For an attacker to intercept NFC communication signals, they must place the eavesdropping device within 10 centimeters—a distance that is extremely difficult to conceal physically.

Compared to Bluetooth (10-100 meters) and Wi-Fi (hundreds of meters), NFC's communication distance is 1-3 orders of magnitude shorter. Attackers using long-range wireless communication can intercept signals from tens of meters away with high-gain antennas, while NFC's 13.56MHz near-field coupling signal attenuates extremely quickly—the field strength is inversely proportional to the cube of the distance, and the signal strength at 10 centimeters away has already attenuated to a level that cannot be effectively demodulated.

NFC's extremely short communication distance makes man-in-the-middle attacks virtually impossible: an attacker would have to be close to both the reader and the card at the same time and maintain two valid links, which is physically impossible.

### 6.2 Random Seed and Challenge-Response Authentication Principles

The Challenge-Response authentication mechanism is the core of NFC secure access. Its basic logic is:

1. The verifier generates a random number seed (Challenge) and sends it to the verifier.
2. The party being verified uses its own key and the received seed to calculate the response value using a specific algorithm and sends it back to the verifier.
3. The verifier calculates the expected value using the same algorithm, the same seed, and its own stored copy of the key, and compares it with the received response value.
4. If the match is found, authentication is successful; otherwise, it is rejected.

**Why is this mechanism secure?**

Safety features | illustrate
:-- | :--
Each Challenge is different | The random number seed is regenerated for each request, and the intercepted response is invalid for subsequent requests.
The key is not transmitted on the link. | Only the seed and computation result are transmitted over the communication link; the key itself does not appear.
Unable to reverse the key | Even if an attacker obtains the Challenge and Response, they will not be able to deduce the key.
Anti-replay attack | The old and new challenges are different; the old response cannot be used for the new challenge.

### 6.3 Isolation and Protection Principle of Hardware Security Module (HSM)

HSM's hardware isolation provides stronger protection than pure software security solutions:

Protection mechanism | illustrate
:-- | :--
Key storage isolation | The key is stored in HSM's dedicated secure Flash memory, which is inaccessible from the main CPU address space.
Key operation isolation | The encryption operation is performed internally by the HSM; the main CPU only retrieves the result and does not access the key.
The key is never exported. | There is no "export key" interface; once the key is written, it never leaves the HSM.
Physical attack protection | Metal protective layer, active shielding layer, voltage/temperature/frequency anomaly detection, photosensitive detector

## Chapter 7 Comparison of NFC with Other Short-Range Wireless Technologies

### 7.1 Comparison of the core features of the three technologies

parameter | NFC | Bluetooth Classic | Bluetooth Low Energy (BLE) | UWB
:-- | :-- | :-- | :-- | :--
Operating frequency | 13.56MHz | 2.4GHz | 2.4GHz | 3.1-10.6GHz
Communication distance | 0-10cm | 10-100m | 10-100m | 1-10m
Data rate | 106-424kbps | 1-3Mbps | 1-2Mbps | 6.8-27Mbps
Power consumption | Extremely low | Medium and high | Low | middle
Connection establishment time | &lt;0.1s | ~1s | &lt;0.1s | &lt;0.1s
Distance measurement accuracy | none | meter level | meter level | centimeter level

### 7.2 Applicable Scenarios

technology | Advantages | Typical scenarios
:-- | :-- | :--
NFC | Extremely short range, high security, zero power consumption for passive devices, and fast connection. | Identity verification, access control, payment, device pairing
Bluetooth | Medium range, low power consumption, and wide device compatibility | Continuous data connection, audio transmission, sensor data acquisition
UWB | High-precision ranging, anti-relay attack | High-precision positioning, safe distance measurement, and location tracking

## Chapter 8 Summary

This article systematically outlines the knowledge system of NFC from its physical principles to its application implementation, focusing on three aspects: NFC technology, the hardware architecture of automotive NFC key systems, and automotive diagnostic communication protocols.

**NFC technology** operates in the 13.56MHz frequency band, with a communication distance of less than 10 centimeters, achieving short-range wireless communication through electromagnetic induction. Three operating modes cover different application scenarios. Passive devices transmit data via load modulation, independent of their own power supply.

**At the hardware architecture level** : the core components of the automotive NFC key system include an NFC antenna and RF controller, a main control MCU, a hardware security module (HSM), and a CAN bus transceiver. The HSM provides hardware-isolated secure storage and encrypted computation capabilities, and the root key never leaves the HSM's security boundary. The NFC module communicates with the vehicle's network via the CAN bus.

**At the diagnostic communication protocol level** : UDS (ISO 14229) defines the request/response model between the diagnostic tool and the ECU. The ISO 15765-2 network layer achieves reliable transmission of long data through four frame types: single frame, first frame, consecutive frames, and flow control frames. 0x27 Secure access is achieved through a Challenge-Response mechanism for authentication, and 0x31 Routine control supports asynchronous execution of time-consuming operations.

All of the above content is based on publicly available ISO standards and general electronic engineering knowledge, and does not involve specific business implementation details.

## Appendix A: Glossary

the term | Full English name | explain
:-- | :-- | :--
NFC | Near Field Communication | 13.56MHz, short-range wireless communication technology within 10cm
RFID | Radio Frequency Identification | The general term for technologies that identify targets using radio waves
HSM | Hardware Security Module | Independent security subsystem integrated within the MCU
MCU | Microcontroller Unit | Main control processor of automotive ECU
CAN | Controller Area Network | Standard communication bus between automotive electronic control units
ECU | Electronic Control Unit | Electronic control unit in a car
UDS | Unified Diagnostic Services | Automotive diagnostic communication protocol defined by ISO 14229
DID | Data Identifier | A 2-byte number used in UDS to identify internal data of the ECU
RID | Routine Identifier | A 2-byte number used to identify a routine in UDS routine control.
SID | Service Identifier | ID used to identify service type in UDS
NRC | Negative Response Code | The code indicating the error type in the UDS negative response.
SF | Single Frame | Single-frame transmission when data does not exceed 7 bytes
FF | First Frame | The first frame of multi-frame transmission
CF | Consecutive Frame | Subsequent frames of multi-frame transmission
FC | Flow Control Frame | The receiver controls the frame rhythm of the sender.
BS | Block Size | Flow control frame parameters control the number of consecutive frames sent.
STmin | Separation Time Minimum | Flow control frame parameters control the minimum interval between consecutive frames.
Challenge-Response | — | Two-way authentication mechanism based on random numbers
