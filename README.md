# 📚 索引

> 文档导航目录，快速跳转各模块

---

## 📋 目录
- [🧠 AI](#-ai)
- [📦 移植](#-移植)
- [🔩  模型量化部署](#-模型量化部署)
- [🛠 工具](#-工具)
- [📜 脚本](#-脚本)
- [💻 个人仓库](#-个人仓库)

---

## 🧠 AI
> 分类：AI 全链路 | 知识体系 | Agent 架构

- [AI 全链路知识体系](./ai/AI全链路知识体系.md)
  `#AI #Agent #RAG #大模型 #工程化`
  > AI 领域全链路知识体系构造，从底层数学到工业级 Agent 的完整技术栈
  > 涵盖大脑（大模型）、记忆模块、规划模块、工具调用、Skills、RAG 检索、模型工程化、Agent 工程化等模块
  > 核心主线：构建能解决实际问题的工业级智能体 Agent

---

## 📦 移植
> 分类：交叉编译 | Rootfs 构建 | QEMU chroot | 驱动移植 | 问题排查

- [Failed to take /etc/passwd lock: Invalid argument](./port/qemu构建rootfs时systemd锁问题修复.md)
  `#Ubuntu24.04 #systemd #QEMU #ARM64_rootfs`
  > x86 VMware-Ubuntu20.04 构建 ARM64 Ubuntu 24.04 rootfs 根文件系统时的记录
  > 解决 systemd v254+ OFD 锁不兼容报错，汇总踩坑记录、多套可落地修复脚本、底层原理分析

- [RK3588 Ubuntu 移植摄像头显示问题](./port/camera显示问题排查.md)
  `#RK3588 #MIPI #摄像头 #DRM #Ubuntu24.04`
  > ATK-DLRK3588 开发板 + 5.5 寸 MIPI 屏幕，从 Buildroot 移植 Ubuntu 后摄像头画面显示异常
  > 排查 DRM 显示框架、MIPI DSI 配置、摄像头驱动适配等问题

- [RK3588 ES8388 音频无声问题](./port/es8388音频无声排查.md)
  `#RK3588 #ES8388 #音频 #ALSA #Ubuntu24.04`
  > ATK-DLRK3588 开发板板载扬声器无声，aplay 执行成功但无声音输出
  > 完整排查过程：从 ALSA 驱动、设备树配置、codec 寄存器到混音器通路

---

## 🔩 模型量化部署
> 分类：模型转换 | 量化部署 | RKNN | ONNX | NPU 推理

- [MeloTTS RKNN 量化部署踩坑记录](./deploy/melotts-rknn量化部署踩坑记录.md)
  `#MeloTTS #RKNN #INT8量化 #ONNX #RK3588 #NPU`
  > PyTorch → ONNX → RKNN 全流程，含动态维度、假动态、INT8 量化、Less 算子冲突等核心踩坑记录
  > 最终方案：FP16 Encoder + INT8 Decoder，推理时间 1.8–2.2s，模型体积 129MB→67MB

---

## 🛠 工具
> 分类：调试工具 | 反汇编 | 逆向分析

- [GDB 调试 + Ghidra 反汇编](./tools/gdb-ghidra.md)
  `#GDB #Ghidra #调试 #反汇编 #逆向`
  > GDB 命令速查表、快速调试流程、内存检查、条件断点、用户自定义命令
  > Ghidra 反编译、objdump 反汇编、radare2 高级分析、从反编译重建源代码

---

## 📜 脚本
> 项目辅助构建脚本与环境配置

- [configure-rootfs.sh](./scripts/configure-rootfs.sh)
  `#RK3588 #Ubuntu #rootfs #打包脚本`
  > RK3588 Ubuntu 20.04/24.04 rootfs 构建与打包脚本
  > 支持从 Buildroot target 目录提取 + rkaiq 摄像头引擎 deb 包的自动安装

- [configure-bashrc](./scripts/configure-bashrc)
  `#bash #shell #环境配置`
  > Bash 环境配置文件：智能 PATH 管理、语言环境、历史记录、Shell 行为优化

- [configure-vimrc](./scripts/configure-vimrc)
  `#vim #编辑器配置`
  > 极简无插件 Vim 配置，保留常用快捷键，支持 Linux/WSL 剪贴板

---

## 💻 个人仓库
> 开源项目链接

- [eai-rk3588](https://github.com/kyshipit/eai-rk3588) — 基于插件的 RK3588 边缘推理平台，多线程流水线、RKNN 适配器、RKLLM 对话、协调器驱动的多槽位激活
- [MeloTTS](https://github.com/kyshipit/MeloTTS) — MeloTTS ONNX 导出 + RKNN 部署（RK3588），INT8 量化和部署