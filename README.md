**English** | [简体中文](README.zh.md)

<div align="center">

# Technical Notes
<p>
  <a href="#ai">AI</a> ·
  <a href="#quantization">Quantization</a> ·
  <a href="#ros2">ROS2</a> ·
  <a href="#embedded">Embedded</a> ·
  <a href="#iot">IoT</a> ·
  <a href="#tools">Tools</a> ·
  <a href="#scripts">Scripts</a> ·
  <a href="#repos">Repos</a>
</p>
</div>

> Technical notes covering embedded systems, AI, robotics, IoT and other related fields, continuously updated. If you find this useful, please give it a Star ⭐, thanks!


<a id="ai"></a>

## AI

> AI End-to-End | Knowledge System | Agent Architecture

- [AI Knowledge System Construction: From Mathematics to Industrial-grade Agents](en/ai/AI-Knowledge-System-Construction.md)
- [AI Engineering Implementation: Model Optimization, Quantization & Agent Architecture](en/ai/AI-Engineering-Implementation.md)


<a id="quantization"></a>

## Quantization

> Model Conversion | Quantization Deployment | RKNN | ONNX | NPU Inference

- [RKNPU Quantization Manual: Compiler Internals from ONNX to NPU Instructions](en/deploy/RKNPU-Model-Quantization-Deployment-Principles.md)
- [MeloTTS RKNN Deployment Pitfalls: Resolving INT8 Quantization & Dynamic Dimensions](en/deploy/MeloTTS-RKNN-Quantization-Deployment-Pitfalls.md)


<a id="ros2"></a>

## ROS2

> ROS2 | WSL2 | Cross-machine communication | Fast-DDS

- [ROS2 Robot Simulation & Navigation: Complete Engineering Practice](en/ros/ROS2-Robot-Simulation-and-Navigation-Engineering-Practice.md)
- [WSL2 ROS2 Cross-Machine Communication: Fixing Fast-DDS Multicast Discovery](en/ros/WSL2-ROS2-Cross-Machine-Communication.md)
- [ROS2 Image Stuttering Fix: WiFi QoS, Asynchronous Encoding & WSL2 Issues](en/ros/ROS2-Image-Stuttering-WiFi-QoS-and-WSL2-Troubleshooting.md)
- [Cross-Compiling ROS2 Jazzy to RK3588 on x86: Resolving Sysroot & CMake Issues](en/ros/Cross-Compiling-ROS2-Pitfalls.md)


<a id="embedded"></a>

## Embedded

> Cross-compilation | Rootfs build | QEMU chroot | Driver porting | Troubleshooting

- [QEMU Rootfs Build: Fixing systemd v254 + OFD Lock Incompatibilities](en/embed/QEMU-Rootfs-Build-Systemd-Lock-Fix.md)
- [RK3588 Ubuntu Camera Display: Debugging DRM, MIPI DSI & Driver Compatibility](en/embed/Camera-Display-Troubleshooting.md)
- [RK3588 ES8388 Audio: Fixing Output Stage Switches via ALSA/amixer](en/embed/ES8388-Audio-No-Sound-Troubleshooting.md)
- [Porting Ubuntu 24.04 (Noble) Rootfs to RK3588: QEMU Chroot & Driver Porting](en/embed/RK3588-Noble-Rootfs-Porting.md)


<a id="iot"></a>

## IoT

> CAN | Bluetooth | NFC | Other Peripheral Interfaces

- [CAN UDS Diagnostics: Protocol Stack, ISO Standards, and Message Parsing](en/iot/CAN-UDS-Automotive-Diagnostic-Technical-Guide.md)
- [Bluetooth Low Energy (BLE): Communication Principles, Security & Power Management](en/iot/Bluetooth-Low-Energy-Complete-Communication-Guide.md)
- [NFC Technology & Car Keys: Principles, Hardware Architecture & ISO 15765-2](en/iot/NFC-Technology-and-Car-Key-Applications.md)


<a id="tools"></a>

## Tools

> Debugging Tools | Disassembler | Reverse Engineering

- [ELF Static Reverse Engineering: File Structure & Analysis Workflow](en/tools/ELF-Static-Reverse-Engineering-Analysis.md)
- [GDB Dynamic Debugging Guide: Commands, Breakpoints & Memory Checks](en/tools/GDB-Dynamic-Debugging-Guide.md)
- [Git Common Operations: Branch Management, Conflict Resolution & Security](en/tools/Git-Common-Operations-and-Security-Practices.md)


<a id="scripts"></a>

## Scripts

> Project-aided build scripts and environment configuration

- [configure-rootfs.sh: RK3588 Ubuntu Rootfs Build & Packaging](scripts/configure-rootfs.sh)
- [configure-bashrc: Bash Environment & PATH Configuration](scripts/configure-bashrc)
- [configure-vimrc: Minimal Vim Configuration for Linux/WSL](scripts/configure-vimrc)


<a id="repos"></a>

## Repos

> Open source project links

- [eai-rk3588: Edge Inference Platform with Multi-threaded Pipeline](https://github.com/kyshipit/eai-rk3588)
- [MeloTTS: ONNX Export & RKNN Deployment on RK3588](https://github.com/kyshipit/MeloTTS)
- [mbot-sim: ROS 2 Jazzy simulation navigation verification (archived)](https://github.com/kyshipit/mbot-sim)
- [gh-heatmap-generator: GitHub heatmap visualizer and script generator](https://github.com/kyshipit/gh-heatmap-generator)

<p align="right">(<a href="#technical-notes">Back to top</a>)</p>

## License

The notes are in [CC BY-SA 4.0](LICENSE-CC-BY-SA) format, and the code/scripts are licensed under [the MIT License](LICENSE-MIT).