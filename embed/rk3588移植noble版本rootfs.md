# **Ubuntu 24.04 (Noble) 完整移植**

## 一、环境准备

```
sudo apt update
sudo apt install debootstrap qemu-user-static binfmt-support rsync -y
```

## 二、debootstrap --foreign

- 说明：noble 是 Ubuntu 24.04 的版本代号，22.04 为 jammy

```
mkdir-p ~/ubuntu_rootfs

sudo debootstrap --foreign --arch=arm64 noble ~/ubuntu_rootfs http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/
```

## 三、挂载 **+ second‑stage**

```
ROOTFS="$HOME/ubuntu_rootfs"

sudo mount --bind /dev "$ROOTFS/dev"
sudo mount --bind /dev/pts "$ROOTFS/dev/pts"
sudo mount --bind /proc "$ROOTFS/proc"
sudo mount --bind /sys "$ROOTFS/sys"

# 仅在debootstrap完成之后复制qemu
sudo cp /usr/bin/qemu-aarch64-static "$ROOTFS/usr/bin/"
sudo cp /etc/resolv.conf "$ROOTFS/etc/resolv.conf"

# second-stage 阶段进入chroot
sudo chroot "$ROOTFS" /debootstrap/debootstrap --second-stage      

sudo chroot "$ROOTFS" /bin/bash
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
```

## 四、chroot 内基础配置

### 4.1 配置软件源

bash

```
cat > /etc/apt/sources.list << 'EOF'
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ noble main restricted universe multiverse
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ noble-updates main restricted universe multiverse
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ noble-backports main restricted universe multiverse
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ noble-security main restricted universe multiverse
EOF
```

### 4.2 修复 /tmp 权限

```
chmod 777 /tmp
```

### 4.3 安装基础软件包

```
apt update

# 基础系统
apt install -y vim net-tools openssh-server sudo systemd locales \
    wpasupplicant wireless-tools \
    xfce4 xfce4-goodies lightdm \
    alsa-utils pulseaudio v4l-utils

# 开发工具
apt install -y python3-pip git cmake python3-dev python3-numpy python3-yaml python3-colcon-common-extensions

# GStreamer 工具（摄像头预览和流触发）
apt install -y gstreamer1.0-tools gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly

# USB Gadget 依赖
apt install -y psmisc   # 提供 fuser 命令
```

### 4.4 配置 DNS

```
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 114.114.114.114" >> /etc/resolv.conf
```

### 4.5 清空 root 密码

```
passwd -d root
```

### 4.6 配置系统自动登录及 SSH 远程登录

```
# ---------- 串口自动登录 ----------
sudo mkdir -p /etc/systemd/system/serial-getty@ttyFIQ0.service.d
cat > /etc/systemd/system/serial-getty@ttyFIQ0.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty -a root --keep-baud 115200 %I $TERM
EOF

# ---------- LightDM 图形界面自动登录 ----------
cat > /etc/lightdm/lightdm.conf << 'EOF'
[Seat:*]
autologin-user=root
autologin-user-timeout=0
allow-root=true
greeter-session=lightdm-gtk-greeter
EOF

# ---------- SSH 配置（支持 root 密码 + 密钥双模式登录） ----------
# 备份原配置
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# 修改关键参数
sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
# 如果原文件没有这些行，追加
grep -q "^PermitRootLogin" /etc/ssh/sshd_config || echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
grep -q "^PubkeyAuthentication" /etc/ssh/sshd_config || echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
grep -q "^PasswordAuthentication" /etc/ssh/sshd_config || echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
# 确保没有设置 DenyUsers 或 DenyGroups 阻止 root
sed -i '/^DenyUsers/d' /etc/ssh/sshd_config
sed -i '/^DenyGroups/d' /etc/ssh/sshd_config

# ---------- 主机名 ----------
echo "ATK-DLRK3588" > /etc/hostname
sed -i '/127.0.1.1/d' /etc/hosts
echo "127.0.1.1 ATK-DLRK3588" >> /etc/hosts

# ---------- 登录目录和 PS1 ----------
echo 'cd /' >> /root/.profile
echo 'export PS1="\\u@\\h:\\w\\$ "' >> /root/.bashrc

# ---------- 屏蔽网络等待服务 ----------
ln -sf /dev/null /etc/systemd/system/NetworkManager-wait-online.service
```

### 4.7 配置 bashrc

```
cat > /root/.bashrc << 'EOF'
# 串口 ttyFIQ0 显示修复
if [[ "$(tty)" == "/dev/ttyFIQ0" ]]; then
    stty -ixon -ixoff
    setterm -linewrap on
    export TERM=xterm
    shopt -s checkwinsize
fi

# ls 彩色配置
export LS_OPTIONS='--color=auto'
eval "`dircolors`"
alias ls='ls $LS_OPTIONS'
alias ll='ls $LS_OPTIONS -lh'
alias la='ls $LS_OPTIONS -lha'

# 命令提示符
PS1="\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]# "

# 历史记录
export HISTSIZE=2000
export HISTCONTROL=ignoredups
shopt -s histappend

# 常用别名
alias cls='clear'
alias df='df -h'
alias free='free -h'

# bash 自动补全
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  fi
fi
EOF
```

### 4.8 禁用休眠

```
cat > /etc/systemd/system/disable-suspend.service << 'EOF'
[Unit]
Description=Disable all suspend and cpuidle
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/bash /usr/local/bin/no_suspend.sh

[Install]
WantedBy=multi-user.target
EOF

cat > /usr/local/bin/no_suspend.sh << 'EOF'
#!/bin/bash
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0
gsettings set org.gnome.settings-daemon.plugins.power sleep-display-ac 0
gsettings set org.gnome.settings-daemon.plugins.power sleep-display-battery 0
gsettings set org.gnome.settings-daemon.plugins.power screen-blank-delay-ac 0
gsettings set org.gnome.settings-daemon.plugins.power screen-blank-delay-battery 0

for state in /sys/devices/system/cpu/cpu0/cpuidle/state*/disable; do
    echo 1 > "$state"
done

systemctl mask --now sleep.target suspend.target hibernate.target hybrid-sleep.target
exit 0
EOF

chmod 755 /usr/local/bin/no_suspend.sh
chmod 644 /etc/systemd/system/disable-suspend.service
ln -sf /etc/systemd/system/disable-suspend.service /etc/systemd/system/multi-user.target.wants/disable-suspend.service

echo "IdleAction=ignore" >> /etc/systemd/logind.conf
echo "IdleActionSec=0" >> /etc/systemd/logind.conf
```

### 4.9 创建 systemd 服务（USB Gadget + ISP 3A）

```
# ---------- USB Gadget 服务 ----------
cat > /etc/systemd/system/usbdevice.service << 'EOF'
[Unit]
Description=Rockchip USB Gadget Service
After=sysfs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/usbdevice start
RemainAfterExit=yes
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target
EOF

ln -sf /etc/systemd/system/usbdevice.service /etc/systemd/system/multi-user.target.wants/usbdevice.service

# ---------- 摄像头流服务（ISP 3A 需要持续流触发） ----------
cat > /etc/systemd/system/camera-stream.service << 'EOF'
[Unit]
Description=Camera stream trigger for ISP 3A
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/bin/gst-launch-1.0 v4l2src device=/dev/video-camera0 ! video/x-raw,width=1920,height=1080,format=NV12 ! fakesink -e
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl enable camera-stream.service
```

### 4.10 创建首次开机扩容脚本

```
# 首次开机扩容脚本
cat > /usr/local/bin/firstboot-setup.sh << 'EOF'
#!/bin/sh
FLAG_FILE="/var/lib/firstboot-done"

if [ -f "$FLAG_FILE" ]; then
    exit 0
fi

# 扩容根分区文件系统
ROOT_DEV=$(findmnt -n -o SOURCE /)
if [ -b "$ROOT_DEV" ]; then
    resize2fs "$ROOT_DEV"
fi

# userdata 分区处理
USERDATA_DEV="/dev/mmcblk0p8"
if [ -b "$USERDATA_DEV" ]; then
    if ! blkid "$USERDATA_DEV" | grep -q ext4; then
        mkfs.ext4 -F -m 0 -L userdata "$USERDATA_DEV"
    else
        resize2fs "$USERDATA_DEV"
    fi
fi

mkdir -p "$(dirname "$FLAG_FILE")"
touch "$FLAG_FILE"
systemctl disable firstboot-setup.service
EOF

chmod +x /usr/local/bin/firstboot-setup.sh

cat > /etc/systemd/system/firstboot-setup.service << 'EOF'
[Unit]
Description=First boot setup
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/firstboot-setup.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

ln -sf /etc/systemd/system/firstboot-setup.service /etc/systemd/system/multi-user.target.wants/firstboot-setup.service
```

### 4.11 配置挂载点

```
mkdir -p /userdata
echo "/dev/mmcblk0p8  /userdata  ext4  defaults,nofail,noatime  0  2" >> /etc/fstab
```

### 4.12 安装 camera-engine-rkaiq（ISP 3A 服务）

```
# 安装 deb 包
dpkg -i /tmp/camera_engine_rkaiq_rk3588_arm64.deb
apt-get install -f -y   # 修复依赖

# 启用 3A 服务
systemctl enable rkaiq_3A.service
```

### 4.13 退出 chroot

```
exit
```

## 五、从 Buildroot 复制硬件文件（在 chroot 外执行）

bash

```
BUILDROOT_DIR=~/atk_dlrk3588_linux6.1/buildroot/output/alientek_rk3588/target
UBUNTU_ROOT=~/ubuntu_rootfs

# ---------- 5.1 复制固件 ----------
sudo mkdir -p ${UBUNTU_ROOT}/lib/firmware
sudo cp -a ${BUILDROOT_DIR}/lib/firmware/* ${UBUNTU_ROOT}/lib/firmware/

# ---------- 5.2 复制内核模块 ----------
sudo mkdir -p ${UBUNTU_ROOT}/lib/modules/6.1.141
sudo cp -a ${BUILDROOT_DIR}/lib/modules/6.1.141/* ${UBUNTU_ROOT}/lib/modules/6.1.141/

# ---------- 5.3 复制第三方动态库（排除系统核心库） ----------
sudo rsync -av --exclude='libc.so*' \
               --exclude='libpthread.so*' \
               --exclude='libdl.so*' \
               --exclude='libm.so*' \
               --exclude='libresolv.so*' \
               --exclude='libnss_*.so*' \
               --exclude='libutil.so*' \
               --exclude='librt.so*' \
               --exclude='libanl.so*' \
               --exclude='libthread_db.so*' \
               --exclude='ld-linux-aarch64.so*' \
               ${BUILDROOT_DIR}/usr/lib/*.so* \
               ${UBUNTU_ROOT}/usr/lib/

# ---------- 5.4 复制 USB Gadget ----------
sudo cp -a ${BUILDROOT_DIR}/usr/bin/usbdevice ${UBUNTU_ROOT}/usr/bin/
sudo cp -a ${BUILDROOT_DIR}/usr/bin/adbd ${UBUNTU_ROOT}/usr/bin/
sudo cp -a ${BUILDROOT_DIR}/usr/bin/usb-gadget ${UBUNTU_ROOT}/usr/bin/
sudo chmod +x ${UBUNTU_ROOT}/usr/bin/usbdevice ${UBUNTU_ROOT}/usr/bin/adbd ${UBUNTU_ROOT}/usr/bin/usb-gadget

sudo cp -a ${BUILDROOT_DIR}/etc/usbdevice.d/ ${UBUNTU_ROOT}/etc/
sudo cp -a ${BUILDROOT_DIR}/etc/usb-gadget.d/ ${UBUNTU_ROOT}/etc/
sudo cp -a ${BUILDROOT_DIR}/usr/lib/udev/rules.d/61-usb-gadget.rules ${UBUNTU_ROOT}/usr/lib/udev/rules.d/

# USB Gadget 环境变量脚本
sudo cp -a ${BUILDROOT_DIR}/etc/profile.d/adbd.sh ${UBUNTU_ROOT}/etc/profile.d/
sudo cp -a ${BUILDROOT_DIR}/etc/profile.d/usb-gadget.sh ${UBUNTU_ROOT}/etc/profile.d/

# U盘自动挂载（可选）
sudo cp -a ${BUILDROOT_DIR}/etc/usbmount ${UBUNTU_ROOT}/etc/
sudo cp -a ${BUILDROOT_DIR}/usr/share/usbmount ${UBUNTU_ROOT}/usr/share/

# ---------- 5.5 复制无线工具 ----------
sudo cp -a ${BUILDROOT_DIR}/usr/sbin/rfkill ${UBUNTU_ROOT}/usr/sbin/
sudo cp -a ${BUILDROOT_DIR}/usr/sbin/iw ${UBUNTU_ROOT}/usr/sbin/
sudo cp -a ${BUILDROOT_DIR}/usr/sbin/wpa_supplicant ${UBUNTU_ROOT}/usr/sbin/
sudo cp -a ${BUILDROOT_DIR}/usr/bin/wpa_passphrase ${UBUNTU_ROOT}/usr/bin/
sudo cp -a ${BUILDROOT_DIR}/usr/sbin/connmand ${UBUNTU_ROOT}/usr/sbin/
sudo cp -a ${BUILDROOT_DIR}/usr/bin/connmanctl ${UBUNTU_ROOT}/usr/bin/

# ---------- 5.6 复制 camera-engine-rkaiq deb 包 ----------
sudo mkdir -p ${UBUNTU_ROOT}/tmp
sudo cp -a ~/atk_dlrk3588_linux6.1/debian/packages/arm64/rkaiq/camera_engine_rkaiq_rk3588_arm64.deb ${UBUNTU_ROOT}/tmp/

# ---------- 5.7 复制 IQ 配置文件 ----------
sudo mkdir -p ${UBUNTU_ROOT}/etc/iqfiles
sudo cp -a ${BUILDROOT_DIR}/etc/iqfiles/*.json ${UBUNTU_ROOT}/etc/iqfiles/

# ---------- 5.8 复制摄像头 udev 规则 ----------
sudo cp -a ${BUILDROOT_DIR}/usr/lib/udev/rules.d/70-camera.rules ${UBUNTU_ROOT}/usr/lib/udev/rules.d/
sudo cp -a ${BUILDROOT_DIR}/usr/lib/udev/rules.d/88-rockchip-camera.rules ${UBUNTU_ROOT}/usr/lib/udev/rules.d/
sudo cp -a ${BUILDROOT_DIR}/usr/lib/udev/rules.d/99-rockchip-permissions.rules ${UBUNTU_ROOT}/usr/lib/udev/rules.d/
sudo cp -a ${BUILDROOT_DIR}/usr/lib/udev/rules.d/99-usb-camera.rules ${UBUNTU_ROOT}/usr/lib/udev/rules.d/

# ---------- 5.9 复制摄像头环境变量 ----------
sudo tee ${UBUNTU_ROOT}/etc/profile.d/rk-camera.sh > /dev/null << 'EOF'
export GST_V4L2SRC_DEFAULT_DEVICE=/dev/video-camera0
export GST_V4L2_PREFERRED_FOURCC=NV12:YU12:NV16:YUY2
export GST_VIDEO_CONVERT_PREFERRED_FORMAT=NV12:NV16:I420:YUY2
export GST_V4L2_USE_LIBV4L2=1
export GST_V4L2SRC_RK_DEVICES=_mainpath:_selfpath:_bypass:_scale
EOF
sudo chmod 644 ${UBUNTU_ROOT}/etc/profile.d/rk-camera.sh
```

## 六、卸载挂载点（关键步骤）

```
ROOTFS="$HOME/ubuntu_rootfs"

sudo umount "$ROOTFS/dev/pts" 2>/dev/null
sudo umount "$ROOTFS/dev" 2>/dev/null
sudo umount "$ROOTFS/proc" 2>/dev/null
sudo umount "$ROOTFS/sys" 2>/dev/null

# 检查是否还有残留挂载
mount | grep ubuntu_rootfs
```

## 七、创建 rootfs.img 并打包

```
# 7.1 计算镜像大小（加 30% 冗余）
ROOTFS_SIZE=$(sudo du -sm ~/ubuntu_rootfs | cut -f1)
ROOTFS_SIZE=$((ROOTFS_SIZE * 13 / 10))
echo "镜像大小: ${ROOTFS_SIZE} MB"

# 7.2 创建镜像
dd if=/dev/zero of=~/rootfs.img bs=1M count=$ROOTFS_SIZE status=progress
mkfs.ext4 -F ~/rootfs.img

# 7.3 挂载并复制
mkdir -p ~/rootfs_mount
sudo mount ~/rootfs.img ~/rootfs_mount
sudo rsync -av ~/ubuntu_rootfs/ ~/rootfs_mount/
sudo umount ~/rootfs_mount

# 7.4 替换 SDK 中的 rootfs.img
sudo cp ~/rootfs.img ~/atk_dlrk3588_linux6.1/output/firmware/rootfs.img
sudo cp ~/rootfs.img ~/atk_dlrk3588_linux6.1/output/update/Image/rootfs.img

# 7.5 打包完整 update.img
cd ~/atk_dlrk3588_linux6.1 && ./build.sh updateimg
```

## 八、烧录验证

使用 RKDevTool_Release工具烧录，烧录后验证。

| 功能         | 验证命令                                                     |
| ------------ | ------------------------------------------------------------ |
| GLIBC 兼容性 | ./edgeai_app 不再报 GLIBC_2.38 not found                     |
| ISP 状态     | cat /proc/rkisp*                                             |
| 摄像头预览   | gst-launch-1.0 v4l2src device=/dev/video-camera0 ! video/x-raw,width=1920,height=1080,format=NV12 ! videoconvert ! autovideosink |
| ADB          | adb devices                                                  |
| 无线         | connmanctl                                                   |
| SSH          | 从远程 PC 执行 ssh root@板子IP 测试密码登录和密钥登录        |


## 九、与 Ubuntu 22.04 移植的关键差异总结

| 项目                 | Ubuntu 22.04 (Jammy)  | Ubuntu 24.04 (Noble)        |
| -------------------- | --------------------- | --------------------------- |
| debootstrap 版本代号 | jammy                 | noble                       |
| 软件源路径           | /ubuntu-ports/ jammy  | /ubuntu-ports/ noble        |
| ROS2 版本            | Humble / Rolling      | Jazzy                       |
| GLIBC 版本           | 2.35                  | 2.39                        |
| 工具链兼容性         | Buildroot 2.38 不兼容 | Buildroot 2.38 **完全兼容** |
| 其他步骤             | 完全相同              | 完全相同                    |