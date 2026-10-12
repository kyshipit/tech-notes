<div align="center">
</div>
<h1 data-md-type="header" data-md-header-level="1">Technical Notes</h1>
<p data-md-type="paragraph"><img src="https://img.shields.io/github/last-commit/kyshipit/tech-notes?style=flat-square" alt="GitHub last commit" data-md-type="image"><img src="https://img.shields.io/github/repo-size/kyshipit/tech-notes?style=flat-square" alt="GitHub repo size" data-md-type="image"><img src="https://img.shields.io/github/license/kyshipit/tech-notes?style=flat-square" alt="GitHub" data-md-type="image"><img data-md-type="raw_html" src="https://komarev.com/ghpvc/?username=kyshipit&amp;color=007ec6&amp;style=flat-square&amp;label=views"> <a data-md-type="raw_html" href="https://github.com/kyshipit/tech-notes"></a><img data-md-type="raw_html" src="https://img.shields.io/badge/%E2%AD%90%EF%B8%8F-%E7%BB%99%E4%B8%AAStar-brightgreen?style=flat-square" alt="Give it a star"></p>
<div data-md-type="block_html">
<p>   <a href="#-ai">AI</a> · <a href="#-%E9%87%8F%E5%8C%96%E9%83%A8%E7%BD%B2">Quantitative Deployment</a> · <a href="#-ros2">ROS2</a> · <a href="#-%E5%B5%8C%E5%85%A5%E5%BC%8F">Embedded Systems</a> · <a href="#-IoT">IoT</a> · <a href="#-%E5%B7%A5%E5%85%B7">Tools</a> · <a href="#-%E8%84%9A%E6%9C%AC">Scripts</a> · <a href="#-%E4%B8%AA%E4%BA%BA%E4%BB%93">Personal Warehouse</a> </p>
</div>
<div data-md-type="block_html"></div>

---

> [!NOTE] 📖 Technical notes on embedded systems, AI, robotics, IoT, and other related fields, continuously updated.

---

## ✨ Content Overview

<table align="center">
  <tr>
    <td nowrap align="center"><a href="#-ai"><b>🤖 AI</b></a></td>
    <td nowrap align="center"><a href="#-%E9%87%8F%E5%8C%96%E9%83%A8%E7%BD%B2"><b>🚀 Quantitative Deployment</b></a></td>
    <td nowrap align="center"><a href="#-ros2"><b>🦾 ROS2</b></a></td>
    <td nowrap align="center"><a href="#-%E5%B5%8C%E5%85%A5%E5%BC%8F"><b>🔄 Embedded</b></a></td>
  </tr>
  <tr>
    <td nowrap align="center"><a href="#-IoT"><b>📡 IoT</b></a></td>
    <td nowrap align="center"><a href="#-%E5%B7%A5%E5%85%B7"><b>🛠 Tools</b></a></td>
    <td nowrap align="center"><a href="#-%E8%84%9A%E6%9C%AC"><b>📜 Script</b></a></td>
    <td nowrap align="center"><a href="#-%E4%B8%AA%E4%BA%BA%E4%BB%93"><b>🏠 Personal Storage</b></a></td>
  </tr>
</table>

---

<a id="-ai"></a>

## 🤖 AI

> Categories: AI End-to-End | Knowledge System | Agent Architecture

- [AI Knowledge System Construction](./ai/AI%E7%9F%A5%E8%AF%86%E4%BD%93%E7%B3%BB%E6%9E%84%E9%80%A0.md) `#AI #Agent #RAG #大模型#工程化`

    > This document outlines a comprehensive knowledge system for the AI ​​field, encompassing a complete technology stack from underlying mathematics to industrial-grade agents. It covers modules such as the "brain" (large-scale model), memory modules, planning modules, tool invocation, skills, RAG retrieval, model engineering, and agent engineering. The core focus is on building industrial-grade intelligent agents capable of solving real-world problems.

- [AI engineering implementation related](./ai/AI%E5%B7%A5%E7%A8%8B%E8%90%BD%E5%9C%B0%E7%9B%B8%E5%85%B3.md) `#AI #Agent #RAG #大模型#工程化`

    > This is a collection of technical notes related to AI engineering implementation, covering modules such as model optimization, quantitative deployment, agent architecture, skill systems, and toolchains.

<p align="right">( <a href="#%E6%8A%80%E6%9C%AF%E7%AC%94%E8%AE%B0">Back to top</a> )</p>

---

<a id="-量化部署"></a>

## 🚀 Quantitative Deployment

> Categories: Model Conversion | Quantization Deployment | RKNN | ONNX | NPU Inference

- [RKNPU Model Quantization Deployment Principles Manual](./deploy/RKNPU%E6%A8%A1%E5%9E%8B%E9%87%8F%E5%8C%96%E9%83%A8%E7%BD%B2%E5%8E%9F%E7%90%86%E6%89%8B%E5%86%8C.md) `#RKNN #量化#ONNX #NPU #部署`

    > From ONNX to NPU instructions, what does the compiler do internally, how are parameters configured, and why?

- [MeloTTS RKNN Quantization Deployment Troubleshooting Log](./deploy/melotts-rknn%E9%87%8F%E5%8C%96%E9%83%A8%E7%BD%B2%E8%B8%A9%E5%9D%91%E8%AE%B0%E5%BD%95.md) `#MeloTTS #RKNN #INT8量化#ONNX #RK3588 #NPU`

    > This document documents the entire deployment process of PyTorch → ONNX → RKNN, documenting key pitfalls encountered, including dynamic dimensions, pseudo-dynamics, INT8 quantization, and Less operator conflicts. The final solution was: FP16 Encoder + FP16 Decoder (recommended for clear audio quality), and INT8 Decoder (an alternative, smaller in size but with some loss of audio quality).

<p align="right">( <a href="#%E6%8A%80%E6%9C%AF%E7%AC%94%E8%AE%B0">Back to top</a> )</p>

---

<a id="-ros2"></a>

## 🦾 ROS2

> Categories: ROS2 | WSL2 | Cross-machine communication | Fast-DDS

- [Complete Engineering Practice for ROS2 Robot Simulation and Navigation](./ros/ROS2%E6%9C%BA%E5%99%A8%E4%BA%BA%E4%BB%BF%E7%9C%9F%E4%B8%8E%E5%AF%BC%E8%88%AA%E5%AE%8C%E6%95%B4%E5%B7%A5%E7%A8%8B%E5%AE%9E%E8%B7%B5.md) `#ROS2 #机器人仿真#导航#工程实践`

    > This project builds a ROS2 robot simulation and navigation system from scratch, covering core aspects such as modeling, simulation, and navigation algorithms.

- [WSL2 ROS2 cross-machine communication issue](./ros/WSL2-ROS2%E8%B7%A8%E6%9C%BA%E9%80%9A%E4%BF%A1%E9%97%AE%E9%A2%98.md) `#WSL2 #ROS2 #Fast-DDS #跨机通信#多播发现`

    > WSL2 Ubuntu 20.04/22.04/24.04 + ROS2 Foxy/Galactic/Humble/Rolling, cross-machine communication fails to discover nodes. After troubleshooting issues with the Fast-DDS multicast discovery mechanism, network interface binding, and environment variable configuration, the final solution was: unified DDS domain ID + forced intra-subnet multicast discovery + specified network interface eth0.

- [Troubleshooting ROS2 image stuttering, WiFi QoS, and WSL2 issues](./ros/ROS2%E5%9B%BE%E5%83%8F%E5%8D%A1%E9%A1%BFWiFi_QoS%E4%B8%8EWSL2%E6%8E%92%E9%94%99.md) `#ROS2 #WiFi #QoS #WSL2 #图像卡顿#调试`

    > On a ROS2 Jazzy + WSL2 Ubuntu 24.04 system, issues included image transmission stuttering, frame drops, and command crashes. Troubleshooting involved checking WiFi packet loss rate, compression settings, asynchronous encoding, and QoS configuration. The solution was ultimately achieved through three measures: ① Enabling compression on the publishing end; ② Moving encoding to a separate thread for asynchronous publishing; ③ Explicitly specifying the BEST_EFFORT QoS on the subscription end.

- [Cross-compiling ROS2 Jazzy to rk3588 on x86](./ros/%E4%BA%A4%E5%8F%89%E7%BC%96%E8%AF%91ROS2%E8%B8%A9%E5%9D%91%E8%AE%B0%E5%BD%95.md) `#交叉编译工具链#cmake #CMakeLists.txt`

    > This document records the configuration of dual sysroots, toolchain files, and CMakeLists to resolve issues such as disabled Python generators, missing system libraries, and link paths.

<p align="right">( <a href="#%E6%8A%80%E6%9C%AF%E7%AC%94%E8%AE%B0">Back to top</a> )</p>

---

<a id="-嵌入式"></a>

## 🔄 Embedded

> Categories: Cross-compilation | Rootfs build | QEMU chroot | Driver porting | Troubleshooting

- [Failed to take /etc/passwd lock: Invalid argument](./embed/qemu%E6%9E%84%E5%BB%BArootfs%E6%97%B6systemd%E9%94%81%E9%97%AE%E9%A2%98%E4%BF%AE%E5%A4%8D.md) `#Ubuntu24.04 #systemd #QEMU #ARM64_rootfs`

    > This document documents my experience building an ARM64 Ubuntu 24.04 rootfs root filesystem using x86 VMware-Ubuntu 20.04. It includes solutions to incompatibility errors caused by systemd v254 + OFD locks, summarizing the pitfalls encountered, providing multiple workable repair scripts, and analyzing the underlying principles.

- [RK3588 Ubuntu porting camera display issue](./embed/camera%E6%98%BE%E7%A4%BA%E9%97%AE%E9%A2%98%E6%8E%92%E6%9F%A5.md) `#RK3588 #MIPI #摄像头#DRM #Ubuntu24.04`

    > An ATK-DLRK3588 development board with a 5.5-inch MIPI screen experienced camera display issues after porting Ubuntu from Buildroot. Troubleshooting included issues with the DRM display framework, MIPI DSI configuration, and camera driver compatibility.

- [RK3588 ES8388 Audio No Sound Issue](./embed/es8388%E9%9F%B3%E9%A2%91%E6%97%A0%E5%A3%B0%E6%8E%92%E6%9F%A5.md) `#RK3588 #ES8388 #音频#ALSA #Ubuntu24.04`

    > The ES8388 chip's internal OUT1/OUT2 output stage switches are off by default, preventing signals from reaching the speaker. Buildroot enables this automatically via UCM; on Ubuntu, it requires manual enabling via amixer or configuration for automatic startup.

- [Porting Noble version rootfs to RK3588](./embed/rk3588%E7%A7%BB%E6%A4%8Dnoble%E7%89%88%E6%9C%ACrootfs.md) `#RK3588 #Ubuntu24.04 #rootfs`

    > RK3588 is used to build and port the Ubuntu 24.04 rootfs, supporting QEMU chroot and driver porting.

<p align="right">( <a href="#%E6%8A%80%E6%9C%AF%E7%AC%94%E8%AE%B0">Back to top</a> )</p>

---

<a id="-IoT"></a>

## 📡 IoT

> Categories: CAN | Bluetooth | NFC | Other Peripheral Interfaces

- [CAN UDS Vehicle Communication Diagnostic Technology Documentation](./iot/can_uds%E8%BD%A6%E8%BD%BD%E9%80%9A%E4%BF%A1%E8%AF%8A%E6%96%AD%E6%8A%80%E6%9C%AF%E6%96%87%E6%A1%A3.md) `#CAN #UDS #ISO14229 #ISO15765 #诊断协议`

    > CAN bus communication principles, UDS protocol stack, ISO14229/ISO15765 standards, diagnostic service SID, sub-function, negative response code (NRC). Communication flow between vehicle diagnostic tools and ECUs, UDS request/response message format, and parsing of commonly used diagnostic services.

- [Bluetooth Low Energy Communication Principles Explained](./iot/%E8%93%9D%E7%89%99%E4%BD%8E%E5%8A%9F%E8%80%97%E5%AE%8C%E6%95%B4%E9%80%9A%E4%BF%A1%E5%8E%9F%E7%90%86%E8%A7%A3%E6%9E%90.md) `#BLE #蓝牙#低功耗#通信协议#安全机制`

    > Bluetooth Low Energy communication principles, broadcasting and scanning, connection establishment, link encryption, application authentication, command interaction, and power management. Includes security mechanisms such as RPA/Replay Attack/Whitelist/IRK/CSRK, and power consumption and fault tolerance designs such as Dynamic Interval/OTA A/B Partition.

- [NFC Technology Principles and Car Key Applications](./iot/NFC%E6%8A%80%E6%9C%AF%E5%8E%9F%E7%90%86%E4%B8%8E%E6%B1%BD%E8%BD%A6%E9%92%A5%E5%8C%99%E5%BA%94%E7%94%A8.md) `#NFC #近场通信#数字钥匙#ISO 15765-2`

    > This course provides a systematic explanation of NFC technology principles (13.56MHz, electromagnetic induction, load modulation, and three operating modes). It covers the general hardware architecture of automotive NFC key systems (antenna/RF controller/MCU/HSM/CAN bus). The course also explains automotive diagnostic communication protocols (ISO 14229 UDS and ISO 15765-2 transport layer), including four frame types, secure access mechanisms, and routine control format parsing.

<p align="right">( <a href="#%E6%8A%80%E6%9C%AF%E7%AC%94%E8%AE%B0">Back to top</a> )</p>

---

<a id="-工具"></a>

## 🛠 Tools

> Categories: Debugging Tools | Disassembler | Reverse Engineering

- [ELF Static Reverse Engineering](./tools/ELF%E9%9D%99%E6%80%81%E9%80%86%E5%90%91%E5%88%86%E6%9E%90.md) `#ELF #静态分析#逆向#Ghidra #radare2`

    > ELF file structure, ELF header, section table, symbol table, relocation table, dynamic link table. Static analysis workflow: strings → Ghidra decompilation → radare2 advanced analysis → reconstruct source code.

- [GDB Dynamic Debugging Guide](./tools/GDB%E5%8A%A8%E6%80%81%E8%B0%83%E8%AF%95%E6%8C%87%E5%8D%97.md) `#GDB #调试#动态分析#断点#内存检查`

    > GDB command cheat sheet, quick debugging process, memory check, conditional breakpoints, user-defined commands.

- [Common Git Operations and Security Practices](./tools/Git%E5%B8%B8%E7%94%A8%E6%93%8D%E4%BD%9C%E4%B8%8E%E5%AE%89%E5%85%A8%E5%AE%9E%E8%B7%B5.md) `#Git #版本控制#安全实践`

    > Git common operations, branch management, merge strategies, conflict resolution, and security practices.

<p align="right">( <a href="#%E6%8A%80%E6%9C%AF%E7%AC%94%E8%AE%B0">Back to top</a> )</p>

---

<a id="-脚本"></a>

## 📜 Script

> Project-aided build scripts and environment configuration

- [configure-rootfs.sh](./scripts/configure-rootfs.sh) `#RK3588 #Ubuntu #rootfs #打包脚本`

    > RK3588 is a build and packaging script for Ubuntu 20.04/24.04 rootfs. It supports automatic installation of the rkaiq camera engine deb package extracted from the Buildroot target directory.

- [configure-bashrc](./scripts/configure-bashrc) `#bash #shell #环境配置`

    > Bash environment configuration file: intelligent PATH management, locale, history, and shell behavior optimization.

- [configure-vimrc](./scripts/configure-vimrc) `#vim #编辑器配置`

    > Minimal Vim configuration without plugins, retains commonly used keyboard shortcuts, and supports Linux/WSL clipboard.

<p align="right">( <a href="#%E6%8A%80%E6%9C%AF%E7%AC%94%E8%AE%B0">Back to top</a> )</p>

---

<a id="-个人仓"></a>

## 🏠 Personal Storage

> Open source project link

- [eai-rk3588](https://github.com/kyshipit/eai-rk3588) — A plug-in-based RK3588 edge inference platform with multi-threaded pipeline, RKNN adapter, RKLLM dialogue, and coordinator-driven multi-slot activation.
- [MeloTTS](https://github.com/kyshipit/MeloTTS) — MeloTTS ONNX Export + RKNN Deployment (RK3588), INT8 Quantization and Deployment.
- [ros-robot](https://github.com/kyshipit/ros-robot) — a scalable edge AI robot platform based on ROS2, with built-in YOLO and SCRFD models, and supports local RKLLM dialogue and text-to-speech (TTS).

<p align="right">( <a href="#%E6%8A%80%E6%9C%AF%E7%AC%94%E8%AE%B0">Back to top</a> )</p>

---

If this was helpful, please give it a Star ⭐ to show your support, thank you!

---

## 📄 License

The notes are in [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) format, and the code/scripts are licensed under [the MIT License](LICENSE) .

<p align="right">( <a href="#%E6%8A%80%E6%9C%AF%E7%AC%94%E8%AE%B0">Back to top</a> )</p>
