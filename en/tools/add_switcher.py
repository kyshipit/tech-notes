#!/usr/bin/env python3
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent

# 中文文件 -> 英文文件 映射
mapping = {
    "README.md": "en/README.md",
    "AGENTS.md": "en/AGENTS.md",
    "ai/AI工程落地相关.md": "en/ai/AI-Engineering-Implementation.md",
    "ai/AI知识体系构造.md": "en/ai/AI-Knowledge-System-Construction.md",
    "deploy/melotts-rknn量化部署踩坑记录.md": "en/deploy/MeloTTS-RKNN-Quantization-Deployment-Pitfalls.md",
    "deploy/RKNPU模型量化部署原理手册.md": "en/deploy/RKNPU-Model-Quantization-Deployment-Principles.md",
    "embed/camera显示问题排查.md": "en/embed/Camera-Display-Troubleshooting.md",
    "embed/es8388音频无声排查.md": "en/embed/ES8388-Audio-No-Sound-Troubleshooting.md",
    "embed/qemu构建rootfs时systemd锁问题修复.md": "en/embed/QEMU-Rootfs-Build-Systemd-Lock-Fix.md",
    "embed/rk3588移植noble版本rootfs.md": "en/embed/RK3588-Noble-Rootfs-Porting.md",
    "iot/can_uds车载通信诊断技术文档.md": "en/iot/CAN-UDS-Automotive-Diagnostic-Technical-Guide.md",
    "iot/NFC技术原理与汽车钥匙应用.md": "en/iot/NFC-Technology-and-Car-Key-Applications.md",
    "iot/蓝牙低功耗完整通信原理解析.md": "en/iot/Bluetooth-Low-Energy-Complete-Communication-Guide.md",
    "ros/ROS2图像卡顿WiFi_QoS与WSL2排错.md": "en/ros/ROS2-Image-Stuttering-WiFi-QoS-and-WSL2-Troubleshooting.md",
    "ros/ROS2机器人仿真与导航完整工程实践.md": "en/ros/ROS2-Robot-Simulation-and-Navigation-Engineering-Practice.md",
    "ros/WSL2-ROS2跨机通信问题.md": "en/ros/WSL2-ROS2-Cross-Machine-Communication.md",
    "ros/交叉编译ROS2踩坑记录.md": "en/ros/Cross-Compiling-ROS2-Pitfalls.md",
    "tools/ELF静态逆向分析.md": "en/tools/ELF-Static-Reverse-Engineering-Analysis.md",
    "tools/GDB动态调试指南.md": "en/tools/GDB-Dynamic-Debugging-Guide.md",
    "tools/Git常用操作与安全实践.md": "en/tools/Git-Common-Operations-and-Security-Practices.md",
}

def clean_old_switcher(content: str) -> str:
    """删除文件开头可能存在的旧语言切换器，保留正文。"""
    # 删除 <div align="right">...</div>
    content = re.sub(r'^<div align="right">[\s\S]*?</div>\n*', '', content, flags=re.MULTILINE)
    lines = content.splitlines(keepends=True)
    i = 0
    while i < len(lines):
        line = lines[i]
        # 匹配切换器相关行：以 [English]、**English**、[简体中文]、**简体中文**、[![English] 等开头
        if re.match(r'^\s*(\[English\]|\*\*English\*\*|\[简体中文\]|\*\*简体中文\*\*|\[!\[English\]|\[!\[简体中文\])', line):
            i += 1
            # 跳过后续空行和 --- 分隔线
            while i < len(lines) and (lines[i].strip() == '' or lines[i].strip() == '---'):
                i += 1
            continue
        else:
            break
    return ''.join(lines[i:]).lstrip('\n')

def add_switcher():
    for zh_rel, en_rel in mapping.items():
        zh_path = ROOT / zh_rel
        en_path = ROOT / en_rel

        # 中文文件：根据当前文件深度加 ../
        if zh_path.exists():
            content = zh_path.read_text(encoding='utf-8')
            content = clean_old_switcher(content)
            depth = zh_rel.count('/')          # README.md -> 0, ai/xxx.md -> 1
            up = '../' * depth
            en_link = up + en_rel
            switcher = f'[English]({en_link}) | **简体中文**\n\n'
            zh_path.write_text(switcher + content, encoding='utf-8')
            print(f'✓ 中文: {zh_rel}  ->  {en_link}')
        else:
            print(f'✗ 中文文件不存在: {zh_rel}')

        # 英文文件：根据 en/ 下的深度加 ../
        if en_path.exists():
            content = en_path.read_text(encoding='utf-8')
            content = clean_old_switcher(content)
            depth = en_rel.count('/')            # en/ai/xxx.md -> 2
            up = '../' * depth                   # "../../"
            zh_link = up + zh_rel                # "../../ai/AI工程落地相关.md"
            switcher = f'**English** | [简体中文]({zh_link})\n\n'
            en_path.write_text(switcher + content, encoding='utf-8')
            print(f'✓ 英文: {en_rel}')
        else:
            print(f'✗ 英文文件不存在: {en_rel}')

if __name__ == '__main__':
    add_switcher()
    print('\n完成！请检查文件，然后 git add/commit/push。')