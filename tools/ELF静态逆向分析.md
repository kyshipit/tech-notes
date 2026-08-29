<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2026 KY (kyshipit)
-->

# 第一篇：ELF静态逆向分析——Ghidra从安装到反编译重建源码

> **适用场景**：你只有一个二进制可执行文件，没有源代码，想搞清楚这个程序干了什么，甚至恢复出接近源码的逻辑。
>
> **本文不涉及动态调试**（程序运行起来之后的分析），只做静态分析。
>
> **什么是静态分析**：不运行程序，直接分析二进制文件本身。通过查看文件信息、提取字符串、反汇编、反编译等手段，还原程序逻辑。Ghidra是目前最强大的开源反编译工具，能把汇编代码还原成可读性很高的C伪代码。

## 第一章 Ghidra安装与环境配置

### 1.1 工具安装

#### 1.1.1 更新包管理器并安装基础工具

```
sudo apt update
sudo apt install binutils gdb build-essential
```

#### 1.1.2 安装radare2（源码方式，最新版）

```
git clone https://github.com/radareorg/radare2
cd radare2 && sys/install.sh
```

或使用snap安装最新版：

```
sudo snap install radare2
```

#### 1.1.3 安装Ghidra（需要Java 11+）

下载Ghidra 10.3.2：

```
wget https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_10.3.2_build/ghidra_10.3.2_PUBLIC_20230711.zip
unzip ghidra_10.3.2_PUBLIC_20230711.zip
```

> **重要**：`ghidra_10.3.2_PUBLIC` 目录必须保留，这是Ghidra的实际程序文件，删除后Ghidra将无法运行。

#### 1.1.4 安装OpenJDK 17（推荐，兼容性好）

```
sudo apt install openjdk-17-jdk
```

### 1.2 环境配置

#### 1.2.1 检查JAVA_HOME环境变量

```
echo $PATH
echo $PATH | tr ':' '\n' | grep tools
```

检查JAVA_HOME是否在环境中：

```
env | grep JAVA
```

检查当前PATH中是否包含JVM路径：

```
echo $PATH | tr ':' '\n' | grep jvm
```

直接测试Java是否可用：

```
java -version
javac -version
```

#### 1.2.2 手动配置JAVA_HOME

如果Java未正确配置，手动执行：

```
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
```

立即测试配置是否生效：

```
echo $JAVA_HOME
java -version
```

#### 1.2.3 验证当前使用的radare2版本

检查当前使用的是哪个radare2：

```
which r2
```

检查版本（确认是apt安装的版本）：

```
r2 -v
```

- 如果输出显示版本信息和路径在 `/usr/bin/r2`，说明使用的是apt版本
- 如果路径在 `/usr/local/bin/r2`，`r2 -v` 显示git commit hash，说明是源码安装版本

### 1.3 脚本启动

#### 方法1：添加到PATH环境变量

```
# 将Ghidra目录添加到PATH
echo 'export PATH=$PATH:~/ghidra_10.3.2_PUBLIC' >> ~/.rc
source ~/.rc

# 检查.rc文件末尾是否有设置
tail -10 ~/.rc
```

现在可以直接运行：
```
ghidraRun
```

#### 方法2：创建便捷启动脚本

```
# 在主目录创建启动脚本
echo '#!/bin/
cd ~/ghidra_10.3.2_PUBLIC
./ghidraRun' > ~/ghidra.sh

chmod +x ~/ghidra.sh
```

通过脚本启动：
```
~/ghidra.sh
```

#### 验证当前安装

查看Ghidra实际位置：

```
find ~ -name "ghidraRun" 2>/dev/null
```

### 1.4 进程检测

检查Ghidra和Java进程：

```
ps aux | grep ghidra
ps aux | grep java
```

或使用jps查看Java进程：
```
jps -l | grep ghidra
```

查看进程树，检查是否有残留的Java进程：
```
pstree | grep -i java
```

## 第二章 Ghidra反汇编与逆向分析

### 2.1 反汇编工具链概览

**三种工具的关系：**

| 工具    | 定位                    | 适用场景              |
| :------ | :---------------------- | :-------------------- |
| objdump | Linux自带，快速查看汇编 | 初步了解程序结构      |
| radare2 | 命令行交互式逆向框架    | 脚本化分析、远程分析  |
| Ghidra  | 图形化反编译工具        | 深度分析，还原C伪代码 |

**标准工作流程：**

```
file/nm/strings 摸底 → objdump 看汇编 → radare2 深入探索 → Ghidra 反编译重建源码
```

### 2.2 基础文件分析

#### 2.2.1 查看文件信息

```
file your_program
```

输出示例：`ELF 64-bit LSB executable, x86-64`

#### 2.2.2 检查是否包含调试符号

```
nm your_program
```

- 如果有输出，说明包含符号信息，恢复会容易很多
- 如果没输出或显示 `no symbols`，说明符号被剥离了

#### 2.2.3 提取字符串

```
strings your_program > strings.txt
less strings.txt
```

这会提取所有可读字符串，帮你了解程序可能的功能。

### 2.3 objdump反汇编

#### 2.3.1 反汇编整个程序

```
objdump -d -M intel your_program > full_disassembly.asm
```

#### 2.3.2 只反汇编代码段

```
objdump -d -M intel --disassemble=.text your_program > code_section.asm
```

#### 2.3.3 查看特定函数

先找到main函数地址：

```
objdump -t your_program | grep main
```

反汇编main函数（以地址0x401050到0x401150为例）：

```
objdump -d -M intel --start-address=0x401050 --stop-address=0x401150 your_program
```

### 2.4 radare2安装与使用

#### 2.4.1 安装说明

radare2已在1.1.2节完成安装，可通过以下命令验证：

```
which r2        # 确认路径
r2 -v           # 确认版本
```

#### 2.4.2 初始分析

```
r2 -A your_program
```

`-A` 参数执行自动分析。

#### 2.4.3 radare2交互命令

进入radare2交互环境后，常用命令：

```
[0x00000000]> aa              # 自动分析
[0x00000000]> afl             # 列出所有函数
[0x00000000]> s main          # 跳转到main函数
[0x00000000]> pdf             # 反汇编当前函数
[0x00000000]> pdb             # 显示调试器信息
[0x00000000]> iz              # 列出数据段中的字符串
```

#### 2.4.4 详细函数分析

```
[0x00000000]> pdf @@ *       # 反汇编所有函数
[0x00000000]> graph          # 显示控制流图
```

### 2.5 GDB动态分析（辅助反汇编场景）

在静态分析过程中，有时需要用GDB辅助查看运行时的汇编信息。

启动GDB：

```
gdb your_program
```

GDB中常用反汇编相关命令：

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

### 2.6 Ghidra反编译（最重要的一步）

#### 2.6.1 启动Ghidra

```
cd ~/ghidra_10.3.2_PUBLIC
./ghidraRun
```

#### 2.6.2 创建项目和分析文件

1. File → New Project → Non-shared project → 输入项目名
2. File → Import File → 选择你的可执行文件
3. 双击导入的文件打开Code Browser
4. 点击"Yes"开始自动分析

#### 2.6.3 定位关键函数

在左侧"Symbol Tree"窗口展开"Functions"，找到并双击`main`函数。

右侧会出现三个主要窗口：

- **左侧**：汇编代码窗口
- **中间**：反编译窗口（显示伪C代码）
- **右侧**：各种信息面板

#### 2.6.4 分析伪代码示例

假设Ghidra显示：

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

#### 2.6.5 重命名变量和函数

在Ghidra中重命名变量，使其更有意义。

**重命名变量的三种方法：**

| 方法              | 操作                                                    |
| :---------------- | :------------------------------------------------------ |
| 方法1：双击重命名 | 在反编译窗口中直接双击变量名，输入新名称，按Enter确认   |
| 方法2：右键菜单   | 在变量上右键点击 → Rename Variable → 输入新名称 → Enter |
| 方法3：快捷键     | 选中变量后按 `L` 键（小写L），输入新名称，按Enter确认   |

### 2.7 从反编译结果重建源代码

根据Ghidra的输出，手动重建C代码。

以上面的伪代码为例，重建后的C代码：

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

**重要提示：**

| 注意事项         | 说明                                               |
| :--------------- | :------------------------------------------------- |
| 变量名会丢失     | Ghidra会生成类似`local_18`的临时名称，需手动重命名 |
| 注释完全丢失     | 需要根据逻辑重新添加注释                           |
| 代码结构可能不同 | 编译器优化会改变代码结构                           |
| 先分析简单函数   | 从main函数开始，逐步分析调用的子函数               |
| 多次验证         | 反复测试确保恢复的代码行为与原始程序一致           |

按照这些步骤，即使没有源代码，也能很大程度上恢复程序的逻辑和功能。

### 2.8 验证恢复的代码

#### 2.8.1 编译测试

```
gcc -o recovered recovered_code.c
./recovered
```

#### 2.8.2 对比行为

比较原始程序和恢复后程序的行为是否一致。

### 2.9 导出整个程序的反汇编文本

#### 2.9.1 完整导出流程

1. 保存项目：File → Save Project
2. 导出完整反汇编：File → Export Program → 选择ASCII格式
3. 导出反编译代码：在反编译窗口中逐个函数复制伪代码
4. 导出符号表：使用脚本导出所有函数和变量名
5. 整理输出：将导出的文件整理成有结构的文档

> **格式选择说明**：
>
> - 选择 **ASCII格式**：当您需要反汇编代码（汇编指令）时
> - **不要选择C/C++格式**：除非您需要原始二进制数据的C数组表示
> - 反编译的C代码需要通过脚本或手动复制从Decompile窗口获取

#### 2.9.2 使用文件菜单导出

点击菜单栏 File → Export Program...，在弹出的对话框中选择格式为 "ASCII"，设置Output File路径和文件名，Options中可选择包含地址、操作码、指令等。

#### 2.9.3 使用脚本批量导出

打开脚本管理器：Window → Script Manager

搜索并运行以下脚本：

| 脚本名称                   | 功能          |
| :------------------------- | :------------ |
| ExportAssemblyScript.java  | 导出汇编代码  |
| ExportToCSVScript.java     | 导出为CSV格式 |
| DumpAddressInfoScript.java | 导出地址信息  |

#### 2.9.4 分函数导出反汇编

**单个函数导出**：在反汇编窗口中选择要导出的函数，右键点击 → Copy Special → Copy As，选择格式：

- Assembly - 纯汇编代码
- Formatted Assembly - 带格式的汇编代码
- HTML - HTML格式

**批量导出所有函数**：打开 Window → Function Graph，在函数图窗口中右键 → Export → Export Graph，可选择导出为文本或图像格式。

#### 2.9.5 使用控制台命令导出

打开Ghidra控制台：Window → Console

在控制台中输入命令：

java
```
// 导出整个程序的反汇编
saveProgramText(currentProgram, "/path/to/output/disassembly.txt");

// 导出特定地址范围
saveAddressRangeText(currentProgram, fromAddr, toAddr, "/path/to/output/range.txt");
```

#### 2.9.6 保存Ghidra项目

File → Save Project

这会保存所有分析结果、注释、重命名等，项目文件可以在以后重新打开继续分析。

#### 2.9.7 导出为二进制补丁

File → Export → Binary File... 可以选择导出修改后的二进制文件。

#### 2.9.8 使用第三方脚本增强导出功能

安装社区脚本：

```
git clone https://github.com/NationalSecurityAgency/ghidra.git
```

在Script Manager中导入有用的导出脚本。

#### 2.9.9 完整导出脚本示例

在Script Manager中运行以下脚本可以导出带注释的完整反汇编：

java
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

#### 2.9.10 逐部分手动复制

在反汇编窗口中按 `Ctrl+A` 全选，`Ctrl+C` 复制，粘贴到文本编辑器中，重复此过程覆盖所有代码段。

### 2.10 实际案例演示

假设你有一个简单的计算器程序被删除了源代码：

**分析过程：**

1. `strings` 分析发现字符串：`"Enter first number:"`、`"Enter second number:"`、`"Result: %d"`
2. Ghidra反编译显示：

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

3. 重建的代码：
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

