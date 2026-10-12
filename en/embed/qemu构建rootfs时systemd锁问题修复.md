<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2026 KY (kyshipit)
-->

# Troubleshooting a rootfs error when building an ARM64 Ubuntu 24.04 rootfs on an x86 host machine.

When building an ARM64 Ubuntu 24.04 rootfs on an x86 host machine, the systemd postinst script failed because qemu-user-static did not support OFD locks. This was resolved by upgrading QEMU to 8.0.x.

# I. Problem Phenomenon

## environment

- Host machine: VMware Ubuntu 20.04 (x86_64, kernel 6.6)

- Build method: Build an ARM64 architecture Ubuntu 24.04 (Noble) rootfs in the chroot environment using debootstrap + qemu-user-static.

## error message

```bash
Setting up systemd (255.4-1ubuntu8) ...
Failed to take /etc/passwd lock: Invalid argument
dpkg: error processing package systemd (--configure):
installed systemd package post-installation script subprocess returned error exit status 1
```

This issue occurs during the `debootstrap --second-stage` phase, triggered when the `postinst` script for the systemd package is executed. After the systemd package configuration fails, the entire build process freezes, preventing the installation of other packages.

# II. Root Cause Analysis

## 2.1 systemd v254 removed the fallback mechanism for OFD locks.

In systemd v253 and earlier versions, the file lock implementation logic is as follows:

1. First, try the Linux-specific fcntl(F_OFD_SETLKW) (OFD lock).

2. If it fails (returns EINVAL), it falls back to the traditional POSIX flock(F_SETLKW).

Starting with systemd v254, this fallback was **completely removed** (committed ed70a34ec0). **systemd now requires** the underlying environment to support F_OFD_SETLKW.

The affected versions include systemd 255.4-1ubuntu8.1, which comes with Ubuntu 24.04.

**Key timeline** : This issue began to be reported on a large scale after the release of systemd version 255.4-1ubuntu8.1 on June 5, 2024.

## 2.2 qemu-user-static does not support OFD locks.

- QEMU's user-space emulation (linux-user) **does not support** Open File Description (OFD) locks.

- In linux-user/syscall.c, the target_to_host_fcntl_cmd function does not handle the case branches for F_OFD_SETLK / F_OFD_SETLKW / F_OFD_GETLK, and any call to it directly returns EINVAL.

- QEMU Bug #1893010 was reported in August 2020. A patch (qemu-5.0.0-ofd-fcntl.patch) was submitted in 2020, but it has not been merged into the QEMU mainline and its status remains New.

## 2.3 Error Call Chain

```text
systemd.postinst
  ↓
pwconv (shadow-utils 包)
  ↓
libshadow.so → pw_lock()
  ↓
fcntl(F_OFD_SETLKW) → qemu-user-static 不支持 → 返回 EINVAL
```

Note: This is a common misconception. Many online tutorials say that "replacing /bin/systemd-sysusers with echo will solve the problem," but this solution only applies to WSL1 environments (where the error originates from systemd-sysusers itself). In the qemu-user-static + chroot scenario, the error originates from pwconv → libshadow.so, and replacing systemd-sysusers is completely ineffective.

# III. Ineffective Solutions Tried (Pitfalls)

## 3.1 Replace /bin/systemd-sysusers with echo

operate:

```bash
cd /bin && mv -f systemd-sysusers systemd-sysusers.org && ln -s echo systemd-sysusers
```

Result: ❌ Invalid. The error originated from pwconv, not systemd-sysusers. This solution only applies to scenarios where systemd-sysusers itself throws an error in a WSL1 environment.

## 3.2 Modify the postinst script by adding || true after systemd-sysusers.

operate:

```bash
find /var/lib/dpkg/info -name "*.postinst" -exec sed -i 's/systemd-sysusers/systemd-sysusers || true/g' {} \;
```

Result: ❌ Invalid. In systemd.postinst, pwconv executes before systemd-sysusers, and the script exits with an error at the pwconv line, so it never reaches systemd-sysusers.

## 3.3 Pre-create the users and groups required for systemd

Operation: Manually add /etc/group, /etc/passwd, and /etc/shadow to the --customize-hook configuration.

Result: ❌ Invalid. The error originates from pwconv → libshadow.so → pw_lock() → fcntl(F_OFD_SETLKW), which is an unavoidable lock call for pre-created users.

## 3.4 Upgrade the host machine's QEMU to version 8.0.x (applicable depending on the scenario)

On Ask Ubuntu, some users have reported that upgrading QEMU to 8.0.x via backports resolved the issue. However, this solution has the following limitations:

Applicable scenarios:

- The host machine directly uses chroot to build the system, and the file system is a regular ext4/btrfs, etc.

- The host machine, Ubuntu 20.04, was upgraded to 8.0.x via backports.

Not applicable scenarios:

- The host Ubuntu version cannot obtain QEMU 8.0.x (such as Ubuntu 18.04 or earlier) through backports.

## 3.5 Use multiarch/qemu-user-static --reset -p yes

operate:

```bash
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
```

Result: ❌ Invalid. This command only fixes binfmt registration (resolving the "arm64 interpreter not found" problem), but does not fix the defect in struct flock cross-architecture ABI conversion in QEMU TCG. This solution was only tried in a Docker environment and is considered a pitfall.

## 3.6 Using ischroot techniques

Action: In --essential-hook, link /usr/bin/ischroot to /bin/false.

Result: ❌ Invalid. systemd.postinst does not protect the pwconv call with ischroot, and the return value of ischroot cannot prevent pwconv from executing.

# IV. The final feasible solution

## 4.1 Option 1: Upgrade the host machine's QEMU (✅ This option was used successfully in this case)

On the host machine Ubuntu 20.04, QEMU is upgraded to version 8.0.x via backports.

### 4.1.1 Method 1: Upgrade via Backports PPA

```bash
sudo add-apt-repository ppa:canonical-server/server-backports
sudo apt-get update
sudo apt-get upgrade qemu-user-static
# 升级后重启 systemd-binfmt 服务
sudo systemctl restart systemd-binfmt.service
qemu-aarch64-static --version
# 显示还是之前的版本，升级版本未成功
```

Method 1 **failed to upgrade** in this process, so Method 2 was used: manually installing the customized deb package.

### 4.1.2 Method 2: Manually install the 8.0.4 customized deb package

- The customized version of qemu-user-static conflicts with the binfmt-support package.

- binfmt-support provides the SysVinit startup script /etc/init.d/binfmt-support, while the customized version provides the systemd service unit /lib/systemd/system/systemd-binfmt.service. The execution order of the two can cause systemd settings to be overridden.

- Therefore, you need to remove binfmt-support first, and then install the customized version.

```bash
# 1. 移除冲突的 binfmt-support
sudo apt-get purge binfmt-support -y

# 2. 下载 8.0.4 定制版 deb 包
wget https://archive.spacemit.com/qemu/qemu-user-static_8.0.4%2Bdfsg-1ubuntu3.23.10.1_amd64.deb

# 3. 安装 deb 包
sudo dpkg -i qemu-user-static_8.0.4+dfsg-1ubuntu3.23.10.1_amd64.deb

# 4. 重启 systemd-binfmt 服务，将 qemu-user-static 注册到内核
sudo systemctl restart systemd-binfmt.service

# 5. 验证安装
qemu-aarch64-static --version
# 应显示类似 8.0.4 的版本号
```

The official QEMU OFD lock patch (submitted in 2020) was never merged into the QEMU mainline, but it still resolves the issue in actual testing after upgrading to 8.0.x.

**This porting process was solved using this method!** Upgrading the host machine's QEMU.

## 4.2 Option 2: Replace pwconv (chroot + qemu-user-static scenario)

Before executing `debootstrap --second-stage`, directly replace `/usr/sbin/pwconv` within chroot on the host machine:

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

Principle: After pwconv is replaced with a no-operation, when systemd.postinst calls pwconv, it returns success directly and does not trigger the F_OFD_SETLKW lock.

Cost: pwconv will permanently return 0, and /etc/shadow and /etc/passwd will become out of sync. A real pwconv operation needs to be performed after the target system's first boot.

## 4.3 Option 3: Modify the systemd source code

Launchpad Bug #2069555 clearly states:

> "The only real fix for this issue is a modified systemd package which changes the locking mechanism."

The specific modification location is in src/basic/lock-util.c, where the `ofd` parameter in the calls to `fcntl_lock()` and `fcntl_unlockpp()` should be changed from `true` to `false`. Alternatively, add detection logic: if `F_OFD_SETLKW` is detected as unsupported, automatically fall back to `F_SETLKW`.

Applicable scenario: This solution requires modifying the source code and recompiling the systemd package, which is complicated but can fundamentally solve the problem.

## 4.4 Option 4: Use a complete virtual machine qemu-system-aarch64 instead

Instead of qemu-user-static, we use qemu-system-aarch64 for complete system emulation. The virtual machine runs a complete ARM64 kernel, natively supports F_OFD_SETLKW, and has no emulation defects. This is the most reliable but slowest solution.

# V. Official Bug Tracking Link

source | Link | state
--- | --- | ---
Ubuntu Launchpad | [Bug #2069555](https://bugs.launchpad.net/ubuntu/+source/systemd/+bug/2069555) | Confirmed
QEMU | [Bug #1893010](https://bugs.launchpad.net/qemu/+bug/1893010) | New
Debian | [Bug #1126304](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1126304) | fixed-upstream
systemd GitHub | [Issue #29512](https://github.com/systemd/systemd/issues/29512) | Open discussion
Microsoft/WSL | [Issue #10397](https://github.com/microsoft/WSL/issues/10397) | Open discussion
GitHub Workaround | [InfoXMax/linux‑apt‑fix‑broken‑issue](https://github.com/InfoXMax/linux-apt-fix-broken-issue) | Community Plan

Key conclusion: The root cause of this issue is that systemd v254+ has a hard requirement for F_OFD_SETLKW, while qemu-user-static does not support this lock. Neither systemd nor QEMU has fixed this problem; it can only be circumvented through a workaround.

**The effective solution adopted this time** was to upgrade the host machine's QEMU to version 8.0.x.
