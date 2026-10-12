**English** | [简体中文](../../tools/ELF静态逆向分析.md)

<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2026 KY (kyshipit)
-->

# Part 1: ELF Static Reverse Engineering – Ghidra from Installation to Decompilation and Reconstruction of Source Code

> **Applicable scenarios** : You only have a binary executable file, no source code, and want to figure out what the program does, or even recover logic close to the source code.
>
> **This article does not cover dynamic debugging** (analysis after the program is running), but only static analysis.
>
> **What is static analysis** ? It's analyzing the binary file itself without running the program. It involves reconstructing the program logic by examining file information, extracting strings, disassembling, and decompiling. Ghidra is currently the most powerful open-source decompiler, capable of converting assembly code into highly readable C pseudocode.

## Chapter 1 Ghidra Installation and Environment Configuration

### 1.1 Tool Installation

#### 1.1.1 Update the package manager and install basic tools

```
sudo apt update
sudo apt install binutils gdb build-essential
```

#### 1.1.2 Install Radare2 (source code method, latest version)

```
git clone https://github.com/radareorg/radare2
cd radare2 && sys/install.sh
```

Alternatively, you can use Snap to install the latest version:

```
sudo snap install radare2
```

#### 1.1.3 Install Ghidra (requires Java 11+)

Download Ghidra 10.3.2:

```
wget https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_10.3.2_build/ghidra_10.3.2_PUBLIC_20230711.zip
unzip ghidra_10.3.2_PUBLIC_20230711.zip
```

> **Important** : The `ghidra_10.3.2_PUBLIC` directory must be kept. This directory contains the actual program files for Ghidra. Deleting it will prevent Ghidra from running.

#### 1.1.4 Install OpenJDK 17 (Recommended, good compatibility)

```
sudo apt install openjdk-17-jdk
```

### 1.2 Environment Configuration

#### 1.2.1 Check the JAVA_HOME environment variable

```
echo $PATH
echo $PATH | tr ':' '\n' | grep tools
```

Check if JAVA_HOME is in the environment:

```
env | grep JAVA
```

Check if the JVM path is included in the current PATH:

```
echo $PATH | tr ':' '\n' | grep jvm
```

Directly test if Java is available:

```
java -version
javac -version
```

#### 1.2.2 Manually configure JAVA_HOME

If Java is not configured correctly, execute the following manually:

```
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
```

Test the configuration now to see if it works:

```
echo $JAVA_HOME
java -version
```

#### 1.2.3 Verify the currently used Radare 2 version

Check which Radare2 is currently being used:

```
which r2
```

Check the version (confirm it's the version installed via apt):

```
r2 -v
```

- If the output shows version information and the path is `/usr/bin/r2` , it means that the apt version is being used.
- If the path is `/usr/local/bin/r2` , `r2 -v` displays the git commit hash, it indicates that it is a source code installation version.

### 1.3 Script Startup

#### Method 1: Add to PATH environment variable

```
# 将Ghidra目录添加到PATH
echo 'export PATH=$PATH:~/ghidra_10.3.2_PUBLIC' >> ~/.rc
source ~/.rc

# 检查.rc文件末尾是否有设置
tail -10 ~/.rc
```

It can be run directly now:

```
ghidraRun
```

#### Method 2: Create a convenient startup script

```
# 在主目录创建启动脚本
echo '#!/bin/
cd ~/ghidra_10.3.2_PUBLIC
./ghidraRun' > ~/ghidra.sh

chmod +x ~/ghidra.sh
```

Start via script:

```
~/ghidra.sh
```

#### Verify the current installation

To check Ghidra's actual location:

```
find ~ -name "ghidraRun" 2>/dev/null
```

### 1.4 Process Detection

Check Ghidra and Java processes:

```
ps aux | grep ghidra
ps aux | grep java
```

Alternatively, use jps to view Java processes:

```
jps -l | grep ghidra
```

Examine the process tree to check for any residual Java processes:

```
pstree | grep -i java
```

## Chapter 2 Ghidra Disassembly and Reverse Engineering

### 2.1 Overview of the Disassembly Toolchain

**The relationship between the three tools:**

tool | position | Applicable Scenarios
:-- | :-- | :--
objdump | Linux's built-in quick assembly language viewer | Initial understanding of program structure
radare2 | Command-line interactive reverse engineering framework | Scripted analysis, remote analysis
Ghidra | Graphical decompilation tools | In-depth analysis, reconstructing the C pseudocode

**Standard workflow:**

```
file/nm/strings 摸底 → objdump 看汇编 → radare2 深入探索 → Ghidra 反编译重建源码
```

### 2.2 Basic Document Analysis

#### 2.2.1 Viewing file information

```
file your_program
```

Output example: `ELF 64-bit LSB executable, x86-64`

#### 2.2.2 Check if debug symbols are included.

```
nm your_program
```

- If there is output, it means that symbolic information is contained, which will make recovery much easier.
- If there is no output or `no symbols` is displayed, it means the symbols have been stripped.

#### 2.2.3 Extracting Strings

```
strings your_program > strings.txt
less strings.txt
```

This will extract all readable strings, helping you understand the program's potential functionality.

### 2.3 objdump disassembly

#### 2.3.1 Disassemble the entire program

```
objdump -d -M intel your_program > full_disassembly.asm
```

#### 2.3.2 Disassembling only code segments

```
objdump -d -M intel --disassemble=.text your_program > code_section.asm
```

#### 2.3.3 Viewing specific functions

First, locate the address of the main function:

```
objdump -t your_program | grep main
```

Disassemble the main function (taking addresses 0x401050 to 0x401150 as an example):

```
objdump -d -M intel --start-address=0x401050 --stop-address=0x401150 your_program
```

### 2.4 Radare2 Installation and Usage

#### 2.4.1 Installation Instructions

radare2 has been installed as described in section 1.1.2, and can be verified using the following command:

```
which r2        # 确认路径
r2 -v           # 确认版本
```

#### 2.4.2 Initial Analysis

```
r2 -A your_program
```

`-A` parameter performs automatic analysis.

#### 2.4.3 radare2 interactive commands

After entering the Radare2 interactive environment, commonly used commands include:

```
[0x00000000]> aa              # 自动分析
[0x00000000]> afl             # 列出所有函数
[0x00000000]> s main          # 跳转到main函数
[0x00000000]> pdf             # 反汇编当前函数
[0x00000000]> pdb             # 显示调试器信息
[0x00000000]> iz              # 列出数据段中的字符串
```

#### 2.4.4 Detailed Function Analysis

```
[0x00000000]> pdf @@ *       # 反汇编所有函数
[0x00000000]> graph          # 显示控制流图
```

### 2.5 GDB Dynamic Analysis (Assisted Disassembly Scenarios)

During static analysis, it is sometimes necessary to use GDB to view runtime assembly information.

Start GDB:

```
gdb your_program
```

Commonly used disassembly commands in GDB:

```
(gdb) info functions          # 列出所有函数
(gdb) disas main             # 反汇编main函数
(gdb) break main             # 在main函数设置断点
(gdb) run                    # 运行程序
(gdb) stepi                  # 单步执行汇编指令
(gdb) info registers         # 查看寄存器状态
(gdb) x/10i $pc             # 查看当前指令附近10条指令
(gdb) quit                   # 退出
```

### 2.6 Ghidra decompilation (the most important step)

#### 2.6.1 Starting Ghidra

```
cd ~/ghidra_10.3.2_PUBLIC
./ghidraRun
```

#### 2.6.2 Creating Projects and Analysis Files

1. File → New Project → Non-shared project → Enter project name
2. File → Import File → Select your executable file
3. Double-click the imported file to open the Code Browser.
4. Click "Yes" to start automatic analysis.

#### 2.6.3 Locating Key Functions

Expand "Functions" in the "Symbol Tree" window on the left, find and double-click `main` function.

Three main windows will appear on the right:

- **Left side** : Assembly code window
- **Middle** : Decompilation window (displays pseudo-C code)
- **Right side** : Various information panels

#### 2.6.4 Analysis of Pseudocode Examples

Assuming Ghidra displays:

```
undefined8 main(void)
{
  int iVar1;
  long in_FS_OFFSET;
  char local_18 [8];
  long local_10;
  
  local_10 = *(long *)(in_FS_OFFSET + 0x28);
  printf("Enter password: ");
  fgets(local_18,8,stdin);
  iVar1 = strcmp(local_18,"secret");
  if (iVar1 == 0) {
    puts("Access granted!");
  }
  else {
    puts("Wrong password!");
  }
  if (local_10 != *(long *)(in_FS_OFFSET + 0x28)) {
                    /* WARNING: Subroutine does not return */
    __stack_chk_fail();
  }
  return 0;
}
```

#### 2.6.5 Renaming Variables and Functions

Rename variables in Ghidra to make them more meaningful.

**Three ways to rename variables:**

method | operate
:-- | :--
Method 1: Double-click to rename | In the decompilation window, double-click the variable name, enter the new name, and press Enter to confirm.
Method 2: Right-click menu | Right-click on the variable → Rename Variable → Enter the new name → Enter
Method 3: Keyboard shortcuts | After selecting the variable, press the `L` key (lowercase L), enter the new name, and press Enter to confirm.

### 2.7 Reconstructing source code from decompiled results

Based on Ghidra's output, manually rebuild the C code.

Using the pseudocode above as an example, the reconstructed C code is as follows:

```
#include <stdio.h>
#include <string.h>

int main(void)
{
    char password[8];
    
    printf("Enter password: ");
    fgets(password, sizeof(password), stdin);
    
    if (strcmp(password, "secret") == 0) {
        printf("Access granted!\n");
    } else {
        printf("Wrong password!\n");
    }
    
    return 0;
}
```

**Important Note:**

Precautions | illustrate
:-- | :--
Variable names will be lost. | Ghidra will generate a temporary name like `local_18` , which needs to be renamed manually.
Comments completely lost | Comments need to be added again based on the logic.
The code structure may differ. | Compiler optimizations can change code structure
First, analyze simple functions. | Starting with the main function, we will analyze the called sub-functions step by step.
Multiple verifications | Repeated testing ensured that the restored code behaved consistently with the original program.

By following these steps, even without the source code, the logic and functionality of the program can be largely restored.

### 2.8 Verify the recovered code

#### 2.8.1 Compilation Test

```
gcc -o recovered recovered_code.c
./recovered
```

#### 2.8.2 Contrast Behavior

Compare the behavior of the original program and the restored program to see if they are consistent.

### 2.9 Export the disassembled text of the entire program

#### 2.9.1 Complete Export Process

1. Save Project: File → Save Project
2. Export the complete disassembly: File → Export Program → Select ASCII format
3. Exporting decompiled code: Copying pseudocode function by function in the decompilation window.
4. Export Symbol Table: Use a script to export all function and variable names.
5. Organize the output: Organize the exported files into a structured document.

> **Format selection instructions** :
>
> - Choose **ASCII format** : When you need to disassemble code (assembly instructions).
> - **Do not choose the C/C++ format** : unless you need a C array representation of raw binary data.
> - The decompiled C code needs to be obtained from the Decompile window either via a script or by manually copying it.

#### 2.9.2 Export using the File menu

Click File → Export Program... in the menu bar. In the pop-up dialog box, select "ASCII" as the format, set the Output File path and file name, and in Options you can choose to include address, opcode, command, etc.

#### 2.9.3 Batch Export Using Scripts

Open the Script Manager: Window → Script Manager

Search for and run the following script:

Script Name | Function
:-- | :--
ExportAssemblyScript.java | Export assembly code
ExportToCSVScript.java | Export as CSV format
DumpAddressInfoScript.java | Export address information

#### 2.9.4 Deriving Disassembly from Functions

**Exporting a single function** : In the disassembly window, select the function to be exported, right-click → Copy Special → Copy As, and select the format:

- Assembly - Pure assembly code
- Formatted Assembly - Formatted assembly code
- HTML - HTML format

**To export all functions in batches** : Open Window → Function Graph, right-click in the function graph window → Export → Export Graph, and you can choose to export as text or image format.

#### 2.9.5 Exporting using console commands

Open the Ghidra console: Window → Console

Enter the command in the console:

Java

```
// 导出整个程序的反汇编
saveProgramText(currentProgram, "/path/to/output/disassembly.txt");

// 导出特定地址范围
saveAddressRangeText(currentProgram, fromAddr, toAddr, "/path/to/output/range.txt");
```

#### 2.9.6 Saving the Ghidra Project

File → Save Project

This will save all analysis results, annotations, renaming, etc., and the project file can be reopened later to continue the analysis.

#### 2.9.7 Export as binary patch

File → Export → Binary File... You can choose to export the modified binary file.

#### 2.9.8 Enhance export functionality using third-party scripts

Install community script:

```
git clone https://github.com/NationalSecurityAgency/ghidra.git
```

Import useful export scripts into the Script Manager.

#### 2.9.9 Complete Export Script Example

Running the following script in Script Manager will export a complete, annotated disassembly:

Java

```
// 在Script Manager中运行这个脚本可以导出带注释的完整反汇编
import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.*;
import java.io.*;

public class ExportFullDisassembly extends GhidraScript {
    public void run() throws Exception {
        File outputFile = new File("/tmp/full_disassembly.asm");
        PrintWriter writer = new PrintWriter(outputFile);
        
        Listing listing = currentProgram.getListing();
        InstructionIterator instructions = listing.getInstructions(true);
        
        while (instructions.hasNext()) {
            Instruction instruction = instructions.next();
            String line = instruction.getAddress() + " " + instruction.toString();
            writer.println(line);
        }
        
        writer.close();
        println("Disassembly exported to: " + outputFile.getAbsolutePath());
    }
}
```

#### 2.9.10 Manually copy section by section

In the disassembly window, press `Ctrl+A` to select all, `Ctrl+C` to copy, and paste into a text editor. Repeat this process to overwrite all code segments.

### 2.10 Real-world case demonstration

Suppose you have a simple calculator program whose source code has been removed:

**Analysis process:**

1. `strings` analysis revealed the following strings: `"Enter first number:"` , `"Enter second number:"` , and `"Result: %d"`
2. Ghidra decompilation shows:

```
undefined8 main(void)
{
  int iVar1;
  int iVar2;
  printf("Enter first number: ");
  iVar1 = get_number();
  printf("Enter second number: ");
  iVar2 = get_number();
  printf("Result: %d\n",iVar1 + iVar2);
  return 0;
}
```

1. Rebuilt code:

```
#include <stdio.h>

int get_number(void) {
    int num;
    scanf("%d", &num);
    return num;
}

int main(void) {
    int num1, num2;
    printf("Enter first number: ");
    num1 = get_number();
    printf("Enter second number: ");
    num2 = get_number();
    printf("Result: %d\n", num1 + num2);
    return 0;
}
```
