# x86 宿主机构建 ARM64 Ubuntu 24\.04 rootfs 报错解决记录

# 一、问题现象

## 环境

- 宿主机：VMware Ubuntu 20\.04（x86\_64，内核 6\.6）

- 构建方式：通过 debootstrap \+ qemu\-user\-static 在 chroot 环境中构建 ARM64 架构的 Ubuntu 24\.04 \(Noble\) rootfs

## 错误信息

```bash
Setting up systemd (255.4-1ubuntu8) ...
Failed to take /etc/passwd lock: Invalid argument
dpkg: error processing package systemd (--configure):
 installed systemd package post-installation script subprocess returned error exit status 1
```

该问题发生在 debootstrap \-\-second\-stage 阶段，systemd 包的 postinst 脚本执行时触发。systemd 包配置失败后，整个构建过程卡死，无法继续安装其他包。

# 二、根本原因分析

## 2\.1 systemd v254 移除了 OFD 锁的 fallback 机制

在 systemd v253 及更早版本中，文件锁的实现逻辑是：先尝试 Linux 特有的 fcntl\(F\_OFD\_SETLKW\)（OFD 锁），如果失败（返回 EINVAL），则回退到传统的 POSIX flock\(F\_SETLKW\)。

从 systemd v254 开始，这个 fallback 被彻底移除（commit ed70a34ec0）。systemd 现在硬性要求底层环境必须支持 F\_OFD\_SETLKW。受影响的版本包括 Ubuntu 24\.04 自带的 systemd 255\.4\-1ubuntu8\.1。

关键时间点：该问题于 2024年6月5日 systemd 版本 255\.4\-1ubuntu8\.1 发布后开始被大规模报告。

## 2\.2 qemu\-user\-static 不支持 OFD 锁

QEMU 的用户态模拟（linux\-user）不支持 Open File Description \(OFD\) 锁。在 linux\-user/syscall\.c 中，target\_to\_host\_fcntl\_cmd 函数没有处理 F\_OFD\_SETLK / F\_OFD\_SETLKW / F\_OFD\_GETLK 的 case 分支，任何调用都直接返回 EINVAL。

QEMU Bug \#1893010 于 2020 年 8 月报告，有人在 2020 年提交了补丁（qemu\-5\.0\.0\-ofd\-fcntl\.patch），但至今未被合并到 QEMU 主线，状态仍为 New。

## 2\.3 报错调用链

```text
systemd.postinst
  ↓
pwconv (shadow-utils 包)
  ↓
libshadow.so → pw_lock()
  ↓
fcntl(F_OFD_SETLKW) → qemu-user-static 不支持 → 返回 EINVAL
```

注意：这是一个常见的认知误区。很多网上教程说"替换 /bin/systemd\-sysusers 为 echo 可解决"，但这个方案只适用于 WSL1 环境（报错来自 systemd\-sysusers 本身）。在 qemu\-user\-static \+ chroot 场景下，报错来自 pwconv → libshadow\.so，替换 systemd\-sysusers 完全无效。

# 三、尝试过的无效方案（踩坑记录）

## 3\.1 替换 /bin/systemd\-sysusers 为 echo

操作：

```bash
cd /bin && mv -f systemd-sysusers systemd-sysusers.org && ln -s echo systemd-sysusers
```

结果：无效。报错来自 pwconv，不是 systemd\-sysusers。该方案只适用于 WSL1 环境下 systemd\-sysusers 自身报错的场景。

## 3\.2 修改 postinst 脚本，在 systemd\-sysusers 后添加 \|\| true

操作：

```bash
find /var/lib/dpkg/info -name "*.postinst" -exec sed -i 's/systemd-sysusers/systemd-sysusers || true/g' {} \;
```

结果：无效。systemd\.postinst 中 pwconv 在 systemd\-sysusers 之前执行，脚本在 pwconv 行就报错退出了，根本跑不到 systemd\-sysusers。

## 3\.3 预创建 systemd 所需用户和组

操作：在 \-\-customize\-hook 中手动写入 /etc/group、/etc/passwd、/etc/shadow。

结果：无效。报错来自 pwconv → libshadow\.so → pw\_lock\(\) → fcntl\(F\_OFD\_SETLKW\)，预创建用户绕不过这个锁调用。

## 3\.4 升级宿主机 QEMU 到 8\.0\.x（分场景有效）

Ask Ubuntu 上有用户报告通过 backports 升级 QEMU 到 8\.0\.x 解决了问题。但该方案有以下限制：

适用场景：

- 宿主机直接 chroot 构建，文件系统为普通 ext4/btrfs 等

- 宿主机 Ubuntu 20\.04 通过 backports 升级到 8\.0\.x

不适用场景：

- Docker overlay2 存储驱动环境下

- 即使升级到 8\.0\.x，QEMU 官方 OFD 锁补丁（2020 年提交）从未被合并到主线，因此升级版本不一定保证解决

操作命令：

```bash
sudo add-apt-repository ppa:canonical-server/server-backports
sudo apt-get update
sudo apt-get upgrade qemu-user-static
```

## 3\.5 使用 multiarch/qemu\-user\-static \-\-reset \-p yes

操作：

```bash
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
```

结果：无效。该命令只修复 binfmt 注册（解决"找不到 arm64 解释器"的问题），不修复 QEMU TCG 中 struct flock 跨架构 ABI 转换的缺陷。该方案仅在 Docker 环境下被尝试，属于坑点之一。

## 3\.6 使用 ischroot 技巧

操作：在 \-\-essential\-hook 中将 /usr/bin/ischroot 链接到 /bin/false。

结果：无效。systemd\.postinst 没有用 ischroot 保护 pwconv 调用，ischroot 返回什么都无法阻止 pwconv 执行。

# 四、最终可行的方案

## 4\.1 方案一：升级宿主机的 QEMU（有限场景）

在宿主机 Ubuntu 20\.04 上，通过 backports 将 QEMU 升级到 8\.0\.x 版本，可能解决该问题。此方案仅在宿主机直接 chroot 构建（非 Docker 环境）且文件系统为普通 ext4/btrfs（非 overlay2）时可能有效。在 Docker overlay2 环境下，该方案无效。

### 4\.1\.1 方法一：通过 backports PPA 升级

```bash
sudo add-apt-repository ppa:canonical-server/server-backports
sudo apt-get update
sudo apt-get upgrade qemu-user-static
```

### 4\.1\.2 方法二：手动安装 8\.0\.4 定制版 deb 包

定制版 qemu\-user\-static 与 binfmt\-support 包存在冲突。binfmt\-support 提供 SysVinit 启动脚本 /etc/init\.d/binfmt\-support，而定制版提供 systemd 服务单元 /lib/systemd/system/systemd\-binfmt\.service，两者执行顺序会导致 systemd 设置被覆盖。因此需要先移除 binfmt\-support，再安装定制版。

```bash
# 1. 移除冲突的 binfmt-support
sudo apt-get purge binfmt-support -y

# 2. 下载 8.0.4 定制版 deb 包
wget https://archive.spacemit.com/qemu/qemu-user-static_8.0.4%2Bdfsg-1ubuntu3.23.10.1_amd64.deb

# 3. 安装 deb 包
sudo dpkg -i qemu-user-static_8.0.4+dfsg-1ubuntu3.23.10.1_amd64.deb

# 4. 重启 systemd-binfmt 服务，将 qemu-user-static 注册到内核
sudo systemctl restart systemd-binfmt.service
```

### 4\.1\.3 验证安装

```bash
qemu-aarch64-static --version
# 应显示类似 8.0.4 的版本号
```

注意：QEMU 官方 OFD 锁补丁（2020 年提交）从未被合并到 QEMU 主线，因此升级到 8\.0\.x 并不保证在所有环境下都能解决该问题。

**本次移植过程就是通过这个解决的！** 升级宿主机的 QEMU

## 4\.2 方案二：替换 pwconv（chroot \+ qemu\-user\-static 场景）

在 debootstrap \-\-second\-stage 执行之前，在宿主机上直接替换 chroot 内的 /usr/sbin/pwconv：

```bash
ROOTFS="$HOME/ubuntu_rootfs"

# 备份原 pwconv
sudo mv "$ROOTFS/usr/sbin/pwconv" "$ROOTFS/usr/sbin/pwconv.real"

# 替换为空操作脚本
sudo bash -c 'printf "#!/bin/sh\nexit 0\n" > '"$ROOTFS/usr/sbin/pwconv"
sudo chmod +x "$ROOTFS/usr/sbin/pwconv"

# 然后执行 debootstrap --second-stage
sudo chroot "$ROOTFS" /debootstrap/debootstrap --second-stage
```

原理：pwconv 被替换为空操作后，systemd\.postinst 调用 pwconv 时直接返回成功，不会触发 F\_OFD\_SETLKW 锁。

代价：pwconv 永久返回 0，/etc/shadow 和 /etc/passwd 不同步。需要在目标系统首次启动后执行一次真实的 pwconv。

## 4\.3 方案三：修改 systemd 源码（唯一真正的修复）

Launchpad Bug \#2069555 中明确指出：

"The only real fix for this issue is a modified systemd package which changes the locking mechanism\."

具体修改位置：src/basic/lock\-util\.c 中 fcntl\_lock\(\) 和 fcntl\_unlockpp\(\) 调用的 ofd 参数，从 true 改为 false。或者增加检测逻辑：检测到 F\_OFD\_SETLKW 不支持时，自动回退到 F\_SETLKW。

这个方案需要自行修改源码并重新编译 systemd 包，操作复杂但能根本解决问题。

## 4\.4 方案四：改用完整虚拟机 qemu\-system\-aarch64

放弃 qemu\-user\-static，改用 qemu\-system\-aarch64 完整系统模拟。虚拟机内部运行完整的 ARM64 内核，原生支持 F\_OFD\_SETLKW，不存在模拟缺陷。这是最可靠但速度最慢的方案。

# 五、官方 Bug 追踪链接

|来源|链接|状态|
|---|---|---|
|Ubuntu Launchpad|Bug \#2069555|Confirmed|
|QEMU|Bug \#1893010|New|
|Debian|Bug \#1126304|fixed\-upstream|
|systemd GitHub|Issue \#29512|公开讨论|
|Microsoft/WSL|Issue \#10397|公开讨论|
|GitHub Workaround|InfoXMax/linux\-apt\-fix\-broken\-issue|社区方案|

核心结论：该问题的根源是 systemd v254\+ 硬性要求 F\_OFD\_SETLKW，而 qemu\-user\-static 不支持该锁。systemd 和 QEMU 两边都未修复此问题，只能通过 workaround 绕过。升级 QEMU 在 Docker overlay2 环境下无效，在宿主机直接 chroot 环境下可能有效，但需验证文件系统类型。


