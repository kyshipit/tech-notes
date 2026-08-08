#!/bin/bash
set -e

UBUNTU_ROOT="$HOME/ubuntu_rootfs"
BUILDROOT_DIR="$HOME/atk_dlrk3588_linux6.1/buildroot/output/alientek_rk3588/target"
KERNEL_VERSION="6.1.141"
RKAIQ_DEB="$HOME/atk_dlrk3588_linux6.1/debian/packages/arm64/rkaiq/camera_engine_rkaiq_rk3588_arm64.deb"



# 步骤标记目录（位于宿主机，用于记录已完成的步骤，避免重复执行）

STEP_DIR="$HOME/.ubuntu_rootfs_steps"
mkdir -p "$STEP_DIR"

step_done() { [ -f "$STEP_DIR/$1" ]; }
mark_step_done() { touch "$STEP_DIR/$1"; }

echo "================================================================"
echo "前置检查"
echo "================================================================"

if ! command -v rsync &> /dev/null; then
    echo "错误: rsync 未安装"
    exit 1
fi

if [ ! -d "$UBUNTU_ROOT" ]; then
    echo "错误: Ubuntu rootfs 目录不存在: $UBUNTU_ROOT"
    exit 1
fi

if [ ! -d "$BUILDROOT_DIR" ]; then
    echo "错误: Buildroot 目录不存在: $BUILDROOT_DIR"
    exit 1
fi

# ================================================================
# 步骤 1: 从 Buildroot 复制硬件文件
# ================================================================

if step_done "step1_copy_buildroot"; then
    echo "步骤1已完成，跳过"
else
    echo "================================================================"
    echo "步骤 1: 从 Buildroot 复制硬件相关文件"
    echo "================================================================"

    sudo mkdir -p ${UBUNTU_ROOT}/lib/firmware
    sudo mkdir -p ${UBUNTU_ROOT}/lib/modules/${KERNEL_VERSION}
    sudo mkdir -p ${UBUNTU_ROOT}/usr/lib
    sudo mkdir -p ${UBUNTU_ROOT}/etc/iqfiles
    sudo mkdir -p ${UBUNTU_ROOT}/tmp
    sudo mkdir -p ${UBUNTU_ROOT}/etc/profile.d
    sudo mkdir -p ${UBUNTU_ROOT}/usr/lib/udev/rules.d

    echo "[1.1] 复制固件"
    sudo cp -a ${BUILDROOT_DIR}/lib/firmware/* ${UBUNTU_ROOT}/lib/firmware/

    echo "[1.2] 复制内核模块"
    sudo cp -a ${BUILDROOT_DIR}/lib/modules/${KERNEL_VERSION}/* ${UBUNTU_ROOT}/lib/modules/${KERNEL_VERSION}/

    echo "[1.3] 复制第三方动态库"
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

    echo "[1.4] 复制 USB Gadget 文件"
    sudo cp -a ${BUILDROOT_DIR}/usr/bin/usbdevice ${UBUNTU_ROOT}/usr/bin/
    sudo cp -a ${BUILDROOT_DIR}/usr/bin/adbd ${UBUNTU_ROOT}/usr/bin/
    sudo cp -a ${BUILDROOT_DIR}/usr/bin/usb-gadget ${UBUNTU_ROOT}/usr/bin/
    sudo chmod +x ${UBUNTU_ROOT}/usr/bin/usbdevice ${UBUNTU_ROOT}/usr/bin/adbd ${UBUNTU_ROOT}/usr/bin/usb-gadget

    sudo cp -a ${BUILDROOT_DIR}/etc/usbdevice.d/ ${UBUNTU_ROOT}/etc/
    sudo cp -a ${BUILDROOT_DIR}/etc/usb-gadget.d/ ${UBUNTU_ROOT}/etc/
    sudo cp -a ${BUILDROOT_DIR}/usr/lib/udev/rules.d/61-usb-gadget.rules ${UBUNTU_ROOT}/usr/lib/udev/rules.d/
    sudo cp -a ${BUILDROOT_DIR}/etc/profile.d/adbd.sh ${UBUNTU_ROOT}/etc/profile.d/
    sudo cp -a ${BUILDROOT_DIR}/etc/profile.d/usb-gadget.sh ${UBUNTU_ROOT}/etc/profile.d/
    sudo cp -a ${BUILDROOT_DIR}/etc/usbmount ${UBUNTU_ROOT}/etc/
    sudo cp -a ${BUILDROOT_DIR}/usr/share/usbmount ${UBUNTU_ROOT}/usr/share/

    echo "[1.5] 复制无线工具"
    sudo cp -a ${BUILDROOT_DIR}/usr/sbin/rfkill ${UBUNTU_ROOT}/usr/sbin/
    sudo cp -a ${BUILDROOT_DIR}/usr/sbin/iw ${UBUNTU_ROOT}/usr/sbin/
    sudo cp -a ${BUILDROOT_DIR}/usr/sbin/wpa_supplicant ${UBUNTU_ROOT}/usr/sbin/
    sudo cp -a ${BUILDROOT_DIR}/usr/bin/wpa_passphrase ${UBUNTU_ROOT}/usr/bin/
    sudo cp -a ${BUILDROOT_DIR}/usr/sbin/connmand ${UBUNTU_ROOT}/usr/sbin/
    sudo cp -a ${BUILDROOT_DIR}/usr/bin/connmanctl ${UBUNTU_ROOT}/usr/bin/

    echo "[1.6] 复制 camera-engine-rkaiq deb 包"
    sudo cp -a "$RKAIQ_DEB" ${UBUNTU_ROOT}/tmp/

    echo "[1.7] 复制 IQ 配置文件"
    sudo cp -a ${BUILDROOT_DIR}/etc/iqfiles/*.json ${UBUNTU_ROOT}/etc/iqfiles/

    echo "[1.8] 复制摄像头 udev 规则"
    sudo cp -a ${BUILDROOT_DIR}/usr/lib/udev/rules.d/70-camera.rules ${UBUNTU_ROOT}/usr/lib/udev/rules.d/
    sudo cp -a ${BUILDROOT_DIR}/usr/lib/udev/rules.d/88-rockchip-camera.rules ${UBUNTU_ROOT}/usr/lib/udev/rules.d/
    sudo cp -a ${BUILDROOT_DIR}/usr/lib/udev/rules.d/99-rockchip-permissions.rules ${UBUNTU_ROOT}/usr/lib/udev/rules.d/
    sudo cp -a ${BUILDROOT_DIR}/usr/lib/udev/rules.d/99-usb-camera.rules ${UBUNTU_ROOT}/usr/lib/udev/rules.d/

    echo "[1.9] 创建摄像头环境变量"
    sudo tee ${UBUNTU_ROOT}/etc/profile.d/rk-camera.sh > /dev/null << 'EOF'
    export GST_V4L2SRC_DEFAULT_DEVICE=/dev/video-camera0
    export GST_V4L2_PREFERRED_FOURCC=NV12:YU12:NV16:YUY2
    export GST_VIDEO_CONVERT_PREFERRED_FORMAT=NV12:NV16:I420:YUY2
    export GST_V4L2_USE_LIBV4L2=1
    export GST_V4L2SRC_RK_DEVICES=_mainpath:_selfpath:_bypass:_scale
    EOF
    sudo chmod 644 ${UBUNTU_ROOT}/etc/profile.d/rk-camera.sh

    mark_step_done "step1_copy_buildroot"
    echo "步骤1完成"
    fi
    
    echo ""
    
# ================================================================
# 步骤 2: 挂载虚拟文件系统
# ================================================================

echo "================================================================"
echo "步骤 2: 挂载虚拟文件系统"
echo "================================================================"

if ! mountpoint -q ${UBUNTU_ROOT}/proc; then
    sudo mount --bind /proc ${UBUNTU_ROOT}/proc
else
    echo "/proc 已挂载"
fi

if ! mountpoint -q ${UBUNTU_ROOT}/sys; then
    sudo mount --bind /sys ${UBUNTU_ROOT}/sys
else
    echo "/sys 已挂载"
fi

if ! mountpoint -q ${UBUNTU_ROOT}/dev; then
    sudo mount --bind /dev ${UBUNTU_ROOT}/dev
else
    echo "/dev 已挂载"
fi

if ! mountpoint -q ${UBUNTU_ROOT}/dev/pts; then
    sudo mount --bind /dev/pts ${UBUNTU_ROOT}/dev/pts
else
    echo "/dev/pts 已挂载"
fi

echo "挂载完成"
echo ""

# ================================================================
# 步骤 3: chroot 内系统配置
# ================================================================

if step_done "step3_chroot_configure"; then
    echo "步骤3已完成，跳过"
else
    echo "================================================================"
    echo "步骤 3: chroot 内系统配置"
    echo "================================================================"



    sudo chroot ${UBUNTU_ROOT} /bin/bash << 'CHROOT_EOF'
set -e

export LC_ALL=C.UTF-8
export LANG=C.UTF-8

echo "  [3.1] 配置软件源"
cat > /etc/apt/sources.list << 'EOF'
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ noble main restricted universe multiverse
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ noble-updates main restricted universe multiverse
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ noble-backports main restricted universe multiverse
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ noble-security main restricted universe multiverse
EOF

echo "  [3.2] 修复 /tmp 权限"
chmod 777 /tmp

echo "  [3.3] 更新软件源"
apt update

echo "  [3.4] 安装基础包"
apt install -y vim net-tools openssh-server sudo systemd locales \
    wpasupplicant wireless-tools \
    xfce4 xfce4-goodies lightdm \
    alsa-utils pulseaudio v4l-utils \
    dbus-x11


echo "  [3.5] 安装开发工具"
apt install -y python3-pip git cmake python3-dev python3-numpy python3-yaml python3-colcon-common-extensions

echo "  [3.6] 安装 GStreamer 工具"
apt install -y gstreamer1.0-tools gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly

echo "  [3.7] 安装 USB Gadget 依赖"
apt install -y psmisc

echo "  [3.8] 配置 DNS"
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 114.114.114.114" >> /etc/resolv.conf

echo "  [3.9] 清空 root 密码"
passwd -d root

echo "  [3.10] 配置串口自动登录"
mkdir -p /etc/systemd/system/serial-getty@ttyFIQ0.service.d
cat > /etc/systemd/system/serial-getty@ttyFIQ0.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty -a root --keep-baud 115200 %I $TERM
EOF

echo "  [3.11] 配置 LightDM 自动登录"
cat > /etc/lightdm/lightdm.conf << 'EOF'
[Seat:*]
autologin-user=root
autologin-user-timeout=0
allow-root=true
user-session=xfce
greeter-session=lightdm-gtk-greeter
EOF
# 将 root 加入 nopasswdlogin 组
usermod -a -G nopasswdlogin root

echo "  [3.12] 配置 SSH"
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
grep -q "^PermitRootLogin" /etc/ssh/sshd_config || echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
grep -q "^PubkeyAuthentication" /etc/ssh/sshd_config || echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
grep -q "^PasswordAuthentication" /etc/ssh/sshd_config || echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
sed -i '/^DenyUsers/d' /etc/ssh/sshd_config
sed -i '/^DenyGroups/d' /etc/ssh/sshd_config

echo "  [3.13] 配置主机名"
echo "ATK-DLRK3588" > /etc/hostname
sed -i '/127.0.1.1/d' /etc/hosts
echo "127.0.1.1 ATK-DLRK3588" >> /etc/hosts

echo "  [3.14] 配置 root 登录目录"
echo 'cd /' >> /root/.profile
echo 'export PS1="\\u@\\h:\\w\\$ "' >> /root/.bashrc

echo "  [3.15] 屏蔽网络等待服务"
ln -sf /dev/null /etc/systemd/system/NetworkManager-wait-online.service

echo "  [3.16] 配置 bashrc"
cat > /root/.bashrc << 'EOF'
if [[ "$(tty)" == "/dev/ttyFIQ0" ]]; then
    stty -ixon -ixoff
    setterm -linewrap on
    export TERM=xterm
    shopt -s checkwinsize
fi

export LS_OPTIONS='--color=auto'
eval "`dircolors`"
alias ls='ls $LS_OPTIONS'
alias ll='ls $LS_OPTIONS -lh'
alias la='ls $LS_OPTIONS -lha'

PS1="\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]# "

export HISTSIZE=2000
export HISTCONTROL=ignoredups
shopt -s histappend

alias cls='clear'
alias df='df -h'
alias free='free -h'

if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  fi
fi
EOF

echo "  [3.17] 禁用休眠"
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

mkdir -p /usr/local/bin
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

echo "  [3.18] 创建 systemd 服务"
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

echo "  [3.19] 创建首次开机扩容脚本"
cat > /usr/local/bin/firstboot-setup.sh << 'EOF'
#!/bin/sh
FLAG_FILE="/var/lib/firstboot-done"

if [ -f "$FLAG_FILE" ]; then
    exit 0
fi

ROOT_DEV=$(findmnt -n -o SOURCE /)
if [ -b "$ROOT_DEV" ]; then
    resize2fs "$ROOT_DEV"
fi

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

echo "  [3.20] 配置 /userdata 挂载点"
mkdir -p /userdata
echo "/dev/mmcblk0p8  /userdata  ext4  defaults,nofail,noatime  0  2" >> /etc/fstab

echo "  [3.21] 安装 camera-engine-rkaiq"
dpkg -i /tmp/camera_engine_rkaiq_rk3588_arm64.deb
apt-get install -f -y
systemctl enable rkaiq_3A.service

echo "  [3.22] 清理临时文件"
rm -f /tmp/camera_engine_rkaiq_rk3588_arm64.deb

echo "  [3.23] 配置 ALSA 默认声卡"
cat > /etc/asound.conf << 'EOF'
pcm.!default {
    type hw
    card 1
}
ctl.!default {
    type hw
    card 1
}
EOF

echo "  [3.24] 配置音频开关开机自启"
cat > /etc/rc.local << 'EOF'
#!/bin/sh -e
amixer -c 1 cset "name='OUT1 Switch'" on
amixer -c 1 cset "name='OUT2 Switch'" on
exit 0
EOF
chmod +x /etc/rc.local

echo "  [3.25] 禁用 Xfce 电源管理和屏保"
# 移除 light-locker 和 xfce4-screensaver（如果存在）
apt remove -y light-locker xfce4-screensaver 2>/dev/null || true
# 禁用 Xfce 电源管理器的锁屏
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/lock-screen-suspend-hibernate --create -t bool -s false 2>/dev/null || true
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/lock-screen-on-sleep --create -t bool -s false 2>/dev/null || true
# 设置熄屏时间为 0（永不）
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/blank-on-ac --create -t uint -s 0 2>/dev/null || true
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/blank-on-battery --create -t uint -s 0 2>/dev/null || true
# 禁用 xfce4-screensaver（如果存在）
xfconf-query -c xfce4-screensaver -p /xfce4-screensaver/lock-enabled --create -t bool -s false 2>/dev/null || true
xfconf-query -c xfce4-screensaver -p /xfce4-screensaver/idle-timeout --create -t uint -s 0 2>/dev/null || true

echo "chroot 配置完成"
CHROOT_EOF

    mark_step_done "step3_chroot_configure"
    echo "步骤3完成"
fi

echo ""

# ================================================================
# 步骤 4: 卸载挂载点
# ================================================================

echo "================================================================"
echo "步骤 4: 卸载挂载点"
echo "================================================================"

if mountpoint -q ${UBUNTU_ROOT}/dev/pts; then
    sudo umount ${UBUNTU_ROOT}/dev/pts
else
    echo "/dev/pts 未挂载，跳过"
fi

if mountpoint -q ${UBUNTU_ROOT}/dev; then
    sudo umount ${UBUNTU_ROOT}/dev
else
    echo "/dev 未挂载，跳过"
fi

if mountpoint -q ${UBUNTU_ROOT}/proc; then
    sudo umount ${UBUNTU_ROOT}/proc
else
    echo "/proc 未挂载，跳过"
fi

if mountpoint -q ${UBUNTU_ROOT}/sys; then
    sudo umount ${UBUNTU_ROOT}/sys
else
    echo "/sys 未挂载，跳过"
fi

echo ""
echo "================================================================"
echo "完成！rootfs 位于: ${UBUNTU_ROOT}"
echo "================================================================"