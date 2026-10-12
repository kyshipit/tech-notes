**English** | [简体中文](../../embed/es8388音频无声排查.md)

<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2026 KY (kyshipit)
-->

# RK3588 ES8388 Audio No Sound Issue—Complete Troubleshooting Summary

## I. Problem Phenomenon

- Hardware: ATK-DLRK3588 development board + onboard speaker

- System: Ubuntu 24.04 (rootfs ported from Buildroot)

- Initial problem: aplay executes successfully but there is no sound.

- Comparison object: The speaker works normally on the Buildroot system.

## II. All troubleshooting operations (in chronological order, each step includes the command, principle, and result).

### Step 1: The user initially attempts to play the audio.

**Command verification:**

```
aplay /usr/share/sounds/alsa/Front_Center.wav
aplay -D plughw:1,0 /usr/share/sounds/alsa/Front_Center.wav
```

**result:**

- The aplay command executed successfully (no error output).

- The speaker did not make any sound.

**Preliminary assessment:** The audio playback command was executed successfully, indicating that the software is working properly, but the sound is not reaching the speaker.

### Step 2: The user attempts to play the video using GStreamer.

**Command verification:**

```
gst-launch-1.0 playbin uri=file:///userdata/piano2-CoolEdit.mp3
gst-launch-1.0 uridecodebin uri=file:///userdata/piano2-CoolEdit.mp3 ! audioconvert ! audioresample ! alsasink device=plughw:1,0
```

**result:**

- The pipeline executed successfully, displaying Got EOS.

- The speaker is silent.

**Preliminary assessment:** Multiple media players executed successfully but produced no sound, so the problem is not with the media players themselves.

### Step 3: Check if the sound card is recognized by the system.

**Order:**

```
cat /proc/asound/cards
```

**result:**

```
1 [rockchipes8388 ]: rockchip-es8388 - rockchip-es8388
```

**Conclusion:** The Rockchipes 8388 sound card has been correctly registered.

### Step 4: Check if the playback device node exists.

**Order:**

```
ls -l /dev/snd/
```

**result:**

```
crw-rw---- 1 root audio 116, 4 Aug 7 11:10 pcmC1D0p
```

**Conclusion:** The playback device node pcmC1D0p exists.

### Step 5: Test the ALSA layer using speaker-test.

**Order:**

```
speaker-test -c 2 -D plughw:1,0 -t sine -f 1000
```

**result:**

```
Playback device is plughw:1,0
Stream parameters are 48000Hz, S16_LE, 2 channels
Sine wave rate is 1000.0000Hz
...
0 - Front Left
1 - Front Right
Time per period = 2.750624
```

**Conclusion:** The speaker-test ran successfully, displaying alternating Front Left and Front Right outputs, indicating that the audio data has been successfully written to the ALSA DMA buffer.

### Step 6: Check the volume settings in alsamixer

**Order:**

```
alsamixer -c 1
```

**Command verification:** View the volume of the Headphone, Speaker, PCM, and other channels in the alsamixer interface.

**Result:** The volume channel showed normal, but the speaker was still silent.

### Step 7: List all sound card controls

**Order:**

```
amixer -c 1 scontrols
```

**Results (partial):**

```
Simple mixer control 'Headphone',0
Simple mixer control 'Speaker',0
Simple mixer control 'PCM',0
Simple mixer control 'hp switch',0
Simple mixer control 'spk switch',0
Simple mixer control 'Mono Mux',0
Simple mixer control 'Left Mixer Left Playback Switch',0
Simple mixer control 'Right Mixer Right Playback Switch',0
Simple mixer control 'OUT1 Switch',0
Simple mixer control 'OUT2 Switch',0
Simple mixer control 'Output 1 Playback Volume',0
Simple mixer control 'Output 2 Playback Volume',0
```

### Step 8: Export the current state of all controls.

**Order:**

```
amixer -c 1 contents > /tmp/amixer.txt
cat /tmp/amixer.txt
```

**Key information discovered:**

```
numid=40,iface=MIXER,name='hp switch' - values=off
numid=39,iface=MIXER,name='spk switch' - values=off
numid=55,iface=MIXER,name='OUT1 Switch' - values=off
numid=56,iface=MIXER,name='OUT2 Switch' - values=off
```

**Conclusion:** Multiple switches are in the off state.

### Step 9: Turn on all the switches that were turned off.

**Order:**

```
amixer -c 1 sset 'hp switch' on
amixer -c 1 sset 'spk switch' on
amixer -c 1 sset 'Headphone' on
amixer -c 1 sset 'Speaker' on
amixer -c 1 cset "name='Left Mixer Left Playback Switch'" on
amixer -c 1 cset "name='Right Mixer Right Playback Switch'" on
amixer -c 1 cset "name='PCM Playback Volume'" 192
amixer -c 1 cset "name='Output 1 Playback Volume'" 33
amixer -c 1 cset "name='Output 2 Playback Volume'" 33
amixer -c 1 cset "name='Mono Mux'" 0
```

**Result:** All commands were executed successfully, but the speaker remained silent.

### Step 10: Check if the ALSA UCM configuration is loaded.

**Order:**

```
alsaucm -c rockchipes8388 dump text
```

**result:**

```
ALSA lib main.c:1554:(snd_use_case_mgr_open) error: failed to import rockchipes8388 use case configuration -2
alsaucm: error failed to open sound card rockchipes8388: No such file or directory
```

**Conclusion:** The UCM configuration was not loaded. The BootSequence in the UCM (which contains audio initialization commands) was not executed.

### Step 11: Check if the UCM directory exists.

**Order:**

```
ls -la /usr/share/alsa/ucm2/Rockchip/
```

**result:**

```
drwxr-xr-x 2 root root 4096 Aug 7 11:10 rk3588-es8316
```

**Conclusion:** The UCM configuration file exists (rk3588-es8316 directory), but the sound card name rockchipes8388 does not match the UCM directory name rk3588-es8316.

### Step 12: Obtain the sound card driver name

**Order:**

```
ls -l /sys/class/sound/card1/device/driver
```

**result:**

```
lrwxrwxrwx 1 root root 0 Aug 7 10:29 /sys/class/sound/card1/device/driver -> ../../../bus/platform/drivers/rk-multicodecs
```

**Conclusion:** The driver name is rk-multicodecs. ALSA searches for the UCM configuration based on the driver name, not the sound card name.

### Step 13: Try loading UCM using the driver name

**Order:**

```
alsaucm -c rk-multicodecs dump text
```

**result:**

```
ALSA lib main.c:1554:(snd_use_case_mgr_open) error: failed to import rk-multicodecs use case configuration -2
alsaucm: error failed to open sound card rk-multicodecs: No such file or directory
```

**Conclusion:** Loading UCM using the driver name also failed.

### Step 14: Attempt to create the conf.d mapping file

**Order:**

```
mkdir -p /usr/share/alsa/ucm2/conf.d/rk-multicodecs
cat > /usr/share/alsa/ucm2/conf.d/rk-multicodecs/rk-multicodecs.conf << 'EOF'
SectionUseCase."HiFi" {
    File "/Rockchip/rk3588-es8316/HiFi.conf"
    Comment "Play HiFi quality Music"
}
EOF
```

**Result:** The mapping file was created successfully, but alsaucm still reported an error -2.

### Step 15: Attempt to create symbolic links

**Order:**

```
ln -sf /usr/share/alsa/ucm2/Rockchip/rk3588-es8316 /usr/share/alsa/ucm2/Rockchip/rockchipes8388
```

**Result:** The symbolic link was created successfully, but alsaucm still reported an error.

### Step 16: Use strace to trace the UCM lookup path (not executed, but can be done).

**Command (suggested but not executed):**

```
strace -e trace=file alsaucm -c rk-multicodecs dump text 2>&1 | grep ucm2
```

**Note:** This command displays the actual path searched by ALSA, helping to pinpoint the cause of UCM loading failure.

### Step 17: Check the GPIO power amplifier enable status

**Order:**

```
cat /sys/kernel/debug/gpio | grep -i spk
```

**result:**

```
gpio-136 (|spk-con) out hi
```

**Conclusion:** The power amplifier's enable GPIO is already at a high level. The power amplifier is enabled.

### Step 18: Attempt to export GPIO 136

**Order:**

```
echo 136 > /sys/class/gpio/export
```

**result:**

```
cat: /sys/class/gpio/gpio136/value: No such file or directory
```

**Conclusion:** GPIO 136 is already occupied by the kernel and cannot be exported from user space. This indicates that GPIO is managed by the kernel driver and is functioning normally.

### Step 19: Recheck all output-related switches

**Order:**

```
amixer -c 1 controls | grep -i "output\|out"
```

**result:**

```
numid=55,iface=MIXER,name='OUT1 Switch'
numid=56,iface=MIXER,name='OUT2 Switch'
numid=34,iface=MIXER,name='Output 1 Playback Volume'
numid=35,iface=MIXER,name='Output 2 Playback Volume'
```

### Step 20: Check the specific status of OUT1 Switch and OUT2 Switch.

**Order:**

```
amixer -c 1 cget "name='OUT1 Switch'"
amixer -c 1 cget "name='OUT2 Switch'"
```

**result:**

```
numid=55,iface=MIXER,name='OUT1 Switch'
  ; type=BOOLEAN,access=rw------,values=1
  : values=off

numid=56,iface=MIXER,name='OUT2 Switch'
  ; type=BOOLEAN,access=rw------,values=1
  : values=off
```

**Conclusion:** OUT1 Switch and OUT2 Switch are in the off state. These two switches are the physical output stage switches of the ES8388, located at the last stage of the signal path.

### Step 21: Turn on OUT1 Switch and OUT2 Switch (final success)

**Order:**

```
amixer -c 1 cset "name='OUT1 Switch'" on
amixer -c 1 cset "name='OUT2 Switch'" on
```

**result:**

```
numid=55,iface=MIXER,name='OUT1 Switch'
  ; type=BOOLEAN,access=rw------,values=1
  : values=on

numid=56,iface=MIXER,name='OUT2 Switch'
  ; type=BOOLEAN,access=rw------,values=1
  : values=on
```

### Step 22: Verify that the speaker is producing sound.

**Order:**

```
speaker-test -c 2 -D plughw:1,0 -t sine -f 1000
```

**Result:** ✅ The speaker is working normally!

## III. All erroneous inferences (in chronological order)

Serial Number | Incorrect inference | Overturned evidence
--- | --- | ---
1 | There is a problem with the playback tool or pipeline configuration. | Both gst-launch and aplay executed successfully, indicating that the tools are working correctly.
2 | "ALSA volume setting is too low or it is muted" | alsamixer displays the volume as normal, but there is still no sound after turning it on.
3 | "UCM configuration is required; the missing files are missing." | Manual amixer allows for complete control over the audio path.
4 | The driver name is rockchipes8388. | The command `ls -l /sys/class/sound/card1/device/driver` shows "rk-multicodecs".
5 | "UCM symbolic links can solve the problem." | alsaucm still reports an error after the symbolic link is created.
6 | The conf.d mapping file can solve the problem. | alsaucm still reports an error after the mapping file is created.
7 | "Power amplifier GPIO not enabled" | gpio-136 spk-con out hi indicates that it is enabled.
8 | "User space needs to export GPIO" | The GPIO is currently occupied by the kernel; this is normal.
9 | "MCLK gating closed, causing silence" | clk_summary indicates that MCLK is enabled.
10 | "Kernel version or device tree mismatch" | The sound card is registered correctly; the problem is not with the kernel.
11 | "The HP switch or SPK switch is the root cause of the problem." | Still no sound after turning on
12 | "The mixer switch (Left Mixer...) is the root cause of the problem." | Still no sound after turning it on

## IV. The Correct Troubleshooting Path (The Method to Ultimately Find the Problem)

step | operate | Discover
--- | --- | ---
1 | amixer -c 1 controls | grep -i "output
2 | amixer -c 1 cget "name='OUT1 Switch'" | The status is off.
3 | amixer -c 1 cset "name='OUT1 Switch'" on | Successfully started
4 | speaker-test | The speaker is making a sound.

## V. ES8388 Signal Path and Problems

```
数字数据 (DMA)
    │
    ▼
I2S 接口 (接收 PCM 数据)
    │
    ▼
DAC (数模转换)          ← ✅ `speaker-test` 验证数据已到达
    │
    ▼
DAC 输出音量控制
    │
    ▼
Left/Right Mixer        ← ✅ 已开启 (`Left Mixer Left Playback Switch`)
    │
    ▼
OUT1/OUT2 输出级开关    ← ❌ **问题点**，默认关闭
    │                    ← ✅ 开启后信号通过
    ▼
物理输出引脚 (OUT1/OUT2)
    │
    ▼
外部功放 (PA)           ← ✅ GPIO 136 已使能 (`spk-con out hi`)
    │
    ▼
喇叭                    ← ✅ 最终正常发声
```

## 6. Why is Buildroot working normally while Ubuntu is silent?

Buildroot's UCM configuration file HiFi.conf contains a BootSequence, which is executed automatically when the system starts.

```
BootSequence [
    cset "name='OUT1 Switch'" on
    cset "name='OUT2 Switch'" on
    ...
]
```

On Ubuntu, UCM is not loaded (alsaucm error -2), causing OUT1 Switch and OUT2 Switch to remain in the default off state, and the signal is cut off inside the chip.

## VII. The final, effective command (only these two are necessary)

```
amixer -c 1 cset "name='OUT1 Switch'" on
amixer -c 1 cset "name='OUT2 Switch'" on
```

## 8. All operations previously performed but ultimately proven to be unnecessary/ineffective

operate | Why is it ineffective?
--- | ---
Setting up HP switch on | Controlling the headphones is unrelated to the speakers.
Set spk switch on | The ES8388 internal switch does not affect OUT1/OUT2.
Adjust Headphone Volume | Controlling headphone volume is unrelated to the speakers.
Set Speaker Volume | The ES8388's internal volume control is not the root cause.
Set PCM Playback Volume to 192 | Volume, not a problem with the switch.
Set Output 1/2 Playback Volume 33 | Volume, not a problem with the switch.
Set Mono Mux Stereo | The mode selection is not the reason for muting.
Set Left/Right Mixer... on | The mixer switch is not the last stage.
Create UCM symbolic link | The UCM loading mechanism itself has problems.
Create the conf.d mapping file | The UCM loading mechanism itself has problems.
Check MCLK clock | The clock is working properly
Check GPIO 136 | The power amplifier is enabled.
Check the equipment tree | Device tree is normal
Install the GStreamer plugin | The playback tool is working properly.
Update kernel | The kernel is not the root cause.

## IX. Permanent Configuration

Add the following before `exit 0` in `/etc/rc.local`:

```
# OUT1/OUT2 开关开启
amixer -c 1 cset "name='OUT1 Switch'" on
amixer -c 1 cset "name='OUT2 Switch'" on

# 设置 ALSA 默认声卡为 card 1 (ES8388)
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

```

## X. Final Conclusion

project | content
--- | ---
Root of the problem | The ES8388 chip's internal OUT1 and OUT2 switches are off by default.
Why is the speaker test normal but there is no sound? | Data arrives at the DAC, but is intercepted by the OUT1/OUT2 switch.
Why is Buildroot working normally? | UCM's BootSequence automatically enables the OUT1/OUT2 switches.
Why is Ubuntu silent? | UCM is not loaded; OUT1/OUT2 switches remain off by default.
Final solution | Two amixer commands enable OUT1 Switch and OUT2 Switch.
All other operations | Ineffective attempts during the investigation process
