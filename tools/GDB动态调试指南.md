<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2026 KY (kyshipit)
-->

# 第二篇：GDB动态调试完全指南——从coredump分析到主动调试

> **适用场景：**
>
> - 程序运行中崩溃了，需要定位崩溃原因
> - 程序行为异常，需要跟踪执行流程
> - 想观察程序运行时的内存状态和变量变化
>
> **本文能帮你解决什么问题：**
>
> - 程序崩溃了怎么拿到coredump、怎么分析
> - 怎么从崩溃现场反推根因
> - 怎么主动调试一个正在运行或即将运行的程序
>
> **动态调试 vs 静态分析的区别：**
>
> - 动态调试：程序实际运行起来，观察执行过程
> - 静态分析：不运行程序，直接分析二进制文件
> - 两者互补，动态调试解决“哪里崩了”，静态分析解决“这个程序逻辑是什么”

## 第一章 Coredump基础与配置

### 1.1 什么是coredump

coredump文件是程序崩溃时操作系统生成的内存转储文件，它包含了程序崩溃时的内存状态、寄存器值、堆栈信息等，是调试程序崩溃原因的重要工具。

### 1.2 coredump产生条件

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

### 1.3 无法产生coredump的排查方法

#### 1.3.1 检查coredump大小限制

```
ulimit -c
```
如果显示0，表示禁用，需要设置为unlimited。

查看所有限制：
```
ulimit -a
```

临时设置（当前会话有效）：
```
ulimit -c unlimited
```

#### 1.3.2 检查文件系统权限

检查目标目录权限：
```
ls -ld /tmp
```
确保程序有写入权限。


#### 1.3.3 检查进程资源限制

查看进程的限制：
```
cat /proc/<pid>/limits
```

#### 1.3.4 检查程序是否处理了信号

有些程序可能会捕获崩溃信号并自行处理：
```
// 示例：程序捕获了SIGSEGV信号
signal(SIGSEGV, custom_handler);
```

#### 1.3.6 使用strace跟踪系统调用
```
strace -f -o strace.log ./your_program
```

#### 1.3.7 检查apport或abrt服务

Ubuntu/Debian：
```
sudo service apport status
```

CentOS/RHEL：
```
sudo service abrt status
```

### 1.4 WSL特殊机制说明

在传统的Linux环境中，当一个应用程序崩溃时，系统可能会生成一个包含程序崩溃时内存映像的core文件。`kernel.core_pattern`这个内核参数就决定了这些core文件的生成方式。WSL的设计有其特殊之处：

| 设计特征             | 说明                                                         |
| :------------------- | :----------------------------------------------------------- |
| core_pattern指向管道 | WSL默认将kernel.core_pattern设置为一个管道命令，core数据不会直接写入磁盘文件，而是交给特定的程序（如 `/wsl-capture-crash`）处理 |
| 默认禁止生成core文件 | 通过 `ulimit -c 0` 的设置，WSL默认禁止在容器内生成传统的core文件 |

**这样设计的好处：**

- 提升系统安全性：防止core文件无意中记录下敏感信息（如密码、密钥等）并留存于磁盘
- 优化开发体验：通过管道将崩溃信息传递给特定的处理程序，可进行格式化、分析，或与Windows侧的调试工具集成

**安全提醒：** `/proc/sys/kernel/core_pattern` 是一个需要重点关注的敏感文件。如果它可被任意写入，尤其是在容器环境中，可能会被利用来实现容器逃逸或权限提升。

**WSL的核心转储机制：**

```
内核检测到段错误 → 准备生成核心转储
        ↓
检查 core_pattern → 发现要发送给 /wsl-capture-crash
        ↓
显示消息 → 内核固定显示 "Segmentation fault (core dumped)"
        ↓
实际处理 → WSL 的 CaptureCrash 服务接收并处理崩溃信息
        ↓
文件系统层面 → 没有生成传统的 core 文件
```

**为什么显示 "core dumped"：**

- 内核的消息文本是硬编码的，它不知道也不关心实际转储目标
- 从内核视角看，它确实"dumped"了核心信息——只是通过管道而不是文件
- WSL选择保留这个传统消息，即使实际机制不同

**传统Linux vs WSL行为对比：**

| 行为             | 传统Linux | WSL                  |
| :--------------- | :-------- | :------------------- |
| 核心转储目标     | 文件      | 管道 → 专用服务      |
| 受ulimit -c限制  | 是        | 不受传统文件限制影响 |
| 是否生成core文件 | 生成      | 不生成               |

所以 `Segmentation fault (core dumped)` 在WSL中应理解为"发生了段错误并且崩溃信息已被捕获"，而不一定是"生成了核心转储文件"。

### 1.5 启用coredump生成

在WSL的这种配置下，要生成传统的核心转储文件，需要修改核心转储配置。

#### 方法1：临时有效（重启WSL或系统后恢复默认）

```
echo "core-%e-%t-%p" | sudo tee /proc/sys/kernel/core_pattern
```

确认修改成功：
```
cat /proc/sys/kernel/core_pattern
```

#### 方法2：永久修改（对于WSL重启失效，适用于传统Linux）

编辑sysctl配置：
```
sudo vim /etc/sysctl.conf
```

添加以下行：
```
kernel.core_pattern=core-%e-%t-%p
kernel.core_uses_pid=1
```

立即应用配置：
```
sudo sysctl -p
```

#### 方法3：恢复WSL默认
```
echo "|/wsl-capture-crash %t %E %p %s" | sudo tee /proc/sys/kernel/core_pattern
```

**格式说明：**

| 占位符 | 含义                   |
| :----- | :--------------------- |
| %p     | 进程ID (PID)           |
| %t     | 转储时间（UNIX时间戳） |
| %e     | 可执行文件名           |

**完整操作流程示例：**

```
# 1. 检查当前限制
ulimit -c
# 输出: 0

# 2. 检查core_pattern
cat /proc/sys/kernel/core_pattern
# 输出: |/wsl-capture-crash %t %E %p %s

# 3. 启用coredump
echo "core-p%p-t%t-%e" | sudo tee /proc/sys/kernel/core_pattern
ulimit -c unlimited

# 4. 确认设置
ulimit -c
# 输出: unlimited

# 5. 编译并运行程序
gcc -g -o bubble bubble.c
./bubble

# 6. 查看生成的core文件
ls -la core-*
# 输出: core-p12345-t1623456789-bubble

# 7. 用GDB分析
gdb ./bubble core-<pid>
(gdb) bt
```

### 1.6 预防措施

#### 1.6.1 编译时选项
```
# 添加调试信息
gcc -g -o program program.c

# 添加堆栈保护
gcc -fstack-protector-all -o program program.c

# 启用所有警告
gcc -Wall -Wextra -o program program.c
```

#### 1.6.2 运行时检查

使用valgrind检查内存问题：
```
valgrind --tool=memcheck ./program
```

使用AddressSanitizer：
```
gcc -fsanitize=address -g -o program program.c
```

## 第二章 用GDB分析coredump文件

### 2.1 加载coredump文件
```
gdb <程序路径> <coredump文件路径>
```
示例：
```
gdb /usr/bin/myapp /tmp/core-myapp-12345-1623456789
```

### 2.2 查看崩溃位置与调用栈
```
(gdb) bt          # 显示调用栈（backtrace简写）
(gdb) where       # 同bt
(gdb) bt full     # 显示调用栈和局部变量
```

### 2.3 查看寄存器状态
```
(gdb) info registers    # 显示所有寄存器
(gdb) info registers    # 简写: i r
```

重点关注`rip`（x86-64的指令指针寄存器），它指向崩溃时的执行地址。

### 2.4 查看内存映射
```
(gdb) info proc mappings
```

输出示例：
```
0x555555554000     0x555555555000     0x1000        0x0 /home/musk/work/deliberate/algorithm/insertion
0x555555555000     0x555555556000     0x1000     0x1000 /home/musk/work/deliberate/algorithm/insertion
0x555555556000     0x555555557000     0x1000     0x2000 /home/musk/work/deliberate/algorithm/insertion
...
0x7ffff7dc9000     0x7ffff7deb000    0x22000        0x0 /usr/lib/x86_64-linux-gnu/libc-2.31.so
0x7ffff7fcf000     0x7ffff7fd0000     0x1000        0x0 /usr/lib/x86_64-linux-gnu/ld-2.31.so
```

**正常地址模式：**

- 程序代码段：`0x55555555xxxx`
- 库代码段：`0x7ffff7xxxxxx` 或 `0x7ffffxxxxxxx`
- 栈：`0x7ffffffxxxxx`

### 2.5 查看变量
```
(gdb) print variable_name      # 打印变量值
(gdb) p variable_name          # print的简写
(gdb) print *pointer           # 打印指针指向的值
(gdb) print array[5]           # 打印数组元素
(gdb) print $rax               # 打印寄存器值
```

查看当前栈帧的所有局部变量：
```
(gdb) info locals
```

查看当前函数的参数：
```
(gdb) info args
```

### 2.6 查看内存

```
x`命令格式：`x/<重复次数><格式><大小> <地址>
```

**格式说明：**

| 格式 | 含义     |
| :--- | :------- |
| x    | 十六进制 |
| d    | 十进制   |
| t    | 二进制   |
| c    | 字符     |
| s    | 字符串   |
| i    | 汇编指令 |

**大小说明：**

| 大小 | 含义           |
| :--- | :------------- |
| b    | 字节 (1 byte)  |
| h    | 半字 (2 bytes) |
| w    | 字 (4 bytes)   |
| g    | 巨字 (8 bytes) |

**常用示例：**
```
(gdb) x/10wx &variable          # 以十六进制查看10个字
(gdb) x/20cb buffer             # 查看20个字节（字符形式）
(gdb) x/s str                   # 查看字符串
(gdb) x/g $rsp                  # 查看栈指针指向的内容
(gdb) x/10i $pc                 # 查看当前指令附近10条指令
(gdb) x/20xg $rsp               # 查看栈内容（20个巨字）
(gdb) x/10wx 0x7fffffffe110     # 查看指定地址的10个字
```

### 2.7 栈帧操作
```
(gdb) backtrace           # 显示调用栈，简写: bt
(gdb) backtrace full      # 显示调用栈和局部变量
(gdb) frame <编号>        # 切换到指定栈帧，简写: f
(gdb) up                  # 向上移动栈帧（调用者方向）
(gdb) down                # 向下移动栈帧（被调用者方向）
(gdb) info frame          # 显示当前帧信息，简写: i f
(gdb) info locals         # 查看当前栈帧的局部变量，简写: i lo
(gdb) info args           # 查看当前函数的参数，简写: i ar
```

### 2.8 线程信息
```
(gdb) info threads            # 显示所有线程，简写: i th
(gdb) thread <线程ID>         # 切换到指定线程
(gdb) thread apply all bt     # 查看所有线程堆栈
```

### 2.9 反汇编
```
(gdb) disassemble         # 反汇编当前函数
(gdb) disas main          # 反汇编指定函数
```

### 2.10 信号信息
```
(gdb) info signals        # 显示信号信息，简写: i sig
```

### 2.11 自动化脚本示例

创建调试脚本 `debug_core.sh`：
```
#!/bin/
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

使用方法：
```
chmod +x debug_core.sh
./debug_core.sh ./bubble core-12345
```

## 第三章 GDB排查思路与实战

> **核心思路**：从宏观症状定位到微观代码错误，通过观察内存状态和程序行为来缩小问题范围。

### 3.1 排查步骤（完整案例演示）

以 `insertion.c` 程序为例，完整演示从崩溃到定位根因的每一步。

**编译准备（带AddressSanitizer）：**
```
gcc -g -fsanitize=address -fno-omit-frame-pointer -o insertion insertion.c
```



#### 第1步：确认问题现象
```
(gdb) r
Program received signal SIGSEGV, Segmentation fault
```

**观察：** 程序崩溃，段错误
**推断：** 内存访问违规（访问了不该访问的内存）

**检查清单：**

- 映射检查：地址是否在 `info proc mappings` 列出的段内
- 模式检查：地址是否符合系统内存布局模式
- 符号检查：GDB是否能解析出函数名
- 数值检查：地址是否包含可疑的数据模式
- 一致性检查：与其他寄存器/栈值是否协调

#### 第2步：检查崩溃位置
```
(gdb) bt
#0  0x00000003555550db in ?? ()
(gdb) info registers
rip            0x3555550db         0x3555550db
```

**观察：** 调用栈异常，rip指向奇怪地址 `0x3555550db`
**推断：** 返回地址被破坏，说明栈内存被意外修改

#### 第3步：分析内存映射
```
(gdb) info proc mappings
0x555555554000     0x555555555000     0x1000        0x0 /home/musk/work/deliberate/algorithm/insertion
```

**观察：** 正常代码段在 `0x55555555xxxx` 范围，但rip指向 `0x3555550db`

```
正常程序地址:   0x55555555558a  (在映射范围内)
异常的 rip:     0x00000003555550db (不在任何映射范围内)
                ^^^^^^^^^^
                异常的高位部分
```

**推断：** 控制流被破坏，很可能是栈溢出或缓冲区溢出

#### 第4步：检查栈和局部变量状态
```
(gdb) info locals
arr = {10277, -402295808, -1772, -2125934455, 41156}
n = 32767
```

**关键发现：局部变量值被破坏**

- `arr` 不是原始的 `{98, 11, 45, 3, 65}`
- `n` 不是预期的 `5`，而是 `32767`

**推断：** 栈内存被意外写入，破坏了局部变量

#### 第5步：定位崩溃代码位置
```
(gdb) info frame
rip = 0x55555555558a in main (insertion.c:30)
(gdb) list
30      {
```

**观察：** 崩溃在main函数开始处（第30行）
**推断：** 问题发生在函数调用过程中，不是在当前行

#### 第6步：使用内存检测工具精确定位
```
gcc -g -fsanitize=address -o insertion insertion.c
(gdb) r
```

**策略：** 使用AddressSanitizer自动检测内存错误
**结果：** 精确定位到 `insertion.c:19` 的栈缓冲区下溢（访问了 `arr[-1]`）

### 3.2 各参数作用说明

| 参数                      | 作用                                       |
| :------------------------ | :----------------------------------------- |
| `-g`                      | 包含调试信息，使错误报告更清晰             |
| `-fsanitize=address`      | 启用AddressSanitizer插桩，自动检测内存错误 |
| `-fno-omit-frame-pointer` | 保留帧指针，便于调试和栈回溯               |

### 3.3 问题推理链条
```
段错误
    ↓
内存访问违规
    ↓
异常rip地址 → 控制流/返回地址被破坏
    ↓
局部变量值异常 → 栈内存被意外修改
    ↓
崩溃在main开始 → 问题发生在之前的函数调用
    ↓
AddressSanitizer报告 → 精确定位到数组越界访问
```

### 3.4 关键排查技巧

#### a. 观察内存状态模式

| 现象               | 推断         |
| :----------------- | :----------- |
| 局部变量被破坏     | 栈损坏       |
| 返回地址异常       | 控制流被劫持 |
| 这两种现象同时出现 | 缓冲区溢出   |

#### b. 使用工具辅助

- GDB基础命令：`bt`、`info`、`x` 用于初步定位
- 内存检测工具：AddressSanitizer、Valgrind 用于精确定位
- 观察点：`watch` 监控关键变量变化

#### c. 结合算法知识

- 知道是"insertion"程序 → 推测是插入排序
- 插入排序常见错误 → 循环边界问题、索引越界
- 栈缓冲区下溢 → 访问了 `arr[-1]`

### 3.5 经验总结

1. **从现象推导原因**：异常现象背后有确定的内存访问错误
2. **层层深入**：从崩溃现象 → 内存状态 → 代码位置 → 具体错误
3. **工具组合使用**：GDB初步定位 + 专业工具精确定位
4. **结合领域知识**：算法特性帮助预测错误类型

这种系统化的排查方法可以应用于各种内存相关问题的调试，关键是建立从现象到原因的推理链条，并善用工具验证每个推断。

### 3.6 Valgrind补充说明
```
# 内存检查（追踪未初始化值的来源）
valgrind --tool=memcheck --track-origins=yes ./insertion

# 内存泄漏检查（完整报告）
valgrind --leak-check=full ./insertion
```

## 第四章 GDB主动调试

> **说明**：本章讲解如何主动调试一个程序。设置断点、单步执行、观察变量变化、跟踪执行流程。
>
> 第二章已完整讲解了`bt`、`print`、`info locals`、`x`、`info registers`、`info proc mappings`等命令的用法，本章将完整讲解断点相关命令（break、watch等）及其他主动调试专用命令，同时列出所有查看类命令供快速查阅，具体用法详见第二章对应节。

### 4.1 编译准备

#### 4.1.1 调试编译选项

编译时必须添加 `-g` 选项保留调试信息：
```
gcc -g -o program program.c
```


或在Makefile中确保包含 `-g`：
makefile
```
CFLAGS = -g -Wall
```



#### 4.1.2 检查调试信息
```
file program
# 输出应该包含: "with debug_info"
```

或使用readelf：
```
readelf -S program | grep debug
```



### 4.2 启动GDB
```
# 调试可执行文件
gdb ./program

# 调试运行中的进程
gdb -p <进程ID>

# 调试 core dump 文件（详见第二章）
gdb ./program core
```



### 4.3 程序执行控制
```
(gdb) run [参数]          # 运行程序，简写: r
(gdb) start               # 开始执行并停在main函数
(gdb) continue            # 继续运行，简写: c
(gdb) next                # 执行下一行（不进入函数），简写: n
(gdb) step                # 执行下一行（进入函数），简写: s
(gdb) finish              # 运行到当前函数返回，简写: fin
(gdb) until <行号>        # 运行到指定行
(gdb) quit                # 退出GDB，简写: q
```

### 4.4 断点管理

#### 4.4.1 设置断点
```
(gdb) break main              # 在main函数设置断点，简写: b
(gdb) break 15                # 在第15行设置断点
(gdb) break file.c:20         # 在指定文件的第20行设置断点
(gdb) break function          # 在指定函数设置断点
(gdb) break *0x400512         # 在内存地址设置断点
(gdb) tbreak main             # 设置临时断点（触发后自动删除），简写: tb
```

#### 4.4.2 条件断点
```
(gdb) break func if i>5      # i>5时断点触发
(gdb) break file.c:20 if i == 5
(gdb) condition 2 i > 10     # 为断点2设置条件
(gdb) ignore 2 5             # 忽略断点2的前5次触发
```

#### 4.4.3 断点管理
```
(gdb) info breakpoints       # 查看所有断点，简写: i b
(gdb) delete <断点编号>       # 删除断点，简写: d
(gdb) disable <断点编号>      # 禁用断点，简写: dis
(gdb) enable <断点编号>       # 启用断点，简写: en
(gdb) clear                  # 清除当前行断点
(gdb) clear function         # 清除指定函数的断点
```

#### 4.4.4 断点命令列表
```
(gdb) commands 2             # 为断点2设置命令列表
> p i
> p arr[i]
> c
> end
```

#### 4.4.5 保存与加载断点配置
```
(gdb) save breakpoints breakpoints.txt
(gdb) source breakpoints.txt
```

### 4.5 观察点/监视点
```
(gdb) watch variable            # 变量改变时暂停
(gdb) watch *(int*)0x1234       # 监视内存地址
(gdb) rwatch variable           # 变量被读取时暂停
(gdb) awatch variable           # 变量被读或写时暂停
```

### 4.6 查看代码
```
(gdb) list                 # 显示当前行附近的代码，简写: l
(gdb) list function        # 显示指定函数的代码
(gdb) list file.c:15       # 显示指定文件的指定行
(gdb) list 10,20           # 显示10-20行的代码
```

### 4.7 查看变量（命令汇总）

| 命令               | 用途               | 详细用法见  |
| :----------------- | :----------------- | :---------- |
| `print variable`   | 打印变量值         | 第二章2.5节 |
| `print *pointer`   | 打印指针指向的值   | 第二章2.5节 |
| `print array[5]`   | 打印数组元素       | 第二章2.5节 |
| `print $rax`       | 打印寄存器值       | 第二章2.5节 |
| `display variable` | 每次停止时自动显示 | 第二章2.5节 |
| `info display`     | 查看自动显示列表   | 第二章2.5节 |
| `undisplay <编号>` | 取消自动显示       | 第二章2.5节 |
| `whatis variable`  | 查看变量类型       | 第二章2.5节 |
| `ptype variable`   | 查看详细类型信息   | 第二章2.5节 |

### 4.8 显示格式控制
```
(gdb) p/x variable          # 十六进制显示
(gdb) p/d variable          # 十进制显示
(gdb) p/t variable          # 二进制显示
(gdb) p/c variable          # 字符显示
(gdb) p/a variable          # 地址显示
```

### 4.9 查看内存（命令汇总）

| 命令               | 用途                     | 详细用法见  |
| :----------------- | :----------------------- | :---------- |
| `x/10wx &variable` | 十六进制查看10个字       | 第二章2.6节 |
| `x/20cb buffer`    | 查看20个字节（字符形式） | 第二章2.6节 |
| `x/s ptr`          | 查看字符串               | 第二章2.6节 |
| `x/i $pc`          | 查看当前指令             | 第二章2.6节 |

### 4.10 栈和函数调用（命令汇总）

| 命令                   | 用途           | 详细用法见         |
| :--------------------- | :------------- | :----------------- |
| `backtrace` / `bt`     | 显示调用栈     | 第二章2.2节、2.7节 |
| `frame <编号>` / `f`   | 选择栈帧       | 第二章2.7节        |
| `up`                   | 向上移动栈帧   | 第二章2.7节        |
| `down`                 | 向下移动栈帧   | 第二章2.7节        |
| `info frame` / `i f`   | 显示当前帧信息 | 第二章2.7节        |
| `info locals` / `i lo` | 显示局部变量   | 第二章2.5节        |
| `info args` / `i ar`   | 显示函数参数   | 第二章2.5节        |

### 4.11 多线程调试
```
(gdb) info threads              # 查看所有线程，简写: i th
(gdb) thread <线程ID>           # 切换到指定线程，简写: t
(gdb) thread apply all bt       # 对所有线程执行bt命令
(gdb) thread apply all command  # 对所有线程执行指定命令
```

### 4.12 信号处理
```
(gdb) handle SIGSEGV stop    # 当收到SIGSEGV时停止
(gdb) info signals           # 查看信号处理设置，简写: i sig
```

### 4.13 远程调试

**目标机器：**
```
gdbserver :1234 ./program
```

**开发机器：**
```
(gdb) target remote 目标IP:1234
(gdb) continue
```



### 4.14 图形界面模式（TUI）

```
gdb -tui ./program       # 启动文本用户界面
```



在GDB中切换TUI：
```
(gdb) tui enable         # 启用TUI
(gdb) layout src         # 显示源代码布局
(gdb) layout asm         # 显示汇编布局
(gdb) layout regs        # 显示寄存器布局
```



### 4.15 其他实用功能

```
(gdb) shell              # 执行shell命令，简写: sh
(gdb) set logging on     # 开启日志
(gdb) set logging off    # 关闭日志
(gdb) set logging file gdb.log  # 设置日志文件
(gdb) define mycmd       # 定义用户命令
> print variable1
> print variable2
> backtrace
> end
(gdb) mycmd              # 执行自定义命令
(gdb) source file        # 执行命令文件，简写: so
(gdb) show commands      # 显示历史命令
(gdb) record             # 开始执行记录
(gdb) reverse-step       # 反向单步执行
(gdb) skip -gfi /usr/include/*.h  # 跳过标准库头文件
(gdb) skip -gfi /usr/lib/*.so     # 跳过标准库
```

### 4.16 实际调试示例（bubble.c）

#### 示例程序代码
```
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
    }
    for (int i = 0; i < ARRAY_COUNT(arr); i++)
    {
        printf("arr[%d] = %d\n", i, arr[i]);
    }
    return 0;
}
```

#### 完整调试会话

**编译：**

```
gcc -g -o bubble bubble.c
```

**启动GDB：**

```
gdb ./bubble
```

**调试操作：**

```
# 设置断点在可能出问题的地方
(gdb) break bubble.c:15

# 运行程序
(gdb) run

# 监视变量变化
(gdb) display j
(gdb) display i
(gdb) display n

# 单步调试
(gdb) next
(gdb) step

# 检查 arr[j] 和 arr[j+1] 是否在有效范围内
(gdb) print j
(gdb) print j+1
(gdb) print n  # 数组长度

# 查看这些位置的值
(gdb) print arr[j]
(gdb) print arr[j+1]

# 继续执行
(gdb) continue

# 退出
(gdb) quit
```

## 附录A：GDB命令速查表

| 类别           | 全命令           | 缩写    | 功能说明               |
| :------------- | :--------------- | :------ | :--------------------- |
| **基本调试**   | run              | r       | 运行程序               |
|                | quit             | q       | 退出GDB                |
|                | help             | h       | 查看帮助               |
|                | list             | l       | 显示源代码             |
|                | print            | p       | 打印表达式值           |
|                | next             | n       | 单步执行（不进入函数） |
|                | step             | s       | 单步执行（进入函数）   |
|                | continue         | c       | 继续执行               |
|                | finish           | fin     | 执行到当前函数返回     |
| **断点管理**   | break            | b       | 设置断点               |
|                | delete           | d       | 删除断点               |
|                | disable          | dis     | 禁用断点               |
|                | enable           | en      | 启用断点               |
|                | info breakpoints | i b     | 显示所有断点           |
|                | clear            | cl      | 清除断点               |
|                | tbreak           | tb      | 设置临时断点           |
|                | condition        | cond    | 设置断点条件           |
|                | commands         | com     | 设置断点触发命令       |
| **栈和帧**     | backtrace        | bt      | 显示调用栈             |
|                | frame            | f       | 选择栈帧               |
|                | up               |         | 向上移动栈帧           |
|                | down             |         | 向下移动栈帧           |
|                | info frame       | i f     | 显示当前帧信息         |
|                | info locals      | i lo    | 显示局部变量           |
|                | info args        | i ar    | 显示函数参数           |
| **变量和内存** | display          | disp    | 每次停止时显示表达式   |
|                | undisplay        | undisp  | 取消显示               |
|                | watch            | wa      | 设置监视点             |
|                | rwatch           | rwa     | 设置读监视点           |
|                | awatch           | awa     | 设置读写监视点         |
|                | x                |         | 检查内存               |
|                | set variable     | set var | 设置变量值             |
|                | whatis           | wh      | 显示变量类型           |
|                | ptype            | pt      | 显示详细类型信息       |
| **高级调试**   | thread           | t       | 线程操作               |
|                | info threads     | i th    | 显示所有线程           |
|                | catch            | cat     | 设置捕获点             |
|                | signal           | sig     | 发送信号               |
|                | return           | ret     | 强制函数返回           |
|                | jump             | j       | 跳转到指定位置         |
|                | attach           | att     | 附加到运行进程         |
|                | detach           | det     | 分离进程               |
|                | handle           | han     | 设置信号处理           |
| **信息查询**   | info registers   | i r     | 显示寄存器             |
|                | info program     | i prog  | 显示程序状态           |
|                | info signals     | i sig   | 显示信号信息           |
|                | info functions   | i fun   | 显示函数信息           |
|                | info variables   | i var   | 显示变量信息           |
| **其他实用**   | shell            | sh      | 执行shell命令          |
|                | define           | def     | 定义用户命令           |
|                | source           | so      | 执行命令文件           |
|                | show commands    | sh com  | 显示历史命令           |
|                | record           | rec     | 开始执行记录           |
|                | reverse-step     | rs      | 反向单步执行           |

## 附录B：常用命令示例汇总

### 快速调试流程

```
gdb ./insertion
(gdb) run 
(gdb) bt              # 当出现segmentation fault时
(gdb) b main          # 在main函数设断点
(gdb) r               # 运行程序
(gdb) n               # 单步执行
(gdb) p variable      # 查看变量
(gdb) bt              # 查看调用栈
(gdb) c               # 继续执行
```

### 完整调试流程

```
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

### 内存检查示例

```
(gdb) x/10wx addr         # 查看10个字(16进制)
(gdb) x/20cb buf          # 查看20个字节(字符)
(gdb) x/s str             # 查看字符串
(gdb) x/10wx 0x7fffffffe110  # 查看10个word（16进制）
(gdb) x/20cb buffer       # 查看20个字节（字符形式）
(gdb) x/s ptr             # 查看字符串
(gdb) x/i $pc             # 查看当前指令
```

### 条件断点示例

```
(gdb) b func if i>5       # i>5时断点触发
(gdb) commands 2          # 为断点2设置命令
> p i
> c
> end
```

## 附录C：断点设置方式汇总

```
(gdb) b main              # 在main函数设置断点
(gdb) b 15                # 在第15行设置断点
(gdb) b file.c:20         # 在指定文件的第20行设置断点
(gdb) b *0x400512         # 在内存地址设置断点
(gdb) b func if i == 5    # 条件断点
```



## 附录D：条件调试与监视点汇总



```
# 条件调试
(gdb) commands 2           # 为断点2设置命令列表
> p i
> p arr[i]
> c
> end

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

# 开启日志
(gdb) set logging on
(gdb) set logging file gdb.log
(gdb) set logging off

# 远程调试
(gdb) target remote :1234  # 连接到远程gdbserver

# 跳过库函数
(gdb) n                    # 执行下一行，但不进入函数
(gdb) s                    # 进入函数内部（会进入printf）
(gdb) finish               # 执行完当前函数，返回到调用处
(gdb) skip -gfi /usr/include/*.h
(gdb) skip -gfi /usr/lib/*.so
```