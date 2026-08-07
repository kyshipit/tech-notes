##  

# 1、gdb调试

GDB (GNU Debugger) 是 Linux 下最常用的程序调试工具，可以用于调试 C、、C++ 等程序。

## 1.命令速查表

这个表格涵盖了GDB调试中最常用的命令，方便在调试时快速查阅和使用。

| 类别 | 全命令 | 缩写 | 功能说明 | 
| -- | -- | -- | -- |
| **基本调试** | run | r | 运行程序 | 
|   | quit | q | 退出GDB | 
|   | help | h | 查看帮助 | 
|   | list | l | 显示源代码 | 
|   | print | p | 打印表达式值 | 
|   | next | n | 单步执行（不进入函数） | 
|   | step | s | 单步执行（进入函数） | 
|   | continue | c | 继续执行 | 
|   | finish | fin | 执行到当前函数返回 | 
| **断点管理** | break | b | 设置断点 | 
|   | delete | d | 删除断点 | 
|   | disable | dis | 禁用断点 | 
|   | enable | en | 启用断点 | 
|   | info breakpoints | i b | 显示所有断点 | 
|   | clear | cl | 清除断点 | 
|   | tbreak | tb | 设置临时断点 | 
|   | condition | cond | 设置断点条件 | 
|   | commands | com | 设置断点触发命令 | 
| **栈和帧** | backtrace | bt | 显示调用栈 | 
|   | frame | f | 选择栈帧 | 
|   | up |   | 向上移动栈帧 | 
|   | down |   | 向下移动栈帧 | 
|   | info frame | i f | 显示当前帧信息 | 
|   | info locals | i lo | 显示局部变量 | 
|   | info args | i ar | 显示函数参数 | 
| **变量和内存** | display | disp | 每次停止时显示表达式 | 
|   | undisplay | undisp | 取消显示 | 
|   | watch | wa | 设置监视点 | 
|   | rwatch | rwa | 设置读监视点 | 
|   | awatch | awa | 设置读写监视点 | 
|   | x |   | 检查内存 | 
|   | set variable | set var | 设置变量值 | 
|   | whatis | wh | 显示变量类型 | 
|   | ptype | pt | 显示详细类型信息 | 
| **高级调试** | thread | t | 线程操作 | 
|   | info threads | i th | 显示所有线程 | 
|   | catch | cat | 设置捕获点 | 
|   | signal | sig | 发送信号 | 
|   | return | ret | 强制函数返回 | 
|   | jump | j | 跳转到指定位置 | 
|   | attach | att | 附加到运行进程 | 
|   | detach | det | 分离进程 | 
|   | handle | han | 设置信号处理 | 
|   | set follow-fork-mode |   | 设置fork跟踪模式 | 
| **信息查询** | info registers | i r | 显示寄存器 | 
|   | info program | i prog | 显示程序状态 | 
|   | info signals | i sig | 显示信号信息 | 
|   | info functions | i fun | 显示函数信息 | 
|   | info variables | i var | 显示变量信息 | 
| **其他实用** | shell | sh | 执行shell命令 | 
|   | set logging on/off |   | 开启/关闭日志 | 
|   | define | def | 定义用户命令 | 
|   | source | so | 执行命令文件 | 
|   | show commands | sh com | 显示历史命令 | 
|   | record | rec | 开始执行记录 | 
|   | reverse-step | rs | 反向单步执行 | 


**常用命令示例**

```
# 快速调试流程
gdb ./insertion
(gdb) run 
(gdb) bt      # 当出现segmentation fault时
(gdb) b main          # 在main函数设断点
(gdb) r               # 运行程序
(gdb) n               # 单步执行
(gdb) p variable      # 查看变量
(gdb) bt              # 查看调用栈
(gdb) c               # 继续执行

# 内存检查
(gdb) x/10wx addr     # 查看10个字(16进制)
(gdb) x/20cb buf      # 查看20个字节(字符)
(gdb) x/s str         # 查看字符串

# 条件断点
(gdb) b func if i>5   # i>5时断点触发
(gdb) commands 2      # 为断点2设置命令
> p i
> c
> end


# 1. 启动调试
gdb ./program

# 2. 设置断点
(gdb) b main
(gdb) b suspicious_function

# 3. 运行程序
(gdb) r

# 4. 单步调试
(gdb) n
(gdb) s

# 5. 检查变量
(gdb) p variable
(gdb) i locals

# 6. 检查调用栈
(gdb) bt

# 7. 检查内存
(gdb) x/10wx address

# 8. 继续执行或重新运行
(gdb) c
(gdb) run

```

注释讲解

```bash
(gdb) set logging on      # 开启命令日志

# 开启时有些gdb设置会自动设置 gdb.txt
(gdb) set logging on
Copying output to gdb.txt.
Copying debug output to gdb.txt.

(gdb) set logging file gdb.log  # 设置日志文件

#  跳过库函数
(gdb) n        # 执行下一行，但不进入函数
(gdb) s        # 进入函数内部（会进入printf）

(gdb) finish   # 执行完当前函数，返回到调用处

# 设置跳过标准库
(gdb) skip -gfi /usr/include/*.h
(gdb) skip -gfi /usr/lib/*.so

# 用户自定义命令
(gdb) define mycmd
> print variable1
> print variable2
> backtrace
> end
(gdb) mycmd              # 执行自定义命令


# 设置断点的多种方式
(gdb) b main              # 在main函数设置断点
(gdb) b 15                # 在第15行设置断点
(gdb) b file.c:20         # 在指定文件的第20行设置断点
(gdb) b *0x400512         # 在内存地址设置断点
(gdb) b func if i == 5    # 条件断点

# 内存检查命令
(gdb) x/10wx 0x7fffffffe110  # 查看10个word（16进制）
(gdb) x/20cb buffer          # 查看20个字节（字符形式）
(gdb) x/s ptr                # 查看字符串
(gdb) x/i $pc                # 查看当前指令

# 显示格式控制
(gdb) p/x variable          # 十六进制显示
(gdb) p/d variable          # 十进制显示  
(gdb) p/t variable          # 二进制显示
(gdb) p/c variable          # 字符显示
(gdb) p/a variable          # 地址显示

# 条件调试
(gdb) commands 2           # 为断点2设置命令列表
> p i
> p arr[i]
> c
> end

# 条件调试
(gdb) condition 2 i > 10   # 为断点2设置条件
(gdb) ignore 2 5           # 忽略断点2的前5次触发

# 监视点使用
(gdb) watch variable       # 变量改变时暂停
(gdb) watch *(int*)0x1234  # 监视内存地址
(gdb) rwatch variable      # 变量被读时暂停
(gdb) awatch variable      # 变量被读或写时暂停

# 保存断点配置
(gdb) save breakpoints breakpoints.txt
(gdb) source breakpoints.txt

# 自定义命令
(gdb) define mycmd
> p $arg0
> p $arg1
> end
(gdb) mycmd var1 var2

(gdb) set logging on       # 开启日志
(gdb) set logging file gdb.log
(gdb) set logging off      # 关闭日志

(gdb) target remote :1234  # 连接到远程gdbserver
```

## 2.编译准备

调试编译选项

```bash
# 编译时必须添加 -g 选项保留调试信息
gcc -g -o program program.c

# 或者使用 Makefile 确保包含 -g
CFLAGS = -g -Wall
```

检查调试信息

```bash
# 检查是否包含调试信息
file program
# 输出应该包含: "with debug_info"

readelf -S program | grep debug
```

## 3.启动 GDB

基本启动方式

```bash
# 调试可执行文件
gdb ./program
# 调试运行中的进程
gdb -p <进程ID>
# 调试 core dump 文件
gdb ./program core
```

## 4.基本调试命令

程序执行控制

```bash
(gdb) run [参数]           # 运行程序
(gdb) start               # 开始执行并停在 main 函数
(gdb) continue            # 继续运行
(gdb) next                # 执行下一行（不进入函数）
(gdb) step                # 执行下一行（进入函数）
(gdb) finish              # 运行到当前函数返回
(gdb) until <行号>        # 运行到指定行
(gdb) quit                # 退出 GDB
```

断点管理

```bash
(gdb) break main          # 在 main 函数设置断点
(gdb) break file.c:20     # 在 file.c 第 20 行设置断点
(gdb) break function      # 在指定函数设置断点
(gdb) info breakpoints    # 查看所有断点
(gdb) delete <断点编号>    # 删除断点
(gdb) disable <断点编号>   # 禁用断点
(gdb) enable <断点编号>    # 启用断点
```

观察点（数据断点）

```bash
(gdb) watch variable      # 当变量改变时暂停
(gdb) watch *(0x12345678) # 监视内存地址
(gdb) rwatch variable     # 当变量被读取时暂停
(gdb) awatch variable     # 当变量被读取或写入时暂停
```

## 5.查看代码和变量

代码查看

```bash
(gdb) list                # 显示当前行附近的代码
(gdb) list function       # 显示指定函数的代码
(gdb) list file.c:15      # 显示指定文件的指定行
(gdb) list 10,20          # 显示 10-20 行的代码
```

变量查看

```bash
(gdb) print variable      # 打印变量值
(gdb) print *pointer      # 打印指针指向的值
(gdb) print array[5]      # 打印数组元素
(gdb) print $rax          # 打印寄存器值

(gdb) display variable    # 每次停止时自动显示变量
(gdb) info display        # 查看自动显示列表
(gdb) undisplay <编号>     # 取消自动显示

(gdb) whatis variable     # 查看变量类型
(gdb) ptype variable      # 查看详细类型信息
```

**内存查看**

```bash
(gdb) x/10x &variable     # 以十六进制查看 10 个内存单元
(gdb) x/20s pointer       # 查看 20 个字符串
(gdb) x/g $rsp            # 查看栈指针指向的内容
```

## 6.栈和函数调用

调用栈操作

```bash
(gdb) backtrace           # 显示调用栈
(gdb) backtrace full      # 显示调用栈和局部变量
(gdb) frame <编号>        # 切换到指定栈帧
(gdb) info frame          # 查看当前栈帧信息
(gdb) info locals         # 查看当前栈帧的局部变量
(gdb) info args           # 查看当前函数的参数
```

## 7.高级功能

多线程调试

```bash
(gdb) info threads        # 查看所有线程
(gdb) thread <线程ID>     # 切换到指定线程
(gdb) thread apply all command  # 对所有线程执行命令
```

信号处理

```bash
(gdb) handle SIGSEGV stop  # 当收到 SIGSEGV 时停止
(gdb) info signals        # 查看信号处理设置
```

**条件断点**

```bash
(gdb) break file.c:20 if i == 5     # 条件断点
(gdb) condition <断点号> i > 10     # 为已有断点添加条件
```

## 8. 实际调试示例

示例程序：bubble.c

```c
#include <stdio.h>
#define ARRAY_COUNT(arr) (sizeof(arr) / sizeof(arr[0]))
int arr[] = {9, 23, 86, 12, 34};

int main(int argc, char const *argv[])
{
    int temp = 0;
    for (int i = 0; i < ARRAY_COUNT(arr)-1; i++)
    {
        for (int j = 0; i < ARRAY_COUNT(arr)-i-1; j++)
        {
            if (arr[j] > arr[j+1])
            {
                temp = arr[j];
                arr[j] = arr[j+1];
                arr[j+1] = temp;
        }    
    }
    for (int i = 0; i < ARRAY_COUNT(arr); i++)
    {
        printf("arr[%d] = %d\n", i, arr[i]);
    }
    return 0;
}
```

调试会话示例

```
# 编译
gcc -g -o example bubble.c

# 启动 GDB
gdb ./bubble

# 在 GDB 中的操作：
# 重新运行程序（如果需要）
(gdb) run
# 设置断点在可能出问题的地方
(gdb) break bubble.c:15
# 单步执行
(gdb) next
(gdb) step
# 监视变量变化
(gdb) display j
(gdb) display i
(gdb) display n

# 检查 arr[j] 和 arr[j+1] 是否在有效范围内
(gdb) print j
(gdb) print j+1
(gdb) print n  # 数组长度

# 如果可能，查看这些位置的值
(gdb) print arr[j]
(gdb) print arr[j+1]


(gdb) break factorial      # 在 factorial 函数设置断点
(gdb) run                 # 运行程序
(gdb) print n             # 查看参数 n 的值
(gdb) next                # 单步执行
(gdb) backtrace           # 查看调用栈
(gdb) continue            # 继续执行
(gdb) quit                # 退出
```

## 9. 图形界面模式

**使用 TUI 模式**

```bash
gdb -tui ./program       # 启动文本用户界面

# 在 GDB 中切换 TUI
(gdb) tui enable         # 启用 TUI
(gdb) layout src         # 显示源代码布局
(gdb) layout asm         # 显示汇编布局
(gdb) layout regs        # 显示寄存器布局
```

## 10. 核心转储分析

```bash
# 启用 core dump
ulimit -c unlimited

# 程序崩溃后分析 core 文件
gdb ./program core

# 在 GDB 中
(gdb) backtrace          # 查看崩溃时的调用栈
(gdb) frame 1            # 切换到相关栈帧
(gdb) print variable     # 查看相关变量
```

## 12. 远程调试

```
# 目标机器
gdbserver :1234 ./program

# 开发机器
gdb
(gdb) target remote 目标IP:1234
(gdb) continue
```

掌握这些 GDB 命令和技巧，你就能有效地调试大多数程序问题了！

- -o ： 指定生成目标文件的名字

- -g ： ： gdb  添加调试信息

- -wall ： 显示警告信息

# 2、gdb排查思路

**核心思路**：从宏观症状定位到微观代码错误，通过观察内存状态和程序行为来缩小问题范围。

## **1.排查步骤**

```bash
gcc -g -fsanitize=address -fno-omit-frame-pointer -o insertion insertion.c

(gdb) r
Program received signal SIGSEGV, Segmentation fault

(gdb) bt
#0  0x00000003555550db in ?? ()
(gdb) info registers
rip            0x3555550db         0x3555550db

(gdb) info proc mappings
0x555555554000 0x555555555000  0x1000  0x0 /xxx/deliberate/algorithm/insertion

(gdb) info locals
arr = {10277, -402295808, -1772, -2125934455, 41156}
n = 32767

(gdb) info frame
rip = 0x55555555558a in main (insertion.c:30)
(gdb) list
30      {
    
(gdb) r    
(gdb) n   

# 查看程序映射，确认代码段位置
(gdb) info proc mappings

# 查看崩溃点的汇编代码
(gdb) x/10i $rip

# 查看栈内容
(gdb) x/20xg $rsp

# 查看当前函数的栈帧
(gdb) info frame
(gdb) info args
(gdb) info locals

# 使用Valgrind进行内存检查
valgrind --tool=memcheck --track-origins=yes ./insertion
valgrind --leak-check=full ./insertion
```

各参数作用：

- **-fsanitize=address**：启用AddressSanitizer插桩

- **-fno-omit-frame-pointer**：保留帧指针，便于调试和栈回溯

- **-g**：包含调试信息，使错误报告更清晰

### 第1步：确认问题现象

```bash
(gdb) r
Program received signal SIGSEGV, Segmentation fault
```

- **观察**：程序崩溃，段错误

- **推断**：内存访问违规（访问了不该访问的内存）

1. **映射检查**：地址是否在 info proc mappings 列出的段内

1. **模式检查**：地址是否符合系统内存布局模式

1. **符号检查**：GDB是否能解析出函数名

1. **数值检查**：地址是否包含可疑的数据模式

1. **一致性检查**：与其他寄存器/栈值是否协调

### 第2步：检查崩溃位置

```bash
(gdb) bt
#0  0x00000003555550db in ?? ()
(gdb) info registers
rip            0x3555550db         0x3555550db
```

- **观察**：调用栈异常，rip指向奇怪地址 0x3555550db

- **推断**：**返回地址被破坏**，说明栈内存被意外修改

### 第3步：分析内存映射

```
(gdb) info proc mappings
0x555555554000     0x555555555000     0x1000        0x0 /home/musk/work/deliberate/algorithm/insertion
```

- **观察**：正常代码段在 0x55555555xxxx 范围，但 rip 指向 0x3555550db

- **推断**：控制流被破坏，很可能是**栈溢出**或**缓冲区溢出**

```bash

正常程序地址:   0x55555555558a  (在映射范围内)
异常的 rip:     0x00000003555550db (不在任何映射范围内)
                ^^^^^^^^^^
                异常的高位部

0x555555554000     0x555555555000     /home/musk/work/deliberate/algorithm/insertion
0x555555555000     0x555555556000     /home/musk/work/deliberate/algorithm/insertion
0x555555556000     0x555555557000     /home/musk/work/deliberate/algorithm/insertion
...
0x7ffff7dc9000     0x7ffff7deb000     /usr/lib/x86_64-linux-gnu/libc-2.31.so
0x7ffff7fcf000     0x7ffff7fd0000     /usr/lib/x86_64-linux-gnu/ld-2.31.so

正常地址模式：
程序代码段：0x55555555xxxx
库代码段：  0x7ffff7xxxxxx 或 0x7ffffxxxxxxx
栈：        0x7ffffffxxxxx
异常的 rip：0x00000003555550db
```

### 第4步：检查栈和局部变量状态

```
(gdb) info locals
arr = {10277, -402295808, -1772, -2125934455, 41156}
n = 32767
```

- **关键发现**：局部变量值被破坏

	- arr 不是原始的 {98, 11, 45, 3, 65}

	- n 不是预期的 5 而是 32767

- **推断**：栈内存被意外写入，破坏了局部变量

### 第5步：定位崩溃代码位置

```
(gdb) info frame
rip = 0x55555555558a in main (insertion.c:30)
(gdb) list
30      {
```

- **观察**：崩溃在 main 函数开始处（第30行）

- **推断**：问题发生在函数调用过程中，不是在当前行

### 第6步：使用内存检测工具

```
gcc -g -fsanitize=address -o insertion insertion.c
(gdb) r
```

- **策略**：使用AddressSanitizer自动检测内存错误

- **结果**：精确定位到 insertion.c:19 的栈缓冲区下溢

## 2.问题推理链条

1. **段错误** → 内存访问违规

1. **异常rip地址** → 控制流/返回地址被破坏

1. **局部变量值异常** → 栈内存被意外修改

1. **崩溃在main开始** → 问题发生在之前的函数调用

1. **AddressSanitizer报告** → 精确定位到数组越界访问

## 3.关键排查技巧

### a. 观察内存状态模式

- 局部变量被破坏 → 栈损坏

- 返回地址异常 → 控制流被劫持

- 这些现象都指向**缓冲区溢出**

### b. 使用工具辅助

- **GDB基础命令**：bt, info, x 用于初步定位

- **内存检测工具**：AddressSanitizer, Valgrind 用于精确定位

- **观察点**：watch 监控关键变量变化

### c. 结合算法知识

- 知道是"insertion"程序 → 推测是插入排序

- 插入排序常见错误 → 循环边界问题、索引越界

- 栈缓冲区下溢 → 访问了 arr[-1]

## 4.经验总结

1. **从现象推导原因**：异常现象背后有确定的内存访问错误

1. **层层深入**：从崩溃现象 → 内存状态 → 代码位置 → 具体错误

1. **工具组合使用**：GDB初步定位 + 专业工具精确定位

1. **结合领域知识**：算法特性帮助预测错误类型

这种系统化的排查方法可以应用于各种内存相关问题的调试，关键是建立从现象到原因的推理链条，并善用工具验证每个推断。

# 3、coredump

coredump文件是程序崩溃时操作系统生成的内存转储文件，

它包含了程序崩溃时的内存状态、寄存器值、堆栈信息等，是调试程序崩溃原因的重要工具。

## 1.coredump产生条件

**必要条件：**

- 程序发生严重错误（如段错误、总线错误等）

- 系统coredump功能已启用

- 有足够的磁盘空间

- 有写入权限的目标目录

**常见触发情况：**

- 访问空指针或野指针

- 内存越界访问

- 栈溢出

- 除零错误

- 主动调用abort()函数

在传统的 Linux 环境中，当一个应用程序崩溃时，系统可能会生成一个包含程序崩溃时内存映像的 **core 文件**。kernel.core_pattern 这个内核参数就决定了这些 core 文件的生成方式[](https://book.hacktricks.xyz/zh/linux-hardening/privilege-escalation/docker-security/docker-breakout-privilege-escalation/sensitive-mounts)。WSL 的设计有其特殊之处：

| 设计特征 | 说明 | 
| -- | -- |
| **core_pattern**** 指向管道** | WSL 默认将 kernel.core_pattern设置为一个管道命令，这意味着 core 数据不会直接写入磁盘文件，而是交给一个特定的程序（例如你这里的 /wsl-capture-crash）来处理 | 
| **默认禁止生成 core 文件** | 通过 ulimit -c 0的设置，WSL 默认禁止在容器内生成传统的 core 文件 | 


这样的设计主要带来了两方面好处：

1. **提升系统安全性**：防止 core 文件无意中记录下敏感信息（如密码、密钥等）并留存于磁盘，减少潜在的信息泄露风险。

1. **优化开发体验**：通过管道将崩溃信息传递给特定的处理程序，这个程序可以更灵活地处理这些数据，例如进行格式化、分析，或者与 Windows 侧的调试工具集成，这对于 WSL 与 Windows 主机深度融合的环境尤其有用。

需要特别注意，/proc/sys/kernel/core_pattern 是一个需要重点关注的敏感文件。如果它可被任意写入，尤其是在一些容器环境中，可能会被利用来实现**容器逃逸**或**权限提升**[](https://book.hacktricks.xyz/zh/linux-hardening/privilege-escalation/docker-security/docker-breakout-privilege-escalation/sensitive-mounts)。因此，在 WSL 中，默认通过管道方式处理，并由特定程序接管，本身也是一种安全控制措施。

- **如果你确实需要调试**：可以临时修改 ulimit -c unlimited 并设置 core_pattern 到一个有写入权限的目录（例如 echo "/tmp/core-%e-%p" > /proc/sys/kernel/core_pattern）。但请务必在调试完成后**及时清理 core 文件**，并考虑将设置恢复原状。

- **如果你不需要分析 core 文件**：那么维持 WSL 的默认设置是**最省心、最安全**的选择。

## 2. 无法产生coredump

Segmentation fault (core dumped)

```bash
➜ ./bubble
Segmentation fault (core dumped)
08:36:27 musk@DESKTOP-CNCH3P1:~/work/deliberate/algorithm
➜ ulimit -c
0
➜ cat /proc/sys/kernel/core_pattern
|/wsl-capture-crash %t %E %p %s
#启用后 core-p%p-t%t-e%e

# 检查coredump大小限制
ulimit -c
# 查看所有限制
ulimit -a

# 临时设置（当前会话有效）
ulimit -c unlimited

# 查看当前设置
sysctl kernel.core_pattern
```

相关查询

```bash
# 1. 确认coredump大小限制
ulimit -c
# 如果显示0，表示禁用，需要设置为unlimited

# 2. 检查文件系统权限
# 检查目标目录权限
ls -ld /tmp
# 确保程序有写入权限

# 3. 检查磁盘空间
df -h

# 4. 检查进程资源限制
# 查看进程的限制
cat /proc/<pid>/limits

# 5. 检查程序是否处理了信号
# 有些程序可能会捕获崩溃信号并自行处理：
// 示例：程序捕获了SIGSEGV信号
signal(SIGSEGV, custom_handler);

# 6. 使用strace跟踪系统调用
strace -f -o strace.log ./your_program


# 7. 检查apport或abrt服务（Ubuntu/CentOS）
# Ubuntu
sudo service apport status
# CentOS/RHEL
sudo service abrt status
```

## 3.启用coredump生成

**wsl矛盾显示**

```c
➜ ./bubble
Segmentation fault (core dumped)
08:36:27 musk@DESKTOP-CNCH3P1:~/work/deliberate/algorithm
ulimit -c  //0
cat /proc/sys/kernel/core_pattern   // |/wsl-capture-crash %t %E %p %s
#启用后 core-p%p-t%t-e%e

echo "core-p%p-t%t-%e" | sudo tee /proc/sys/kernel/core_pattern
ulimit -c unlimited 
ulimit -c #确认是 unlimited
gcc -g -o bubble bubble.c
./bubble
ls -la core-*
gdb ./bubble core-<pid>
    (gdb) bt
```

- %p - 进程ID (PID)

- %t - 转储时间（UNIX时间戳）

- %e - 可执行文件名

现在运行程序就会在当前目录生成 core 或 core.<pid> 文件。

这是WSL的默认配置，核心转储通过管道发送给 wsl-capture-crash 服务，不生成传统 core 文件。

WSL 的核心转储机制：

1. 内核检测到段错误 → 准备生成核心转储

1. 检查 core_pattern → 发现要发送给 /wsl-capture-crash

1. 显示消息 → 内核固定显示 "Segmentation fault (core dumped)"

1. 实际处理 → WSL 的 CaptureCrash 服务接收并处理崩溃信息

1. 文件系统层面 → 没有生成传统的 core 文件，所以 ulimit -c 0 仍然有效

为什么显示 "core dumped"：

- 内核的消息文本是硬编码的，它不知道也不关心实际转储目标

- 从内核视角看，它确实"dumped"了核心信息 - 只是通过管道而不是文件

- WSL 选择保留这个传统消息，即使实际机制不同

WSL 的特殊设计：

WSL 使用自己的崩溃捕获系统 (wsl-capture-crash) 来：

- 在 Windows 和 Linux 环境间更好地集成崩溃报告

- 可能将崩溃信息发送到 Windows 事件日志或诊断系统

- 避免在 WSL 文件系统中生成可能很大的核心转储文件

这个矛盾是 WSL 设计决策的结果：

- 传统 Linux 行为：核心转储 → 文件 → 受 ulimit 限制

- WSL 行为：核心转储 → 管道 → 专用服务 → 不受传统 ulimit 文件限制影响

所以 "Segmentation fault (core dumped)" 在 WSL 中应该理解为"发生了段错误并且崩溃信息已被捕获"，而不一定是"生成了核心转储文件"。

在 WSL 的这种配置下，要生成**传统的核心转储文件**，你需要修改核心转储配置。以下是几种方法：

```bash
# 方法1：临时有效，重启 WSL 或系统后会恢复默认
echo "core-%e-%t-%p" | sudo tee /proc/sys/kernel/core_pattern
# 确认修改成功
cat /proc/sys/kernel/core_pattern


#方法2：永久修改 core_pattern，对于wsl重启失效
# 编辑 sysctl 配置
sudo vim /etc/sysctl.conf
# 添加以下行：
kernel.core_pattern=core-%e-%t-%p
kernel.core_uses_pid=1
# 立即应用配置
sudo sysctl -p

# 立即恢复 WSL 默认（不用等重启）
echo "|/wsl-capture-crash %t %E %p %s" | sudo tee /proc/sys/kernel/core_pattern
```

## 4. 调试coredump文件

基本调试命令：

```bash
# 加载coredump文件
gdb <程序路径> <coredump文件路径>

# 示例
gdb /usr/bin/myapp /tmp/core-myapp-12345-1623456789
```

**常用GDB命令：**

```bash
# 查看崩溃位置
(gdb) bt
(gdb) where

# 查看详细的堆栈信息
(gdb) bt full

# 查看寄存器状态
(gdb) info registers

# 查看变量值
(gdb) print variable_name

# 查看局部变量
(gdb) info locals

# 查看线程信息
(gdb) info threads

# 切换到特定线程
(gdb) thread 2

# 查看内存映射
(gdb) info proc mappings

# 反汇编当前函数
(gdb) disassemble

# 查看信号信息
(gdb) info signals
```

实际调试示例：

```bash
# 1. 编译程序（记得加上-g选项）
gcc -g -o test test.c

# 2. 运行程序产生coredump
./test

# 3. 使用gdb分析
gdb ./test core

# 4. 在gdb中分析
(gdb) bt
#0  0x0000000000400556 in main () at test.c:8
(gdb) print variable_name
(gdb) info locals
```

## 5. 高级调试技巧

**分析内存泄漏**

```bash
(gdb) info proc mappings
(gdb) x/100x 0x7fffe0000000  # 检查内存区域
```

**多线程调试：**

```bash
(gdb) info threads
(gdb) thread apply all bt  # 查看所有线程堆栈
```

**检查核心数据结构：**

```
(gdb) p *global_ptr
(gdb) p array[10]@20  # 查看数组内容
```

## 6. 自动化脚本示例

创建调试脚本：

```bash
#!/bin/bash
# debug_core.sh

if [ $# -ne 2 ]; then
    echo "用法: $0 <程序路径> <coredump路径>"
    exit 1
fi

PROGRAM=$1
COREFILE=$2

gdb -q $PROGRAM $COREFILE << EOF
set pagination off
bt
info registers
thread apply all bt
quit
EOF
```

## 7. 预防措施

**编译时选项：**

```bash
# 添加调试信息
gcc -g -o program program.c

# 添加堆栈保护
gcc -fstack-protector-all -o program program.c

# 启用所有警告
gcc -Wall -Wextra -o program program.c
```

运行时检查：

```bash
# 使用valgrind检查内存问题
valgrind --tool=memcheck ./program

# 使用AddressSanitizer
gcc -fsanitize=address -g -o program program.c
```

通过以上方法，你应该能够有效地处理coredump文件的生成、排查和调试问题。

# 4、ghidra安装包

## 1.工具安装

**需要保存的文件：**

- **ghidra_10.3.2_PUBLIC** ✅ (**必须保留)**

- 这是Ghidra的实际程序文件

- 删除后Ghidra将无法运行

```bash
# 更新包管理器
sudo apt update

# 安装基础工具
sudo apt install binutils gdb build-essential

# 源码安装radare2，最新版支持Ghidra
git clone https://github.com/radareorg/radare2
cd radare2 && sys/install.sh
# 或者使用snap安装最新版
sudo snap install radare2

# 安装Ghidra（需要Java 11+）
wget https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_10.3.2_build/ghidra_10.3.2_PUBLIC_20230711.zip
unzip ghidra_10.3.2_PUBLIC_20230711.zip

# 安装OpenJDK 17（推荐，因为Ghidra兼容性好）
sudo apt install openjdk-17-jdk
```

## 2.环境配置

**JAVAH检测**

```bash
echo $PATH
echo $PATH | tr ':' '\n' | grep tools

# 检查JAVA_HOME是否在环境中
env | grep JAVA

# 检查当前PATH
echo $PATH | tr ':' '\n' | grep jvm

# 直接测试Java是否可用
java -version
javac -version

# 手动执行配置，直接执行设置命令
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH

# 立即测试
echo $JAVA_HOME
java -version
```

**验证当前使用的 radare2**

```bash
# 检查当前使用的是哪个 radare2
which r2

# 检查版本（确认是 apt 安装的版本）
r2 -v

#如果输出显示版本信息和路径在/usr/bin/r2，说明使用的是apt版本
#在/usr/local/bin/r2，r2 -v版本信息git commit hash，是源码
```

## 3.脚本启动

**方法1：添加到PATH环境变量**

```bash
# 添加到 ~/.bashrc
# echo 'alias ghidra="cd /home/xxx/ghidra_10.3.2_PUBLIC && ./ghidraRun"' >> ~/.bashrc

# 将Ghidra目录添加到PATH
echo 'export PATH=$PATH:~/ghidra_10.3.2_PUBLIC' >> ~/.bashrc
source ~/.bashrc

# 检查.bashrc文件末尾是否有设置
tail -10 ~/.bashrc

# 现在可以直接运行（虽然还是会进入目录，但更方便）
ghidraRun
```

**方法2：创建便捷启动脚本**

```bash
# 在主目录创建启动脚本
echo '#!/bin/bash
cd ~/ghidra_10.3.2_PUBLIC
./ghidraRun' > ~/ghidra.sh

chmod +x ~/ghidra.sh

# 现在可以通过这个脚本启动
~/ghidra.sh
```

**验证当前安装**

```bash
# 查看Ghidra实际位置
find ~ -name "ghidraRun" 2>/dev/null

# 查看磁盘使用情况
du -sh ~/ghidra_10.3.2_PUBLIC/
```

## 4.进程检测

```bash
# 检查 Ghidra 和 Java 进程
ps aux | grep ghidra
ps aux | grep java

# 或者使用 jps 查看 Java 进程
jps -l | grep ghidra
# 检查 Ghidra 和 Java 进程
ps aux | grep ghidra
ps aux | grep java

# 或者使用 jps 查看 Java 进程
jps -l | grep ghidra

# 查看进程树
# 查看是否有残留的 Java 进程
pstree | grep -i java
```

# **5、Ghidra反汇编**

## 1.基础文件分析

**1.1、查看文件信息**

```bash
file your_program
```

这会告诉你文件类型，比如：ELF 64-bit LSB executable, x86-64

**1.2、检查是否包含调试符号**

```bash
nm your_program
```

如果有输出，说明包含符号信息，恢复会容易很多。如果没输出或显示"no symbols"，说明符号被剥离了。

**1.3、提取字符串**

```bash
strings your_program > strings.txt
less strings.txt
```

这会提取所有可读字符串，帮你了解程序可能的功能。

## 2.objdump反汇编

**2.1、反汇编整个程序**

```bash
objdump -d -M intel your_program > full_disassembly.asm
```

**2.2、只反汇编代码段**

```bash
objdump -d -M intel --disassemble=.text your_program > code_section.asm
```

**2.3、查看特定函数**

```bash
# 先找到main函数地址
objdump -t your_program | grep main

# 反汇编main函数
objdump -d -M intel --start-address=0x401050 --stop-address=0x401150 your_program
```

## 3.GDB动态分析

**3.1、启动GDB**

```bash
gdb your_program
```

**3.2、GDB基本命令**

```bash
(gdb) info functions          # 列出所有函数
(gdb) disas main             # 反汇编main函数
(gdb) break main             # 在main函数设置断点
(gdb) run                    # 运行程序
(gdb) stepi                  # 单步执行汇编指令
(gdb) info registers         # 查看寄存器状态
(gdb) x/10i $pc             # 查看当前指令附近10条指令
(gdb) quit                   # 退出
```

## 4.radare2高级分析

**4.1、初始分析**

```bash
r2 -A your_program
```

-A 参数执行自动分析。

**4.2 radare2交互命令**

```bash
[0x00000000]> aa              # 自动分析
[0x00000000]> afl             # 列出所有函数
[0x00000000]> s main          # 跳转到main函数
[0x00000000]> pdf             # 反汇编当前函数
[0x00000000]> pdb             # 显示调试器信息
[0x00000000]> iz              # 列出数据段中的字符串
```

**4.3、详细函数分析**

```bash
[0x00000000]> pdf @@ *       # 反汇编所有函数
[0x00000000]> graph          # 显示控制流图
```

## 5.Ghidra反编译

**（最重要的一步）**

**5.1、启动Ghidra**

```bash
cd ghidra_10.3.2_PUBLIC
./ghidraRun
```

**5.2、创建项目和分析文件**

1. **File → New Project** → Non-shared project → 输入项目名

1. **File → Import File** → 选择你的可执行文件

1. 双击导入的文件打开Code Browser

1. 点击"Yes"开始自动分析

**5.3、定位关键函数**

1. 在左侧"Symbol Tree"窗口展开"Functions"

1. 找到并双击main函数

1. 查看右侧"Decompile"窗口显示的伪代码

**5.4、分析伪代码示例**

假设Ghidra显示：

```c
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

**5.5、重命名变量和函数**

在Ghidra中双击变量名可以重命名，使其更有意义。

1. 在左侧 **Symbol Tree** 中展开 **Functions** 文件夹

1. 双击你想要分析的函数（如 main）

1. 右侧会出现三个主要窗口：

	- **左侧**：汇编代码窗口

	- **中间**：反编译窗口（显示伪C代码）

	- **右侧**：各种信息面板

**重命名变量的方法**

方法1：双击重命名

- 在**反编译窗口**中直接双击你想要重名的变量

- 变量名会变为可编辑状态

- 输入新的名称，然后按 **Enter** 确认

方法2：右键菜单

- 在变量上**右键点击**

- 选择 **"Rename Variable"**

- 输入新名称，按 **Enter** 确认

方法3：快捷键

- 选中变量后按 **L** 键（小写L）

- 输入新名称，按 **Enter** 确认

## 6.从反编译结果重建源代码

根据Ghidra的输出，手动重建C代码：

```c
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

## 7.验证恢复的代码

**7.1、编译测试**

```bash
gcc -o recovered recovered_code.c
./recovered
```

**7.2、对比行为**

比较原始程序和恢复后程序的行为是否一致。

**重要提示**

1. 变量名会丢失 - Ghidra会生成类似local_18的临时名称

1. 注释完全丢失 - 需要根据逻辑重新添加

1. 代码结构可能不同 - 编译器优化会改变代码结构

1. 先分析简单函数 - 从main函数开始，逐步分析调用的子函数

1. 多次验证 - 反复测试确保恢复的代码行为与原始程序一致

按照这些步骤，即使没有源代码，也能很大程度上恢复程序的逻辑和功能。

## 8.导出整个程序的反汇编文本

**推荐的完整导出流程**

1. **首先保存项目**：File → Save Project

1. **导出完整反汇编**：File → Export Program → 选择ASCII格式

1. **导出反编译代码**：在反编译窗口中逐个函数复制伪代码

1. **导出符号表**：使用脚本导出所有函数和变量名

1. **整理输出**：将导出的文件整理成有结构的文档

获取完整反汇编代码的最佳方式，**File → Export Program → ASCII格式**

- **选择ASCII格式**：当您需要**反汇编代码**（汇编指令）时

- **不要选择C/C++格式**：除非您需要原始二进制数据的C数组表示

- **反编译的C代码**：需要通过脚本或手动复制从Decompile窗口获取

**1.使用文件菜单导出**

1. 点击菜单栏 **File** → **Export Program...**

1. 在弹出的对话框中选择格式为 **"ASCII"**

1. 选择导出选项：

	- **Output Format**: ASCII

	- **Output File**: 选择保存路径和文件名

	- **Options**: 可以选择包含地址、操作码、指令等

**2.使用脚本批量导出**

1. 打开脚本管理器：**Window** → **Script Manager**

1. 搜索并运行以下脚本：

	- ExportAssemblyScript.java - 导出汇编代码

	- ExportToCSVScript.java - 导出为CSV格式

	- DumpAddressInfoScript.java  导出地址信息

**3.分函数导出反汇编**

单个函数导出

1. 在反汇编窗口中选择要导出的函数

1. 右键点击 → **Copy Special** → **Copy As**

1. 选择格式：

	- **Assembly** - 纯汇编代码

	- **Formatted Assembly** - 带格式的汇编代码

	- **HTML** - HTML格式

批量导出所有函数

1. 打开 **Window** → **Function Graph**

1. 在函数图窗口中，右键 → **Export** → **Export Graph**

1. 可以选择导出为文本或图像格式

**4.使用控制台命令导出**

打开Ghidra控制台

1. **Window** → **Console**

1. 在控制台中输入命令：

```java
// 导出整个程序的反汇编
saveProgramText(currentProgram, "/path/to/output/disassembly.txt");

// 导出特定地址范围
saveAddressRangeText(currentProgram, fromAddr, toAddr, "/path/to/output/range.txt");
```

**5.保存Ghidra项目（包含所有分析数据）**

保存完整项目

1. **File** → **Save Project**

1. 这会保存所有分析结果、注释、重命名等

1. 项目文件可以在以后重新打开继续分析

**6.导出为二进制补丁**

1. **File** → **Export** → **Binary File...**

1. 可以选择导出修改后的二进制文件

**7.使用第三方脚本增强导出功能**

安装社区脚本，下载Ghidra社区脚本：

```bash
git clone https://github.com/NationalSecurityAgency/ghidra.git
```

在Script Manager中导入有用的导出脚本

常用导出脚本示例

```bash
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

**8.逐部分手动复制**

分段复制

1. 在反汇编窗口中按 **Ctrl+A** 全选

1. **Ctrl+C** 复制

1. 粘贴到文本编辑器中

1. 重复此过程覆盖所有代码段

## 9.实际案例演示

假设你有一个简单的计算器程序被删除了源代码：

**分析过程：**

1. **strings分析**发现字符串："Enter first number:", "Enter second number:", "Result: %d"

1. **Ghidra反编译**显示：

```c
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

**重建的代码：**

```c
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
