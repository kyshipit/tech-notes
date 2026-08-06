# 📚 仓库索引

> 文档导航目录，快速跳转各模块

---

## 📋 目录
- [📦 移植](#-移植)
- [🤖 ROS](#-ros)
- [⚙️ 模型量化](#-模型量化)
- [📜 脚本](#-脚本)
- [💻 个人仓库](#-个人仓库)

---

## 📦 移植
> 分类：交叉编译 | Rootfs构建 | QEMU chroot 移植排错

- [Failed to take /etc/passwd lock: Invalid argument](./porting/passwd-lock-invalid-argument-fix.md)
  `#Ubuntu24.04 #systemd #QEMU #ARM64 rootfs`
  > x86 VMware-Ubuntu20.04 构建 ARM64 Ubuntu 24.04 rootfs 根文件系统时的记录
  > 解决systemd v254+ OFD锁不兼容报错，汇总踩坑记录、多套可落地修复脚本、底层原理分析
  > Failed to take /etc/passwd lock: Invalid argument解决方案



---

### 🤖 ROS 
> ROS 相关开发笔记

> 暂无内容

---

### ⚙️ 模型量化
> RKNN、INT8、模型转换、量化部署笔记

> 暂无内容

---

### 📜 脚本
> 项目辅助构建脚本

- [configure-ubuntu-rootfs.sh](./scripts/configure-ubuntu-rootfs.sh) — chroot 内系统配置脚本

---

### 💻 个人仓库
> 开源项目链接

- [eai-rk3588](https://github.com/kyshipit/eai-rk3588) — 基于插件的 RK3588 边缘推理平台，多线程流水线、RKNN 适配器、RKLLM 对话、协调器驱动的多槽位激活
- [MeloTTS](https://github.com/kyshipit/MeloTTS) — MeloTTS ONNX 导出 + RKNN 部署（RK3588），INT8 量化和部署