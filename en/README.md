**English** | [简体中文](../README.md)

<div align="center">

# Technical Notes

![GitHub last commit](https://img.shields.io/github/last-commit/kyshipit/tech-notes?style=flat-square)
![GitHub repo size](https://img.shields.io/github/repo-size/kyshipit/tech-notes?style=flat-square)
![GitHub](https://img.shields.io/github/license/kyshipit/tech-notes?style=flat-square)
<img src="https://komarev.com/ghpvc/?username=kyshipit&color=007ec6&style=flat-square&label=views"/>
<a href="https://github.com/kyshipit/tech-notes">
  <img src="https://img.shields.io/badge/⭐️-Give_a_Star-brightgreen?style=flat-square" alt="Give it a star"/>
</a>

<p>
  <a href="#-ai">AI</a> ·
  <a href="#-quantization">Quantization</a> ·
  <a href="#-ros2">ROS2</a> ·
  <a href="#-embedded">Embedded</a> ·
  <a href="#-iot">IoT</a> ·
  <a href="#-tools">Tools</a> ·
  <a href="#-scripts">Scripts</a> ·
  <a href="#-repos">Repos</a>
</p>

</div>

---

> [!NOTE]
> 📖 Technical notes on embedded systems, AI, robotics, IoT, and other related fields, continuously updated.

---

## ✨ Content Overview

<table align="center">
  <tr>
    <td nowrap align="center"><a href="#-ai"><b>🤖 AI</b></a></td>
    <td nowrap align="center"><a href="#-quantization"><b>🚀 Quantization</b></a></td>
    <td nowrap align="center"><a href="#-ros2"><b>🦾 ROS2</b></a></td>
    <td nowrap align="center"><a href="#-embedded"><b>🔄 Embedded</b></a></td>
  </tr>
  <tr>
    <td nowrap align="center"><a href="#-iot"><b>📡 IoT</b></a></td>
    <td nowrap align="center"><a href="#-tools"><b>🛠 Tools</b></a></td>
    <td nowrap align="center"><a href="#-scripts"><b>📜 Scripts</b></a></td>
    <td nowrap align="center"><a href="#-repos"><b>🏠 Repos</b></a></td>
  </tr>
</table>

---

<a id="-ai"></a>

## 🤖 AI

> Categories: AI End-to-End | Knowledge System | Agent Architecture

- [AI Knowledge System Construction](./ai/AI-Knowledge-System-Construction.md) `#AI #Agent #RAG #LLM #Engineering`

    > This document outlines a comprehensive knowledge system for the AI field, encompassing a complete technology stack from underlying mathematics to industrial-grade agents. It covers modules such as the "brain" (large-scale model), memory modules, planning modules, tool invocation, skills, RAG retrieval, model engineering, and agent engineering. The core focus is on building industrial-grade intelligent agents capable of solving real-world problems.

- [AI Engineering Implementation](./ai/AI-Engineering-Implementation.md) `#AI #Agent #RAG #LLM #Engineering`

    > This is a collection of technical notes related to AI engineering implementation, covering modules such as model optimization, quantization, agent architecture, skill systems, and toolchains.

<p align="right">(<a href="#technical-notes">Back to top</a>)</p>

---

<a id="-quantization"></a>

## 🚀 Quantization

> Categories: Model Conversion | Quantization Deployment | RKNN | ONNX | NPU Inference

- [RKNPU Model Quantization Deployment Principles Manual](./deploy/RKNPU-Model-Quantization-Deployment-Principles.md) `#RKNN #Quantization #ONNX #NPU #Deployment`

    > From ONNX to NPU instructions, what does the compiler do internally, how are parameters configured, and why?

- [MeloTTS RKNN Quantization Deployment Pitfalls](./deploy/MeloTTS-RKNN-Quantization-Deployment-Pitfalls.md) `#MeloTTS #RKNN #INT8Quantization #ONNX #RK3588 #NPU`

    > This document records the entire deployment process of PyTorch → ONNX → RKNN, documenting key pitfalls encountered, including dynamic dimensions, pseudo-dynamics, INT8 quantization, and Less operator conflicts. The final solution was: FP16 Encoder + FP16 Decoder (recommended for clear audio quality), and INT8 Decoder (an alternative, smaller in size but with some loss of audio quality).

<p align="right">(<a href="#technical-notes">Back to top</a>)</p>

---

<a id="-ros2"></a>

## 🦾 ROS2

> Categories: ROS2 | WSL2 | Cross-machine communication | Fast-DDS

- [Complete Engineering Practice for ROS2 Robot Simulation and Navigation](./ros/ROS2-Robot-Simulation-and-Navigation-Engineering-Practice.md) `#ROS2 #RobotSimulation #Navigation #EngineeringPractice`

    > This project builds a ROS2 robot simulation and navigation system from scratch, covering core aspects such as modeling, simulation, and navigation algorithms.

- [WSL2 ROS2 Cross-Machine Communication Issue](./ros/WSL2-ROS2-Cross-Machine-Communication.md) `#WSL2 #ROS2 #Fast-DDS #CrossMachineCommunication #MulticastDiscovery`

    > WSL2 Ubuntu 20.04/22.04/24.04 + ROS2 Foxy/Galactic/Humble/Rolling, cross-machine communication fails to discover nodes. After troubleshooting issues with the Fast-DDS multicast discovery mechanism, network interface binding, and environment variable configuration, the final solution was: unified DDS domain ID + forced intra-subnet multicast discovery + specified network interface eth0.

- [Troubleshooting ROS2 Image Stuttering, WiFi QoS, and WSL2 Issues](./ros/ROS2-Image-Stuttering-WiFi-QoS-and-WSL2-Troubleshooting.md) `#ROS2 #WiFi #QoS #WSL2 #ImageStuttering #Debugging`

    > On a ROS2 Jazzy + WSL2 Ubuntu 24.04 system, issues included image transmission stuttering, frame drops, and command crashes. Troubleshooting involved checking WiFi packet loss rate, compression settings, asynchronous encoding, and QoS configuration. The solution was ultimately achieved through three measures: ① Enabling compression on the publishing end; ② Moving encoding to a separate thread for asynchronous publishing; ③ Explicitly specifying the BEST_EFFORT QoS on the subscription end.

- [Cross-Compiling ROS2 Jazzy to RK3588 on x86](./ros/Cross-Compiling-ROS2-Pitfalls.md) `#CrossCompileToolchain #cmake #CMakeLists.txt`

    > This document records the configuration of dual sysroots, toolchain files, and CMakeLists to resolve issues such as disabled Python generators, missing system libraries, and link paths.

<p align="right">(<a href="#technical-notes">Back to top</a>)</p>

---

<a id="-embedded"></a>

## 🔄 Embedded

> Categories: Cross-compilation | Rootfs build | QEMU chroot | Driver porting | Troubleshooting

- [Failed to take /etc/passwd lock: Invalid argument](./embed/QEMU-Rootfs-Build-Systemd-Lock-Fix.md) `#Ubuntu24.04 #systemd #QEMU #ARM64_rootfs`

    > This document documents my experience building an ARM64 Ubuntu 24.04 rootfs root filesystem using x86 VMware-Ubuntu 20.04. It includes solutions to incompatibility errors caused by systemd v254 + OFD locks, summarizing the pitfalls encountered, providing multiple workable repair scripts, and analyzing the underlying principles.

- [RK3588 Ubuntu Porting Camera Display Issue](./embed/Camera-Display-Troubleshooting.md) `#RK3588 #MIPI #Camera #DRM #Ubuntu24.04`

    > An ATK-DLRK3588 development board with a 5.5-inch MIPI screen experienced camera display issues after porting Ubuntu from Buildroot. Troubleshooting included issues with the DRM display framework, MIPI DSI configuration, and camera driver compatibility.

- [RK3588 ES8388 Audio No Sound Issue](./embed/ES8388-Audio-No-Sound-Troubleshooting.md) `#RK3588 #ES8388 #Audio #ALSA #Ubuntu24.04`

    > The ES8388 chip's internal OUT1/OUT2 output stage switches are off by default, preventing signals from reaching the speaker. Buildroot enables this automatically via UCM; on Ubuntu, it requires manual enabling via amixer or configuration for automatic startup.

- [Porting Noble Version Rootfs to RK3588](./embed/RK3588-Noble-Rootfs-Porting.md) `#RK3588 #Ubuntu24.04 #rootfs`

    > RK3588 is used to build and port the Ubuntu 24.04 rootfs, supporting QEMU chroot and driver porting.

<p align="right">(<a href="#technical-notes">Back to top</a>)</p>

---

<a id="-iot"></a>

## 📡 IoT

> Categories: CAN | Bluetooth | NFC | Other Peripheral Interfaces

- [CAN UDS Vehicle Communication Diagnostic Technology Documentation](./iot/CAN-UDS-Automotive-Diagnostic-Technical-Guide.md) `#CAN #UDS #ISO14229 #ISO15765 #DiagnosticProtocol`

    > CAN bus communication principles, UDS protocol stack, ISO14229/ISO15765 standards, diagnostic service SID, sub-function, negative response code (NRC). Communication flow between vehicle diagnostic tools and ECUs, UDS request/response message format, and parsing of commonly used diagnostic services.

- [Bluetooth Low Energy Communication Principles Explained](./iot/Bluetooth-Low-Energy-Complete-Communication-Guide.md) `#BLE #Bluetooth #LowPower #CommunicationProtocol #SecurityMechanism`

    > Bluetooth Low Energy communication principles, broadcasting and scanning, connection establishment, link encryption, application authentication, command interaction, and power management. Includes security mechanisms such as RPA/Replay Attack/Whitelist/IRK/CSRK, and power consumption and fault tolerance designs such as Dynamic Interval/OTA A/B Partition.

- [NFC Technology Principles and Car Key Applications](./iot/NFC-Technology-and-Car-Key-Applications.md) `#NFC #NearFieldCommunication #DigitalKey #ISO15765-2`

    > This course provides a systematic explanation of NFC technology principles (13.56MHz, electromagnetic induction, load modulation, and three operating modes). It covers the general hardware architecture of automotive NFC key systems (antenna/RF controller/MCU/HSM/CAN bus). The course also explains automotive diagnostic communication protocols (ISO 14229 UDS and ISO 15765-2 transport layer), including four frame types, secure access mechanisms, and routine control format parsing.

<p align="right">(<a href="#technical-notes">Back to top</a>)</p>

---

<a id="-tools"></a>

## 🛠 Tools

> Categories: Debugging Tools | Disassembler | Reverse Engineering

- [ELF Static Reverse Engineering](./tools/ELF-Static-Reverse-Engineering-Analysis.md) `#ELF #StaticAnalysis #ReverseEngineering #Ghidra #radare2`

    > ELF file structure, ELF header, section table, symbol table, relocation table, dynamic link table. Static analysis workflow: strings → Ghidra decompilation → radare2 advanced analysis → reconstruct source code.

- [GDB Dynamic Debugging Guide](./tools/GDB-Dynamic-Debugging-Guide.md) `#GDB #Debugging #DynamicAnalysis #Breakpoints #MemoryInspection`

    > GDB command cheat sheet, quick debugging process, memory check, conditional breakpoints, user-defined commands.

- [Common Git Operations and Security Practices](./tools/Git-Common-Operations-and-Security-Practices.md) `#Git #VersionControl #SecurityPractices`

    > Git common operations, branch management, merge strategies, conflict resolution, and security practices.

<p align="right">(<a href="#technical-notes">Back to top</a>)</p>

---

<a id="-scripts"></a>

## 📜 Scripts

> Project-aided build scripts and environment configuration

- [configure-rootfs.sh](../scripts/configure-rootfs.sh) `#RK3588 #Ubuntu #rootfs #PackagingScript`

    > RK3588 is a build and packaging script for Ubuntu 20.04/24.04 rootfs. It supports automatic installation of the rkaiq camera engine deb package extracted from the Buildroot target directory.

- [configure-bashrc](../scripts/configure-bashrc) `#bash #shell #EnvironmentConfiguration`

    > Bash environment configuration file: intelligent PATH management, locale, history, and shell behavior optimization.

- [configure-vimrc](../scripts/configure-vimrc) `#vim #EditorConfiguration`

    > Minimal Vim configuration without plugins, retains commonly used keyboard shortcuts, and supports Linux/WSL clipboard.

<p align="right">(<a href="#technical-notes">Back to top</a>)</p>

---

<a id="-repos"></a>

## 🏠 Repos

> Open source project links

- [eai-rk3588](https://github.com/kyshipit/eai-rk3588) — A plug-in-based RK3588 edge inference platform with multi-threaded pipeline, RKNN adapter, RKLLM dialogue, and coordinator-driven multi-slot activation.
- [MeloTTS](https://github.com/kyshipit/MeloTTS) — MeloTTS ONNX Export + RKNN Deployment (RK3588), INT8 Quantization and Deployment.
- [ros-robot](https://github.com/kyshipit/ros-robot) — a scalable edge AI robot platform based on ROS2, with built-in YOLO and SCRFD models, and supports local RKLLM dialogue and text-to-speech (TTS).

<p align="right">(<a href="#technical-notes">Back to top</a>)</p>

---

If this was helpful, please give it a Star ⭐ to show your support, thank you!

---

## 📄 License

The notes are in [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) format, and the code/scripts are licensed under [the MIT License](../LICENSE) .

<p align="right">(<a href="#technical-notes">Back to top</a>)</p>