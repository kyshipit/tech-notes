<div align="center">
  
# 技术笔记

> 个人知识沉淀 · 工程实践记录

![GitHub last commit](https://img.shields.io/github/last-commit/kyshipit/tech-notes?style=flat-square)
![GitHub repo size](https://img.shields.io/github/repo-size/kyshipit/tech-notes?style=flat-square)
![GitHub](https://img.shields.io/github/license/kyshipit/tech-notes?style=flat-square)

<p>
  <a href="#-ai">AI</a> ·
  <a href="#-嵌入式">嵌入式</a> ·
  <a href="#-量化部署">量化部署</a> ·
  <a href="#-ros2">ROS2</a> ·
  <a href="#-工具">工具</a> ·
  <a href="#-脚本">脚本</a> ·
  <a href="#-个人仓">个人仓</a>
</p>

</div>

---

> [!NOTE]
> 📖 所有笔记按分类整理，每篇独立成文，附带标签便于检索。

---

## ✨ 内容概览

<table align="center">
  <tr>
    <td nowrap align="center"><a href="#-ai"><b>🤖 AI</b></a></td>
    <td nowrap align="center"><a href="#-嵌入式"><b>🔄 嵌入式</b></a></td>
    <td nowrap align="center"><a href="#-量化部署"><b>🚀 量化部署</b></a></td>
    <td nowrap align="center"><a href="#-ros2"><b>🦾 ROS2</b></a></td>
  </tr>
  <tr>
    <td nowrap align="center"><a href="#-工具"><b>🛠 工具</b></a></td>
    <td nowrap align="center"><a href="#-脚本"><b>📜 脚本</b></a></td>
    <td nowrap align="center"><a href="#-个人仓"><b>🏠 个人仓</b></a></td>
    <td nowrap align="center"><a href="#-其他"><b>📌 其他</b></a></td>
  </tr>
</table>

---

<a id="-ai"></a>
## 🤖 AI

> 分类：AI 全链路 | 知识体系 | Agent 架构

- [AI 全链路知识体系](./ai/AI全链路知识体系.md)
  `#AI #Agent #RAG #大模型 #工程化`
  > AI 领域全链路知识体系构造，从底层数学到工业级 Agent 的完整技术栈。
  > 涵盖大脑（大模型）、记忆模块、规划模块、工具调用、Skills、RAG 检索、模型工程化、Agent 工程化等模块。
  > 核心主线：构建能解决实际问题的工业级智能体 Agent。

<p align="right">(<a href="#技术笔记">返回顶部</a>)</p>

---

<a id="-嵌入式"></a>
## 🔄 嵌入式

> 分类：交叉编译 | Rootfs 构建 | QEMU chroot | 驱动移植 | 问题排查

- [Failed to take /etc/passwd lock: Invalid argument](./port/qemu构建rootfs时systemd锁问题修复.md)
  `#Ubuntu24.04 #systemd #QEMU #ARM64_rootfs`
  > x86 VMware-Ubuntu20.04 构建 ARM64 Ubuntu 24.04 rootfs 根文件系统时的记录。
  > 解决 systemd v254+ OFD 锁不兼容报错，汇总踩坑记录、多套可落地修复脚本、底层原理分析。

- [RK3588 Ubuntu 移植摄像头显示问题](./port/camera显示问题排查.md)
  `#RK3588 #MIPI #摄像头 #DRM #Ubuntu24.04`
  > ATK-DLRK3588 开发板 + 5.5 寸 MIPI 屏幕，从 Buildroot 移植 Ubuntu 后摄像头画面显示异常。
  > 排查 DRM 显示框架、MIPI DSI 配置、摄像头驱动适配等问题。

- [RK3588 ES8388 音频无声问题](./port/es8388音频无声排查.md)
  `#RK3588 #ES8388 #音频 #ALSA #Ubuntu24.04`
  > ES8388 芯片内部 OUT1/OUT2 输出级开关默认关闭，导致信号无法到达扬声器。
  > Buildroot 通过 UCM 自动开启，Ubuntu 需手动 amixer 开启或配置开机自启。

- [RK3588 移植 Noble 版本 rootfs](./port/rk3588移植noble版本rootfs.md)
  `#RK3588 #Ubuntu24.04 #rootfs`
  > RK3588 构建与移植 Ubuntu 24.04 rootfs ，支持 QEMU chroot、驱动移植。

<p align="right">(<a href="#技术笔记">返回顶部</a>)</p>

---

<a id="-量化部署"></a>
## 🚀 量化部署

> 分类：模型转换 | 量化部署 | RKNN | ONNX | NPU 推理

- [MeloTTS RKNN 量化部署踩坑记录](./deploy/melotts-rknn量化部署踩坑记录.md)
  `#MeloTTS #RKNN #INT8量化 #ONNX #RK3588 #NPU`
  > PyTorch → ONNX → RKNN 全流程，含动态维度、假动态、INT8 量化、Less 算子冲突等核心踩坑记录。
  > 最终方案：FP16 Encoder + INT8 Decoder，推理时间 1.8–2.2s，模型体积 129MB→67MB。

<p align="right">(<a href="#技术笔记">返回顶部</a>)</p>

---

<a id="-ros2"></a>
## 🦾 ROS2

> 分类：ROS2 | WSL2 | 跨机通信 | Fast-DDS

- [WSL2 ROS2 跨机通信问题](./ros/WSL2-ROS2跨机通信问题.md)
  `#WSL2 #ROS2 #Fast-DDS #跨机通信 #多播发现`
  > WSL2 Ubuntu20.04/22.04/24.04 + ROS2 Foxy/Galactic/Humble/Rolling，跨机通信无法发现节点。
  > 排查 Fast-DDS 多播发现机制、网络接口绑定、环境变量配置等问题，最终解决方案：统一 DDS 域 ID + 强制子网内多播发现 + 指定网卡 eth0。

- [ROS2 图像卡顿 WiFi QoS 与 WSL2 排错](./ros/ROS2图像卡顿WiFi_QoS与WSL2排错.md)
  `#ROS2 #WiFi #QoS #WSL2 #图像卡顿 #调试`
  > ROS2 Jazzy + WSL2 Ubuntu 24.04，图像传输卡顿、丢帧、命令卡死——排查了 WiFi 丢包率、压缩话题、异步编码、QoS 配置。
  > 最终通过三项措施解决：① 发布端启用压缩话题；② 将编码移至独立线程实现异步发布；③ 订阅端显式指定 BEST_EFFORT QoS。

<p align="right">(<a href="#技术笔记">返回顶部</a>)</p>

---

<a id="-工具"></a>
## 🛠 工具

> 分类：调试工具 | 反汇编 | 逆向分析

- [GDB 调试 + Ghidra 反汇编](./tools/gdb-ghidra.md)
  `#GDB #Ghidra #调试 #反汇编 #逆向`
  > GDB 命令速查表、快速调试流程、内存检查、条件断点、用户自定义命令。
  > Ghidra 反编译、objdump 反汇编、radare2 高级分析、从反编译重建源代码。

<p align="right">(<a href="#技术笔记">返回顶部</a>)</p>

---

<a id="-脚本"></a>
## 📜 脚本

> 项目辅助构建脚本与环境配置

- [configure-rootfs.sh](./scripts/configure-rootfs.sh)
  `#RK3588 #Ubuntu #rootfs #打包脚本`
  > RK3588 Ubuntu 20.04/24.04 rootfs 构建与打包脚本。
  > 支持从 Buildroot target 目录提取 + rkaiq 摄像头引擎 deb 包的自动安装。

- [configure-bashrc](./scripts/configure-bashrc)
  `#bash #shell #环境配置`
  > Bash 环境配置文件：智能 PATH 管理、语言环境、历史记录、Shell 行为优化。

- [configure-vimrc](./scripts/configure-vimrc)
  `#vim #编辑器配置`
  > 极简无插件 Vim 配置，保留常用快捷键，支持 Linux/WSL 剪贴板。

<p align="right">(<a href="#技术笔记">返回顶部</a>)</p>

---

<a id="-个人仓"></a>
## 🏠 个人仓

> 开源项目链接

- [eai-rk3588](https://github.com/kyshipit/eai-rk3588) — 基于插件的 RK3588 边缘推理平台，多线程流水线、RKNN 适配器、RKLLM 对话、协调器驱动的多槽位激活
- [MeloTTS](https://github.com/kyshipit/MeloTTS) — MeloTTS ONNX 导出 + RKNN 部署（RK3588），INT8 量化和部署

<p align="right">(<a href="#技术笔记">返回顶部</a>)</p>

---

<a id="-其他"></a>
## 📌 其他

> 待补充

<p align="right">(<a href="#技术笔记">返回顶部</a>)</p>

---

## 📄 许可证

笔记内容采用 [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)，代码/脚本遵循 [MIT License](LICENSE)。

<p align="right">(<a href="#技术笔记">返回顶部</a>)</p>