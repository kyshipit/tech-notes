**English** | [简体中文](../../ros/WSL2-ROS2跨机通信问题.md)

<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2026 KY (kyshipit)
-->

# Troubleshooting and resolving incompatibility issues between WSL2 default NAT mode and ROS2 Fast DDS UDP multicast discovery.

## I. Problem Overview

This document describes how to implement ROS2 cross-machine communication between an RK3588 development board and WSL2 in a Windows 10 (22H2) + WSL2 (Ubuntu 24.04) environment. The development board runs a `camera_pub` node publishing the topic `/camera/image_raw`, which should be discoverable by WSL2 using the `ros2 topic list`. However, in actual testing, WSL2 failed to discover any nodes or topics from the development board.

The core issue is that WSL2's default NAT network mode is incompatible with ROS2's UDP multicast-based node discovery mechanism.

## II. Network Diagnosis

### 2.1 Network connectivity test results (overview)

Test Items | Order | result
:-- | :-- | :--
Development board → Windows ping | ping 192.168.1.100 | ✅ Pass, 0% loss
WSL2 → Development board ping | ping 192.168.1.200 | ✅ Pass, 0% loss
UDP unicast test | WSL2: `nc -u -l -p 11811` Development board: `echo "test" | nc -u 192.168.1.100 11811` | ❌ WSL2 not received
UDP multicast test | WSL2: ROS2 multicast receive; Development board: ROS2 multicast send | ❌ WSL2 not received
tcpdump packet capture | sudo tcpdump -i any udp -c 10 | ⚠️ Can capture internet packets, but not development board packets.

Conclusion: ICMP is working but UDP is not, indicating that network layer routing is normal, but transport layer UDP traffic is being blocked.

**IP Address Information Note** : This document uses the example IP address range 192.168.1.x. Please replace it with your actual IP address during actual deployment.

equipment | IP address | Subnet | illustrate
:-- | :-- | :-- | :--
Windows physical network adapter | 192.168.1.100 | 192.168.1.0/24 | Host machine main network interface
RK3588 Development Board | 192.168.1.200 | 192.168.1.0/24 | Devices on the same local area network
WSL2 (eth0) | 172.18.32.32 | 172.18.32.0/20 | WSL2 default NAT mode

Key finding: The WSL2 IP (172.18.32.32) is not on the same subnet as Windows (192.168.1.100) and the development board (192.168.1.200), which is the root cause of the communication failure.

### 2.2 Detailed Testing Process

#### 2.2.1 ICMP Connectivity Test

Development board → Windows:

```
root@rk3588:~# ping 192.168.1.100
PING 192.168.1.100 (192.168.1.100) 56(84) bytes of data.
64 bytes from 192.168.1.100: icmp_seq=1 ttl=128 time=10.1 ms
64 bytes from 192.168.1.100: icmp_seq=2 ttl=128 time=8.67 ms
64 bytes from 192.168.1.100: icmp_seq=3 ttl=128 time=4.74 ms
^C
--- 192.168.1.100 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss
```

WSL2 → Development Board:

```
$ ping 192.168.1.200
PING 192.168.1.200 (192.168.1.200) 56(84) bytes of data.
64 bytes from 192.168.1.200: icmp_seq=1 ttl=63 time=10.3 ms
64 bytes from 192.168.1.200: icmp_seq=2 ttl=63 time=10.6 ms
64 bytes from 192.168.1.200: icmp_seq=3 ttl=63 time=6.45 ms
^C
--- 192.168.1.200 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss
```

#### 2.2.2 UDP Unicast Test

WSL2 receiver:

```
$ nc -u -l -p 11811
（光标闪烁，等待接收，无任何输出）
```

Development board transmitter:

```
root@rk3588:~# echo "test" | nc -u 192.168.1.100 11811
root@rk3588:~#
（命令立即返回，无错误）
```

WSL2 output: No output, continuous waiting, can only be exited by pressing Ctrl+C.

#### 2.2.3 UDP Multicast Test

WSL2 receiver:

```
$ ros2 multicast receive
Waiting for UDP multicast datagram...
（持续等待，无任何接收提示）
```

Development board transmitter:

```
root@rk3588:~# ros2 multicast send
Sending one UDP multicast datagram...
root@rk3588:~#
（命令立即返回）
```

Result: The WSL2 client consistently displayed `Waiting for UDP multicast datagram...` , and no data was received.

#### 2.2.4 Using tcpdump to capture packets

```
$ sudo tcpdump -i any udp -c 10
tcpdump: data link type LINUX_SLL2
listening on any, link-type LINUX_SLL2, snapshot length 262144 bytes

21:12:17.935403 eth0 Out IP 172.18.32.32.41035 > 91.189.91.157.123: NTPv4
21:12:18.193430 eth0 In  IP 91.189.91.157.123 > 172.18.32.32.41035: NTPv4
（继续等待，无开发板包出现）
^C
```

Result: WSL2 can receive Internet NTP unicast packets, but cannot receive any UDP packets from the development board.

### 2.3 Diagnostic Conclusion

Test Items | result | Detailed diagnostic instructions
:-- | :-- | :--
ICMP connectivity | ✅ Pass | Network layer routing is normal, links between devices are unobstructed, there is no packet loss or latency anomalies, and basic network interconnection is problem-free.
UDP unicast | ❌ Not working | Transport layer traffic is blocked by the WSL2 NAT virtual network, preventing UDP unicast packets sent by external devices from penetrating into the WSL2.
UDP multicast | ❌ Not working | NAT mode inherently does not support multicast transmission across LANs, rendering ROS2's core DDS multicast discovery mechanism completely ineffective.
WSL2 IP Status | 172.18.32.32 (private network segment) | The isolated NAT subnet, separate from the Windows host and the RK3588 development board's LAN segment, was the core cause of all communication failures.
Packet capture data verification | Partial Pass | It can receive UDP packets from the external internet normally, but cannot receive UDP packets from local area network devices at all, accurately pinpointing the problem of NAT interception on the internal network.

Root cause: WSL2 defaults to NAT network mode, and the IP address is not on the same subnet as Windows and the development board, causing ROS2's UDP multicast to fail to traverse NAT.

## III. Tried Solutions and Results

### 3.1 WSL2 Network Mode Configuration

plan | Configuration content | result
:-- | :-- | :--
Mirror network mode | networkMode=mirrored in .wslconfig | ❌ The current environment does not support this.
Add hostAddressLoopback | [experimental] hostAddressLoopback=true | ❌ Depends on mirror mode
Full configuration | firewall=true, dnsTunneling=true, etc. | ❌ Mirror mode is unavailable

Reason for failure:

- Microsoft's official documentation clearly states that mirrored network mode is only applicable to Windows 11 22H2 and later: "On machines running Windows 11 22H2 and higher, you can set networkingMode=mirrored under [wsl2] in the .wslconfig file to enable mirrored mode networking."
- The WSL development team confirmed in a GitHub discussion: "Sorry, mirrored mode is only available in Windows 11. In Windows 10, this goes through NAT and a local redirector."
- Community verification: Configuring mirrored networking mode on Windows 10 will be explicitly rejected by WSL and will fall back to NAT: `wsl: Mirrored networking mode is not supported: Windows version 19045.6466 does not have the required features. Falling back to NAT networking.`

### 3.2 Firewall Configuration

plan | operate | result
:-- | :-- | :--
Turn off Windows Firewall | Security Center: Turn off all firewalls | ❌ Invalid
Add UDP inbound rules | New-NetFirewallRule allows access for 11811 and 7400-7500. | ❌ Invalid
Allow Hyper-V firewall access | Set-NetFirewallHyperVVMSetting | ❌ This Cmdlet is not available in Windows 10
wsl2-hyperv-firewall tool | python3 wsl_ros2_hv_firewall.py create --ip 192.168.1.200 | ❌ UnicodeDecodeError

Reason for failure: WSL2 traffic is managed by the Hyper-V underlying virtual network stack, which is independent of the regular Windows firewall; therefore, conventional firewall rules cannot take effect. Windows 10 does not support the Hyper-V firewall.

### 3.3 ROS2 Configuration

plan | operate | result
:-- | :-- | :--
Environment variable configuration | ROS_DOMAIN_ID=42, ROS_IP=192.168.1.100 | ❌ Invalid
Forced unicast (Fast DDS XML) | Create fastdds_profile.xml and load it from both ends. | ❌ NAT routing isolation prevents communication across subnets.
Fast DDS Discovery Server | Start the WSL2 server and configure ROS_DISCOVERY_SERVER on both ends. | ❌ External devices cannot reach the WSL2 internal NAT private address; communication fails without port forwarding.
ROS2 daemon management | ros2 daemon stop/start, ros2 topic list --no-daemon | ❌ Invalid

Reason for failure: In NAT mode, WSL2 is located on an independent private subnet, and development boards within the local area network cannot directly address the WSL2's internal IP address. Even with unicast communication and Discovery Server service configured, without Windows port forwarding, all cross-machine discovery and communication logic will fail.

### 3.4 Automation Tools

plan | operate | result
:-- | :-- | :--
ros2_network_fixer | bash scripts/quickstart.sh | ❌ externally-managed-environment

Reason for failure: The native Python environment protection mechanism of Ubuntu 24.04 system is limited, and the core of this tool depends on the WSL2 mirror network mode to fix NAT isolation issues, which is not compatible with the Windows 10 environment.

### 3.5 System-level adjustments

plan | operate | result
:-- | :-- | :--
Adjust local port range | sudo sysctl -w net.ipv4.ip_local_port_range="1024 65535" | ❌ Invalid
Disable network card checksum | sudo ethtool -K eth0 tx off | ❌ Invalid
Disable systemd-resolved | sudo systemctl stop systemd-resolved | ❌ Invalid
Enable network card multicast | sudo ip link set eth0 multicast on | ❌ Invalid (already has the MULTICAST flag)

## IV. Summary of Root Causes

Conclusion: In the default NAT mode, WSL2 obtains an independent private IP (e.g., 172.30.98.229), which is not on the same subnet as the Windows physical IP (192.168.1.100) and the development board (192.168.1.200), and the IP may change with reboots. The NAT isolation mechanism prevents UDP multicast traffic, which the ROS2 core relies on, from penetrating, and the node auto-discovery mechanism completely fails. Mirrored network mode can solve this problem, but this feature is exclusive to Windows 11 22H2+ and cannot be used on Windows 10.

Network architecture diagram:

```
┌────────────────────────────────────────────────────────────┐
│                    Windows 宿主机                          │
│                    IP: 192.168.1.100                       │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                    WSL2                             │   │
│  │              IP: 172.18.32.32                       │   │
│  │              (NAT 隔离，不同子网)                    │   │
│  │                                                     │   │
│  │   ❌ UDP 多播无法穿越 NAT                            │   │
│  └──────────────────────┬──────────────────────────────┘   │
│                         │                                  │
│  ┌──────────────────────▼──────────────────────────────┐   │
│  │              Windows 防火墙/Hyper-V 防火墙           │   │
│  │              ❌ 拦截 UDP 入站流量                    │   │
│  └──────────────────────┬──────────────────────────────┘   │
└─────────────────────────┼──────────────────────────────────┘
                          │
                    ┌─────▼─────┐
                    │   路由器   │
                    └─────┬─────┘
                          │
                  ┌───────▼─────────┐
                  │     开发板       │
                  │ 192.168.1.200   │
                  │ ✅ UDP 包发往   │
                  │   192.168.1.100 │
                  └─────────────────┘
```

## V. Windows 11 Solutions

Upgrade the operating system to Windows 11, enable WSL2 mirror network mode, share the Windows physical network card network stack, and achieve communication with LAN devices on the same network segment, completely avoiding NAT isolation issues. With standard ROS2 environment variables, normal cross-machine communication can be achieved.

### 5.1 WSL2 Mirror Network Mode Configuration

File path: `C:\Users\<用户名>\.wslconfig`

Key points to note: Files must not have the .txt extension. Windows Explorer hides file extensions by default, so be sure to check the filename after saving. Incorrect file extensions will cause all configurations to fail. Also, ensure that WSL2 is the latest official version.

```
[wsl2]
networkingMode=mirrored
dnsTunneling=true
autoProxy=true
```

Functionality: Mirror mode allows WSL2 to directly reuse the Windows host network interface and LAN IP, eliminating subnet isolation. It natively supports UDP multicast, direct connection to LAN devices, VPN compatibility, and other capabilities, perfectly adapting to ROS2 cross-machine communication scenarios.

Configuration activation verification:

```
$ ip addr show eth0 | grep inet
inet 192.168.1.100/24 brd 192.168.1.255 scope global eth0
```

Effective criteria: The WSL2 network card IP address must be exactly the same as the Windows physical network card IP address.

### 5.2 ROS2 Environment Variable Configuration

`ROS_AUTOMATIC_DISCOVERY_RANGE` is an official ROS2 environment variable, valid for both source code compilation and Deb package installation environments, used to limit the DDS node discovery range. `RMW_FASTDDS_NETWORK_INTERFACE` is a Fast DDS middleware-specific environment variable used to specify the network interface, effective only in mirror mode.

```
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
export ROS_DOMAIN_ID=42
export ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET
# Fast‑DDS 指定使用 eth0 网卡，避免自动选网卡出错（仅镜像模式下生效）
export RMW_FASTDDS_NETWORK_INTERFACE=eth0
```

Environment variables | Function Description
:-- | :--
RMW_IMPLEMENTATION=rmw_fastrtps_cpp | Specify Fast DDS as the default middleware for ROS2 to ensure multicast discovery compatibility.
ROS_DOMAIN_ID=42 | Unify the device's DDS communication domain to avoid cross-domain node discovery failures.
ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET | Official standard variables enforce multicast discovery within the subnet, preventing it from being downgraded to local loopback discovery by default.
RMW_FASTDDS_NETWORK_INTERFACE=eth0 | Fast DDS middleware private environment variables are used to bind to specified network interfaces.

Additional information: Fine-grained network interface binding requires a separate XML configuration file in Fast DDS and does not have a corresponding environment variable.

### 5.3 Complete Communication Verification Steps

**Step 1: Confirm WSL2 network IP**

```
ip addr show eth0 | grep inet
```

**Step 2: Configure the development board with a unified ROS environment and start the release node.**

```
export ROS_DOMAIN_ID=42
ros2 run camera_pkg camera_pub
```

**Step 3: Configure WSL2 environment variables and view topics**

```
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
export ROS_DOMAIN_ID=42
export ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET
# Fast‑DDS 指定使用 eth0 网卡，避免自动选网卡出错（仅镜像模式下生效）
export RMW_FASTDDS_NETWORK_INTERFACE=eth0
ros2 topic list
```

**Step 4: Validate topic data**

```
ros2 topic echo /camera/image_raw --once | grep height
```

### 5.4 Startup Auto-Configuration Script

Save as `~/ros2_wsl_setup.sh`

```
#!/bin/bash
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
export ROS_DOMAIN_ID=42
export ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET
export RMW_FASTDDS_NETWORK_INTERFACE=eth0
echo "ROS2 镜像网络模式跨机通信环境配置完成"
```

Usage: Run `source ~/ros2_wsl_setup.sh` in the terminal each time to quickly apply the configuration.

## VI. Summary of Scheme Comparison

Comparison items | Windows 10 (22H2) + WSL2 | Windows 11 (25H2) + WSL2
:-- | :-- | :--
Mirror network mode supported | ❌ Officially not supported; configure fallback NAT. | ✅ Exclusive to Windows 11 22H2 and above
WSL2 Network IP Status | ❌ 172 independent private IP segments, located across subnets from the host | ✅ Shared host IP address in mirror mode, within the same network segment
ICMP network connectivity | ✅ Normal interoperability | ✅ Normal interoperability
UDP unicast/multicast penetration | ❌ NAT blocks multicast, unicast is restricted | ⚠️ This is officially labeled as an experimental feature; it supports multicast but there are stability risks.
ROS2 node auto-discovery | ❌ Multicast blocking, DDS failure | ⚠️ Mirror mode supports multicast, but its stability depends on experimental features.
Firewall compatibility | ❌ Hyper-V firewall is not supported; regular rules are difficult to apply to WSL virtual network adapters. | ⚠️ Windows 11 version 22H2 introduces the Hyper-V firewall, which filters WSL traffic by default and blocks inbound traffic by default. You need to manually allow it (not bypass it).
ROS2 configuration difficulty | 🔴 High latency, requires port forwarding or proxy | 🟢 Lower settings, enable mirror mode + basic environment variables
Long-term stability | ❌ No official fix plan | ⚠️ This is an experimental feature; Microsoft has confirmed that it is incompatible with some VPNs (Bitdefender, OpenVPN, etc.).
Final feasibility | ❌ Not recommended | ⚠️ Feasible, but attention should be paid to experimental location and firewall configuration.

## VII. Key Technical Points

### 7.1 Explanation of Core Concepts

concept | Detailed description
:-- | :--
WSL2 NAT Default Mode | WSL2 uses a dedicated virtual network adapter by default, obtaining a private IP address segment of 172. This is isolated from the host's LAN network segment, preventing external LAN devices from directly accessing WSL2 and blocking UDP multicast.
WSL2 Mirror Network Mode | Win11 22H2+ exclusive features: reuses Windows native network stack, IP, and network card, eliminates subnet isolation, and natively supports ROS2 cross-machine multicast communication.
ROS2 DDS discovery mechanism | By default, WSL2 relies on UDP multicast for automatic node and topic discovery. However, multicast cannot communicate across NATs, which is the core reason for the failure of cross-machine ROS communication in WSL2.
Hyper-V firewall mechanism | WSL2 traffic is managed by the underlying Hyper-V firewall, independent of the Windows Defender firewall. On Win11 22H2+, you can use `Set-NetFirewallHyperVVMSetting -Name '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}'` to configure inbound Hyper-V firewall rules for WSL2.

### 7.2 Summary of Core Experiences

1. Mirrored mode is a Win11 exclusive feature: Microsoft's official documentation and the WSL development team have both confirmed that Windows 10 cannot use the mirrored network mode, and configuring it will force a fallback to NAT, with no compatibility solutions available.
2. NAT mode UDP multicast is a hard limitation: The WSL2 NAT network stack does not natively support cross-LAN UDP multicast, and all multicast auto-discovery protocols (ROS2/ZeroConf) are invalid, which is an officially known limitation.
3. ROS_AUTOMATIC_DISCOVERY_RANGE is a standard variable: This environment variable is the official native configuration of ROS2, and is globally effective in source code compilation and deb installation environments. It can be safely used to limit the subnet discovery range.
4. Mirrored mode has known stability issues: Microsoft's official troubleshooting documentation marks mirrored network mode as an "experimental setting." NVIDIA's official forum has confirmed that UDP multicast in WSL2 mirrored mode has stability defects in certain scenarios.
5. The best solution for Windows 10: There is no effective modification solution for the Windows 10 environment. Abandoning NAT mode optimization and directly upgrading to Windows 11 or using the native Windows ROS2 is the only safe solution.

## VIII. Appendix

### Appendix A: Reference Links

content | Link
:-- | :--
WSL Mirror Network Mode Official Documentation (Win11 Exclusive) | https://learn.microsoft.com/en-us/windows/wsl/networking#mirrored-mode-networking
WSL Global/Distribution Configuration Official Documentation | https://learn.microsoft.com/en-us/windows/wsl/wsl-config
The WSL team has confirmed that the image mode is only available on Windows 11. | https://github.com/microsoft/WSL/discussions/11380
Known issues with WSL2 NAT UDP communication | https://github.com/microsoft/WSL/issues/11027
WSL2 multicast support related issues | https://github.com/microsoft/WSL/issues/12344
WSL mirror mode is an experimental feature (official troubleshooting documentation). | https://learn.microsoft.com/en-us/windows/wsl/troubleshooting
Hyper-V Firewall Official Documentation (Win11 22H2+ Supports WSL2) | https://learn.microsoft.com/zh-cn/windows/security/operating-system-security/network-security/windows-firewall/hyper-v-firewall
Set-NetFirewallHyperVVMSetting WSL2 Sandbox ID | https://learn.microsoft.com/zh-cn/windows/security/operating-system-security/network-security/windows-firewall/hyper-v-firewall
Issues with NVIDIA IsaacSim + WSL2 mirror mode | https://forums.developer.nvidia.com/t/isaacsim-5-1-ros2-connection-issue-when-running-wsl2-in-mirrored-mode/370535/5

### Appendix B: Troubleshooting Flowchart

```
                    ┌─────────────────────────────┐
                    │  WSL2 无法发现开发板话题      │
                    └─────────────┬───────────────┘
                                  ▼
                    ┌─────────────────────────────┐
                    │  Step 1: ping 连通性测试     │
                    └─────────────┬───────────────┘
                                  ▼
                    ┌─────────────────────────────┐
                    │         ping 通 ✅          │
                    │         UDP不通 ❌          │
                    └─────────────┬───────────────┘
                                  ▼
                    ┌─────────────────────────────┐
                    │  WSL2 IP 与 Windows 不同     │
                    │      → NAT 模式              │
                    └─────────────┬───────────────┘
                                  ▼
                    ┌─────────────────────────────┐
                    │      尝试镜像网络模式        |
                    └─────────────┬───────────────┘
                                  ▼
              ┌───────────────────┴───────────────────┐
              │                                       │
              ▼                                       ▼
    ┌─────────────────┐                 ┌─────────────────────┐
    │   Windows 10    │                 │  Windows 11 22H2+   │
    │  镜像模式不可用  │                 │     镜像模式可用     │
    └────────┬────────┘                 └──────────┬──────────┘
             │                                     │
             ▼                                     ▼
    ┌─────────────────┐                   ┌────────────────────┐
    │ NAT 模式无法解决 │                   │  启用镜像模式       │
    │ 推荐：           │                  │  + 标准ROS2环境变量  │
    │ • 升级 Windows 11│                  │  → 跨机通信成功 ✅  │
    │ • 使用 Windows   │                  └─────────────────────┘
    │   原生 ROS2      │
    └─────────────────┘
```
