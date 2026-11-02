**简体中文** | [English](README.md)

<div align="center">

# 技术笔记
<p>
  <a href="#ai">AI</a> ·
  <a href="#量化部署">量化部署</a> ·
  <a href="#ros2">ROS2</a> ·
  <a href="#嵌入式">嵌入式</a> ·
  <a href="#IoT">IoT</a> ·
  <a href="#工具">工具</a> ·
  <a href="#脚本">脚本</a> ·
  <a href="#个人仓">个人仓</a>
</p>
</div>

> 嵌入式、AI、机器人、IoT 等领域的技术笔记，持续更新中。如果对你有所帮助的话，请点个 Star ⭐ 支持一下，谢谢！


<a id="ai"></a>
## AI
> AI 全链路 | 知识体系 | Agent 架构

- [AI 知识体系构造：从底层数学到工业级 Agent 的完整技术栈](ai/AI知识体系构造.md)
- [AI 工程落地：涵盖模型优化、量化部署与 Agent 架构等核心模块](ai/AI工程落地相关.md)


<a id="量化部署"></a>
## 量化部署
> 模型转换 | 量化部署 | RKNN | ONNX | NPU 推理

- [RKNPU 量化手册：编译器从 ONNX 到 NPU 指令的内部原理与参数配置](deploy/RKNPU模型量化部署原理手册.md)
- [MeloTTS RKNN 部署踩坑：解决 INT8 量化与动态维度等核心问题](deploy/melotts-rknn量化部署踩坑记录.md)


<a id="ros2"></a>
## ROS2
> ROS2 | WSL2 | 跨机通信 | Fast-DDS

- [ROS2 机器人仿真与导航：涵盖建模、仿真与导航算法的完整实践](ros/ROS2机器人仿真与导航完整工程实践.md)
- [WSL2 ROS2 跨机通信：解决 Fast-DDS 多播与节点发现问题](ros/WSL2-ROS2跨机通信问题.md)
- [ROS2 图像卡顿排错：优化 WiFi QoS、异步编码与 WSL2 配置](ros/ROS2图像卡顿WiFi_QoS与WSL2排错.md)
- [x86 交叉编译 ROS2 到 RK3588：解决 Sysroot 与 CMake 配置问题](ros/交叉编译ROS2踩坑记录.md)


<a id="嵌入式"></a>
## 嵌入式
> 交叉编译 | Rootfs 构建 | QEMU chroot | 驱动移植 | 问题排查

- [QEMU Rootfs 构建：修复 systemd v254 + OFD 锁不兼容问题](embed/qemu构建rootfs时systemd锁问题修复.md)
- [RK3588 摄像头显示：排查 DRM、MIPI DSI 与驱动兼容性](embed/camera显示问题排查.md)
- [RK3588 ES8388 音频无声：修复输出级开关默认关闭问题](embed/es8388音频无声排查.md)
- [RK3588 移植 Ubuntu 24.04 rootfs：支持 QEMU chroot 与驱动移植](embed/rk3588移植noble版本rootfs.md)


<a id="IoT"></a>
## IoT
> CAN | 蓝牙 | NFC | 其他外设接口

- [CAN UDS 车辆诊断：协议栈、ISO 标准与报文格式解析](iot/can_uds车载通信诊断技术文档.md)
- [蓝牙低功耗 (BLE)：通信原理、安全机制与功耗容错设计](iot/蓝牙低功耗完整通信原理解析.md)
- [NFC 技术与汽车钥匙：技术原理、硬件架构与诊断协议解析](iot/NFC技术原理与汽车钥匙应用.md)


<a id="工具"></a>
## 工具
> 调试工具 | 反汇编 | 逆向分析

- [ELF 静态逆向分析：文件结构与 Ghidra/radare2 分析流程](tools/ELF静态逆向分析.md)
- [GDB 动态调试：命令速查、断点设置与内存检查](tools/GDB动态调试指南.md)
- [Git 常用操作：分支管理、冲突解决与安全实践](tools/Git常用操作与安全实践.md)


<a id="脚本"></a>
## 脚本
> 项目辅助构建脚本与环境配置

- [configure-rootfs.sh：RK3588 Ubuntu Rootfs 构建与打包脚本](scripts/configure-rootfs.sh)
- [configure-bashrc：Bash 环境与智能 PATH 管理配置](scripts/configure-bashrc)
- [configure-vimrc：极简无插件 Vim 配置（支持 WSL 剪贴板）](scripts/configure-vimrc)


<a id="个人仓"></a>
## 个人仓
> 开源项目链接

- [eai-rk3588：多线程流水线的 RK3588 边缘推理平台](https://github.com/kyshipit/eai-rk3588)
- [MeloTTS：ONNX 导出与 RK3588 RKNN 部署及 INT8 量化实践](https://github.com/kyshipit/MeloTTS)
- [mbot-sim：ROS 2 Jazzy 仿真导航验证（已归档）](https://github.com/kyshipit/mbot-sim)
- [gh-heatmap-generator：GitHub 可视化热力图贡献脚本生成器](https://github.com/kyshipit/gh-heatmap-generator)

<p align="right">(<a href="#技术笔记">返回顶部</a>)</p>


## 许可证

笔记内容采用 [CC BY-SA 4.0](LICENSE-CC-BY-SA)，代码/脚本遵循 [MIT License](LICENSE-MIT)。