
**中文** | [English](../en/language/Cpp-Smart-Pointer-Ownership-Semantics.md)

# 智能指针：三种所有权语义，以及裸指针永远不会告诉你的那些事

> 从裸指针的三类问题出发，讲清楚 `unique_ptr` / `shared_ptr` / `weak_ptr` 分别代表什么所有权语义，每个示例自包含、可编译、可观察析构输出。
>
> 标准出处：三者均定义于 `<memory>`，自 C++11 起提供；`make_unique` 自 C++14 起。参考：https://en.cppreference.com/w/cpp/memory。

------

## 0. 一句话先讲清楚

智能指针不是“更聪明的裸指针”，而是**三种所有权语义的载体**：

| 类型         | 所有权           | 一句话                                                       |
| :----------- | :--------------- | :----------------------------------------------------------- |
| `unique_ptr` | 独占             | 同一时间只有一个持有者，不可拷贝、只能移动，离开作用域自动释放 |
| `shared_ptr` | 共享             | 引用计数，计数归零才析构；拷贝 +1，销毁 −1                   |
| `weak_ptr`   | 无所有权，仅观察 | 不参与强计数，必须 `lock()` 升级成 `shared_ptr` 才能访问；核心用途是打破 `shared_ptr` 循环引用 |

裸指针只存地址、不记录所有权，释放全靠自觉。智能指针把“谁拥有这块内存、什么时候释放”编码进了**类型**里。这是本文其余所有细节的出发点。

**追问 Q0：智能指针和裸指针的本质区别是什么？**

裸指针是一个地址值，拷贝它就是复制一个地址，两个指针之间没有任何语义关联；智能指针是一个**栈上的对象**，通过类型系统规定“能否拷贝、拷贝意味着什么、析构时做什么”。`unique_ptr` 删除拷贝构造使误用变成编译错误，`shared_ptr` 在控制块里维护引用计数，`weak_ptr` 用类型系统禁止“不经检查直接访问”。所有权语义的差异，全部体现在这三个类的特殊成员函数和类型定义上。

## 1. 裸指针的三类问题（ASan 实测）

### 1.1 泄漏与提前 return

下面这个程序刻意把两个 `new` 放在第 15 行和第 22 行，使 LeakSanitizer 报告里的行号与源码对齐。编译方式：

```bash
g++ -std=c++17 -fsanitize=address -g 01a_leak.cpp -o 01a_leak
```

```cpp
// 01a_leak.cpp
#include <cstdio>

struct Widget {
    int id;
    explicit Widget(int i) : id(i) { std::printf("Widget(%d) 构造\n", id); }
    ~Widget() { std::printf("Widget(%d) 析构\n", id); }
};

void leak_example() {
    Widget* p = new Widget(1);          // 第 15 行：分配后从未 delete
    std::printf("leak_example 使用 p->id = %d\n", p->id);
}                                       // 栈上 p 消失，堆内存无人持有

void early_return_example(bool flag) {
    Widget* p = new Widget(2);          // 第 22 行：delete 写在函数尾部
    if (flag) {
        std::printf("提前 return，跳过 delete\n");
        return;                         // 第 25 行：delete 永远执行不到
    }
    delete p;
}

int main() {
    leak_example();
    early_return_example(true);
    return 0;
}
```

运行输出（地址、PID、路径因环境而异，行号是关键）：

```text
Widget(1) 构造
leak_example 使用 p->id = 1
Widget(2) 构造
提前 return，跳过 delete

=================================================================
==41327==ERROR: LeakSanitizer: detected memory leaks

Direct leak of 4 byte(s) in 1 object(s) allocated from:
    #0 0x7f... in operator new(unsigned long)
    #1 0x55... in leak_example() /tmp/01a_leak.cpp:15
    #2 0x55... in main /tmp/01a_leak.cpp:29

Direct leak of 4 byte(s) in 1 object(s) allocated from:
    #0 0x7f... in operator new(unsigned long)
    #1 0x55... in early_return_example(bool) /tmp/01a_leak.cpp:22
    #2 0x55... in main /tmp/01a_leak.cpp:30

SUMMARY: AddressSanitizer: 8 byte(s) leaked in 2 allocation(s).
=================================================================
```

注意析构打印**一次都没有出现**。两个 `Widget` 都没有被释放，泄漏的字节数、分配栈和行号完全对应。

### 1.2 Double free

Double free 会直接 abort，和 LeakSanitizer 的汇总混在一起会互相掩盖，所以单独成程序：

```cpp
// 01b_double_free.cpp  编译：g++ -std=c++17 -fsanitize=address -g 01b_double_free.cpp
#include <cstdio>

struct Widget {
    ~Widget() { std::printf("Widget 析构\n"); }
};

int main() {
    Widget* raw = new Widget();
    Widget* a = raw;                    // 两个裸指针都“以为”自己拥有这块内存
    Widget* b = raw;
    delete a;                           // 第一次释放
    delete b;                           // 第二次释放同一地址 → double free
    return 0;
}
```

```text
Widget 析构
=================================================================
==41331==ERROR: AddressSanitizer: attempting double-free on 0x602000000010 in thread T0:
    #0 0x7f... in operator delete(void*)
    #1 0x55... in main /tmp/01b_double_free.cpp:13
    #2 0x7f... in __libc_start_main
    #3 0x55... in _start

0x602000000010 is located 0 bytes inside of 4-byte region [0x602000000010,0x602000000014)
allocated by thread T0 here:
    #0 0x7f... in operator new(unsigned long)
    #1 0x55... in main /tmp/01b_double_free.cpp:9
    #2 0x7f... in __libc_start_main
=================================================================
```

`Widget 析构` 只打印一次，随后进程被 ASan 终止。第二次 `delete` 没有机会执行析构，说明“析构次数”并不等于“delete 次数”；当所有权不清时，析构语义已经失效。

**三类问题的共同根源**：裸指针不记录所有权。泄漏是“忘了释放”，提前 return 是“释放路径被跳过”，double free 是“两个指针都以为自己拥有”。智能指针要解决的，正是把“拥有”这件事从程序员的记忆里搬到类型系统里。

## 2. RAII：把资源交给栈对象

RAII（Resource Acquisition Is Initialization）的一句话核心：**在构造函数里获取资源，在析构函数里释放资源；对象生命周期绑定资源生命周期。**

栈对象离开作用域时析构函数**必然**被调用——即使中途 `return`、即使抛出异常。智能指针就是这个规则在堆内存上的落地：你 `new` 出来的对象被它包在内部，智能指针自己活在栈上，它一死，指向的堆对象就被释放。

下面是一个最小的 RAII 载体，不是智能指针，但展示了同一套机制：

```cpp
// 02_raii.cpp  编译：g++ -std=c++17 02_raii.cpp
#include <cstdio>

class IntHolder {
    int* p_;
public:
    explicit IntHolder(int v) : p_(new int(v)) {
        std::printf("IntHolder 构造，持有 %d\n", *p_);
    }
    ~IntHolder() {
        std::printf("IntHolder 析构，释放 %d\n", *p_);
        delete p_;
    }
    IntHolder(const IntHolder&) = delete;
    IntHolder& operator=(const IntHolder&) = delete;
};

void scope_example() {
    IntHolder h(42);
    std::printf("scope_example 使用中\n");
}   // h 析构，释放 p_ 指向的堆内存

int main() {
    scope_example();
    std::printf("回到 main\n");
    return 0;
}
```

```text
IntHolder 构造，持有 42
scope_example 使用中
IntHolder 析构，释放 42
回到 main
```

析构打印出现在 `scope_example` 结束时、`回到 main` 之前——这就是“对象离开作用域，资源自动归还”的可观察证据。`unique_ptr` 的内部结构本质上就是这个 `IntHolder`，只不过它把“持有指针”做成了模板，把“释放”做成了可定制的删除器。

## 3. `unique_ptr`：独占所有权

### 3.1 基本语义与移动

`unique_ptr` 的拷贝构造和拷贝赋值被 `= delete`，只能移动。移动后源指针置空（实践中 `get()` 返回 `nullptr`，标准描述为“有效但未指定”）。

```cpp
// 03_unique_move.cpp  编译：g++ -std=c++17 03_unique_move.cpp
#include <cstdio>
#include <memory>
#include <utility>

struct Widget {
    int id;
    explicit Widget(int i) : id(i) { std::printf("Widget(%d) 构造\n", id); }
    ~Widget() { std::printf("Widget(%d) 析构\n", id); }
};

int main() {
    auto p = std::make_unique<Widget>(1);
    std::printf("p.get() = %p, bool(p) = %d\n", (void*)p.get(), (bool)p);

    auto q = std::move(p);                    // 转移所有权
    std::printf("after move: p.get() = %p, bool(p) = %d\n",
                (void*)p.get(), (bool)p);
    std::printf("after move: q.get() = %p, bool(q) = %d\n",
                (void*)q.get(), (bool)q);
}   // q 析构 → Widget(1) 析构
```

```text
Widget(1) 构造
p.get() = 0x...  , bool(p) = 1
after move: p.get() = (nil), bool(p) = 0
after move: q.get() = 0x...  , bool(q) = 1
Widget(1) 析构
```

移动后 `p` 为空，`q` 接管唯一所有权，最终只析构一次。**默认首选 `unique_ptr`**：除非明确需要共享，否则一律先用它。

**追问 Q1：`unique_ptr` 为什么不能拷贝？移动后原指针是什么状态？**

拷贝会制造两个都自认为“独占”的持有者，两者析构时对同一地址各 `delete` 一次，直接 double free。删除拷贝构造把误用从运行时崩溃提前到编译错误，这是把所有权语义编码进类型系统的典型手法。移动构造/赋值把内部指针转移给目标、把源置空；标准规定移动后的 `unique_ptr` 处于“有效但未指定”状态，实践中 `get()` 返回 `nullptr`，可以安全析构、重新赋值或再次移动，但解引用是未定义行为。`release()` 是另一条路径：交出裸指针并把自身置空，由调用方接管释放责任。

### 3.2 进阶：删除器与 `sizeof`

`unique_ptr<T, Deleter>` 的大小取决于删除器类型。**默认删除器 `std::default_delete<T>` 和无捕获 lambda / 空仿函数是空类，通过空基类优化（EBO）不占额外空间，此时 `sizeof(unique_ptr<T>) == sizeof(T\*)\**`。但如果删除器是**函数指针**或**带状态的函数对象**，`unique_ptr` 会变大。

| 删除器类型                     | `sizeof(unique_ptr)`（64 位）               | 原因                 |
| :----------------------------- | :------------------------------------------ | :------------------- |
| `default_delete<T>`            | `sizeof(T*)` = 8                            | EBO，空类占 0 字节   |
| 无捕获 lambda / 空仿函数       | 8                                           | EBO 同样适用         |
| 函数指针 `void(*)(T*)`         | 16                                          | 必须额外存一个指针值 |
| 带捕获的 lambda / 有状态仿函数 | `sizeof(T*) + sizeof(状态)`，按对齐向上取整 | 必须存捕获的状态     |
| `std::function<void(T*)>`      | 约 40+ 字节                                 | 类型擦除开销大       |

下面用 `sizeof` 直接观察：

```cpp
// 04_unique_sizeof.cpp  编译：g++ -std=c++17 04_unique_sizeof.cpp
#include <cstdio>
#include <functional>
#include <memory>

struct Widget { int x; double y; };

struct EmptyDeleter {
    void operator()(Widget* p) const { delete p; }
};

struct CountingDeleter {
    int count = 0;
    void operator()(Widget* p) { ++count; delete p; }
};

void free_deleter(Widget* p) { delete p; }

int main() {
    using default_up  = std::unique_ptr<Widget>;
    using empty_up    = std::unique_ptr<Widget, EmptyDeleter>;
    using counting_up = std::unique_ptr<Widget, CountingDeleter>;
    using funcptr_up  = std::unique_ptr<Widget, void(*)(Widget*)>;
    using stdfunc_up  = std::unique_ptr<Widget, std::function<void(Widget*)>>;

    std::printf("sizeof(Widget*)           = %zu\n", sizeof(Widget*));
    std::printf("default_delete            = %zu\n", sizeof(default_up));
    std::printf("empty functor             = %zu\n", sizeof(empty_up));
    std::printf("stateful functor          = %zu\n", sizeof(counting_up));
    std::printf("function pointer          = %zu\n", sizeof(funcptr_up));
    std::printf("std::function             = %zu\n", sizeof(stdfunc_up));
}
```

典型输出（GCC / Clang，64 位 Linux）：

```text
sizeof(Widget*)           = 8
default_delete            = 8
empty functor             = 8
stateful functor          = 12
function pointer          = 16
std::function             = 40
```

结论很清晰：**能用无捕获 lambda 或空仿函数，就不要用函数指针**；函数指针会让每个 `unique_ptr` 多 8 字节，放进数组或结构体时这个开销会乘上去。

### 3.3 进阶：PIMPL 与不完整类型

在头文件中用 `std::unique_ptr<Impl>` 声明成员（PIMPL 惯用法）时，如果 `Impl` 只有前向声明，编译器生成的默认析构函数需要 `Impl` 完整才能实例化 `default_delete`，触发：

```text
error: invalid application of 'sizeof' to incomplete type 'Widget::Impl'
```

修复方式：在头文件**声明**析构函数（只声明，不定义），在 `.cpp` 中 `= default` 定义，此时 `Impl` 已完整：

```cpp
// widget.h
#pragma once
#include <memory>

class Widget {
public:
    Widget();
    ~Widget();                               // 关键：只声明，推迟到 .cpp
    Widget(Widget&&) noexcept;
    Widget& operator=(Widget&&) noexcept;
    Widget(const Widget&) = delete;
    Widget& operator=(const Widget&) = delete;

private:
    struct Impl;
    std::unique_ptr<Impl> pimpl_;
};
```

```cpp
// widget.cpp
#include "widget.h"
#include <cstdio>

struct Widget::Impl {
    int value = 42;
    ~Impl() { std::printf("Impl 析构\n"); }
};

Widget::Widget() : pimpl_(std::make_unique<Impl>()) {}
Widget::~Widget() = default;                 // Impl 已完整，可以在此生成默认析构
Widget::Widget(Widget&&) noexcept = default;
Widget& Widget::operator=(Widget&&) noexcept = default;
```

注意移动构造和移动赋值同理：它们也需要 `Impl` 完整，所以一并推迟到 `.cpp`。`std::unique_ptr` 是唯一能这样用的智能指针——`shared_ptr` 的删除器是类型擦除的，析构时不需要 `T` 完整，但代价是控制块的额外分配；`unique_ptr` 靠“删除器是类型的一部分”换来了零额外分配，代价就是 PIMPL 下必须手动管理析构/移动的定义位置。

## 4. `shared_ptr`：共享所有权与引用计数

### 4.1 控制块与计数

`shared_ptr` 的计数不在对象里，而在堆上的**控制块**中。所有共享同一对象的副本指向同一个控制块，拷贝 +1、销毁 −1，**强计数归零时对象析构**；控制块本身在强计数和弱计数都归零后才释放。


```cpp
// 05_shared_count.cpp  编译：g++ -std=c++17 05_shared_count.cpp
#include <cstdio>
#include <memory>

struct Widget {
    int id;
    explicit Widget(int i) : id(i) { std::printf("Widget(%d) 构造\n", id); }
    ~Widget() { std::printf("Widget(%d) 析构\n", id); }
};

int main() {
    auto a = std::make_shared<Widget>(1);
    std::printf("a.use_count() = %ld\n", a.use_count());
    {
        auto b = a;
        std::printf("b 存在时: use_count = %ld\n", a.use_count());
    }
    std::printf("b 销毁后: use_count = %ld\n", a.use_count());
}   // a 析构，强计数归零 → Widget 析构
```

```text
Widget(1) 构造
a.use_count() = 1
b 存在时: use_count = 2
b 销毁后: use_count = 1
Widget(1) 析构
```

**追问 Q2：`shared_ptr` 的引用计数存在哪里？`make_shared` 为什么少一次分配？代价是什么？**

计数不在 `shared_ptr` 对象里，而在堆上的控制块中，所有副本共享同一控制块。`make_shared` 把对象和控制块放在**同一次堆分配**里，所以比 `shared_ptr<T>(new T)` 少一次 `operator new`，也顺带消除了“先 new 后构造 shared_ptr 期间抛异常”的泄漏窗口。代价是对象内存与控制块同生共死：只要还有 `weak_ptr` 存活，弱计数就不归零，整块分配（**包括对象占用的那部分空间**）都无法归还给分配器。对大对象 + 长寿命 `weak_ptr` 的场景，这反而会延迟内存回收。

注意：`make_shared` 延迟的是**内存释放**，不是**对象析构**。最后一个 `shared_ptr` 销毁时，对象析构函数仍然立即执行；只是那块内存要等最后一个 `weak_ptr` 也消失后才归还操作系统。这两件事必须分开理解。

### 4.2 进阶：`enable_shared_from_this`

成员函数需要把 `this` 安全地转成 `shared_ptr` 时，直接 `shared_ptr<T>(this)` 会创建独立控制块，导致 double free。正确做法是继承 `enable_shared_from_this<T>`：

```cpp
// 06_shared_from_this.cpp  编译：g++ -std=c++17 06_shared_from_this.cpp
#include <cstdio>
#include <memory>

struct Widget : std::enable_shared_from_this<Widget> {
    ~Widget() { std::printf("Widget 析构\n"); }

    std::shared_ptr<Widget> get_self() {
        return shared_from_this();
    }
};

int main() {
    auto sp = std::make_shared<Widget>();
    auto self = sp->get_self();
    std::printf("sp.use_count() = %ld\n", sp.use_count());  // 2

    // 反例：栈上对象调用 shared_from_this()
    Widget stack_widget;
    try {
        stack_widget.get_self();            // 抛 std::bad_weak_ptr
    } catch (const std::bad_weak_ptr& e) {
        std::printf("bad_weak_ptr: %s\n", e.what());
    }
}
```

`shared_from_this()` 的前提是**对象已经被至少一个 `shared_ptr` 持有**，此时基类内部的 `weak_ptr` 才会被初始化。栈上对象没有 `shared_ptr` 持有者，内部 `weak_ptr` 为空，调用直接抛 `bad_weak_ptr`。

### 4.3 进阶：线程安全边界

这是 `shared_ptr` 最容易被误传的一句话：“`shared_ptr` 是线程安全的。”精确说法需要分四层：

**① 多线程读同一个 `shared_ptr` 实例 —— 安全。** 拷贝构造、按值传参、`get()`、解引用只读取实例内的指针字段，不修改共享状态；控制块强计数的读取在主流实现中是原子操作。但 `use_count()` 返回的只是**近似值**，标准不保证精确，多线程下不要用它做“计数是否为 1 就独占修改”之类的逻辑判断，那类判断本身有 TOCTOU 窗口。

**② 多线程写不同 `shared_ptr` 实例（指向同一对象）—— 安全。** 每个线程操作自己的实例，同时对共享控制块做原子计数增减。标准明确：所有成员函数（包括拷贝构造和拷贝赋值）都可以在不同实例上被多个线程并发调用，无需额外同步，即使这些实例共享同一对象。

**③ 多线程读写同一个 `shared_ptr` 实例 —— 不安全。** `shared_ptr` 实例内部至少有两个指针（对象指针 + 控制块指针），`reset`、赋值、移动会**同时修改这两个字段**，标准没有为实例本身提供同步。一个线程读、另一个线程 `reset`，属于数据竞争。解决办法：用 mutex 串行化对该实例的所有访问，或改用 C++20 的 `std::atomic<std::shared_ptr<T>>`（只保证单次 load/store 原子，不保证 `if (p) p->foo()` 这类复合操作的原子性）。

**④ 多线程通过 `shared_ptr` 访问所指向对象 —— 不受保护。** 智能指针只承诺对象存活到最后一个持有者释放，**不承诺对象内部状态的并发安全**。多个线程通过各自的副本调用同一对象的非 const 成员函数，仍然是普通数据竞争，需要对象自己同步。

**追问 Q3：`shared_ptr` 是线程安全的吗？**

分三层回答。不同实例（包括指向同一对象的副本）的并发读、拷贝、析构安全，因为控制块计数是原子操作；同一实例的并发读写不安全，因为实例内的对象指针和控制块指针没有同步；所指向对象的并发访问完全不受保护，智能指针只负责生命周期，不负责数据。所以“`shared_ptr` 线程安全”只在“多线程各自持有副本、通过副本管理生命周期”这个狭窄意义上成立。C++20 的 `atomic<shared_ptr>` 解决的是“同一实例的原子 load/store”，仍然不解决对象内部的数据竞争。

## 5. `weak_ptr`：观察者，以及循环引用

### 5.1 强计数与弱计数

`weak_ptr` 不增加**强计数**（决定对象生死），但增加**弱计数**。控制块的释放条件是 `强计数 == 0 && 弱计数 == 0`：强计数归零时对象析构，弱计数归零时控制块本身释放。

```cpp
// 07_weak_count.cpp  编译：g++ -std=c++17 07_weak_count.cpp
#include <cstdio>
#include <memory>

struct Widget {
    ~Widget() { std::printf("Widget 析构\n"); }
};

int main() {
    std::weak_ptr<Widget> wp;
    {
        auto sp = std::make_shared<Widget>();
        wp = sp;
        std::printf("sp 存活: wp.expired() = %d, wp.use_count() = %ld\n",
                    wp.expired(), wp.use_count());
    }   // sp 销毁，强计数归零 → Widget 析构
    std::printf("sp 销毁后: wp.expired() = %d, wp.use_count() = %ld\n",
                wp.expired(), wp.use_count());

    auto locked = wp.lock();
    std::printf("lock() 返回空: %d\n", locked == nullptr);
}   // wp 销毁，弱计数归零 → 控制块释放
```

```text
sp 存活: wp.expired() = 0, wp.use_count() = 1
Widget 析构
sp 销毁后: wp.expired() = 1, wp.use_count() = 0
lock() 返回空: 1
```

注意：`Widget` 析构后 `wp` 仍然存在且 `expired()` 为 true，控制块直到 `wp` 也销毁才释放。`lock()` 是**原子**的“检查 + 升级”：强计数 > 0 就返回有效 `shared_ptr`，否则返回空。

**追问 Q4：`weak_ptr::lock()` 在对象已销毁时返回什么？`expired()` 和 `use_count() == 0` 等价吗？**

`lock()` 原子地检查强计数：大于 0 就递增并返回有效 `shared_ptr`，等于 0 就返回空 `shared_ptr`，不抛异常。`expired()` 在语义上就是“强计数是否为 0”，单线程下与 `use_count() == 0` 通常一致；但标准不保证 `use_count()` 的精确性，多线程下可能读到过期值。**判断对象是否存活应当用 `expired()` 或 `lock()` 后检查返回值**，不要依赖 `use_count() == 0`——`use_count()` 的文档定位是调试/诊断用途。

### 5.2 循环引用：完整对照

两个节点用 `shared_ptr` 互持时，计数各为 2；离开作用域后各减 1，剩余计数 1，双方都不析构。把其中一边改成 `weak_ptr`，环被打断。

```cpp
// 08_cycle.cpp  编译：g++ -std=c++17 08_cycle.cpp
#include <cstdio>
#include <memory>
#include <string>

struct Node {
    std::string name;
    std::shared_ptr<Node> next;             // 默认：强持有
    explicit Node(std::string n) : name(std::move(n)) {
        std::printf("Node(%s) 构造\n", name.c_str());
    }
    ~Node() { std::printf("Node(%s) 析构\n", name.c_str()); }
};

void leak_cycle() {
    auto a = std::make_shared<Node>("A");
    auto b = std::make_shared<Node>("B");
    a->next = b;
    b->next = a;                            // 环：a 和 b 互相强持有
    std::printf("leak_cycle 退出前: a.use_count = %ld, b.use_count = %ld\n",
                a.use_count(), b.use_count());  // 各为 2
}   // a、b 栈上指针销毁，但计数各剩 1 → 两个 Node 都不析构

// ---------- 正面：一侧改为 weak_ptr ----------

struct Node2 {
    std::string name;
    std::shared_ptr<Node2> next;            // 强持有
    std::weak_ptr<Node2>   prev;            // 弱持有，不参与强计数
    explicit Node2(std::string n) : name(std::move(n)) {
        std::printf("Node2(%s) 构造\n", name.c_str());
    }
    ~Node2() { std::printf("Node2(%s) 析构\n", name.c_str()); }
};

void no_leak() {
    auto a = std::make_shared<Node2>("A");
    auto b = std::make_shared<Node2>("B");
    a->next = b;
    b->prev = a;                            // 弱引用，强计数不增加
    std::printf("no_leak 退出前: a.use_count = %ld, b.use_count = %ld\n",
                a.use_count(), b.use_count());  // a=1, b=2
}   // a、b 销毁，强计数归零 → 两个 Node2 都正常析构

int main() {
    std::printf("=== 反面：shared_ptr 互持 ===\n");
    leak_cycle();
    std::printf("=== 正面：一侧 weak_ptr ===\n");
    no_leak();
    return 0;
}
```

```text
=== 反面：shared_ptr 互持 ===
Node(A) 构造
Node(B) 构造
leak_cycle 退出前: a.use_count = 2, b.use_count = 2
=== 正面：一侧 weak_ptr ===
Node2(A) 构造
Node2(B) 构造
no_leak 退出前: a.use_count = 1, b.use_count = 2
Node2(B) 析构
Node2(A) 析构
```

反面场景中 `leak_cycle` 退出后**没有任何析构打印**——两个 `Node` 的强计数停在了 1，谁都不肯先放手。正面场景中一侧改为 `weak_ptr` 后，环被打断，两个对象都正常析构。

**追问 Q5：同一个裸指针构造两个 `shared_ptr` 会发生什么？**

两个 `shared_ptr` 会各自创建**独立的控制块**，强计数各为 1，彼此不知道对方存在。第一个析构时 `delete` 对象，第二个析构时对同一地址再 `delete` 一次，结果是 double free，和 1.2 节的裸指针场景完全同构。注意区分：从**已有 `shared_ptr` 拷贝**是共享同一控制块，完全安全；问题只出在“从裸指针独立构造”。避免方式：优先 `make_shared`；对象的创建者只构造一次 `shared_ptr`，其余地方传副本或 `weak_ptr`；类需要从 `this` 构造时继承 `enable_shared_from_this`。

## 6. 自定义删除器：智能指针管理的不只是堆内存

智能指针更大的价值在于管理**任何需要配对释放的资源**：`FILE*`、POSIX fd、`HANDLE`、`mmap` 区域等。`unique_ptr` 和 `shared_ptr` 在删除器上的设计差异，本身就是所有权语义的延伸：

|                          | `unique_ptr`                                             | `shared_ptr`                               |
| :----------------------- | :------------------------------------------------------- | :----------------------------------------- |
| 删除器是否是类型的一部分 | **是**，`unique_ptr<T, D>` 和 `unique_ptr<T>` 是不同类型 | **否**，删除器在构造时传入，被擦除进控制块 |
| 删除器是否影响 `sizeof`  | 是（见 3.2）                                             | 否，`shared_ptr` 大小不变                  |
| 空指针时是否调用删除器   | **不调用**（C++11 起保证）                               | **调用**（只要控制块存在）                 |

最后一条差异是很多 bug 的来源：如果删除器有副作用（关闭 fd、写日志），`unique_ptr` 在指针为空时会跳过删除器，而 `shared_ptr` 会执行。不要依赖“删除器一定被调用”来写关键逻辑。

下面用 `FILE*` 对照两种写法：

```cpp
// 09_file_deleter.cpp  编译：g++ -std=c++17 09_file_deleter.cpp
#include <cstdio>
#include <memory>

struct FileCloser {
    void operator()(std::FILE* f) const {
        if (f) {
            std::printf("关闭文件\n");
            std::fclose(f);
        }
    }
};

int main() {
    // unique_ptr：删除器是类型的一部分，空仿函数零开销
    using FilePtr = std::unique_ptr<std::FILE, FileCloser>;
    {
        FilePtr f(std::fopen("/tmp/demo_unique.txt", "w"), FileCloser{});
        if (!f) { std::printf("打开失败\n"); return 1; }
        std::fputs("hello from unique_ptr", f.get());
    }   // f 析构 → FileCloser 调用 → fclose

    // shared_ptr：删除器不是类型的一部分，构造时传入
    {
        std::shared_ptr<std::FILE> g(
            std::fopen("/tmp/demo_shared.txt", "w"),
            [](std::FILE* fp) {
                if (fp) { std::printf("关闭 shared 文件\n"); std::fclose(fp); }
            }
        );
        if (!g) { std::printf("打开失败\n"); return 1; }
        std::fputs("hello from shared_ptr", g.get());
    }   // g 析构，强计数归零 → 删除器调用

    return 0;
}
```

`unique_ptr<FILE, FileCloser>` 在无状态 `FileCloser` 下 `sizeof` 仍然是 8 字节；`shared_ptr<FILE>` 的删除器被类型擦除进控制块，`shared_ptr` 自身大小不变，但控制块需要额外分配。

## 7. 对比速查表

| 维度                   | `unique_ptr`                    | `shared_ptr`                      | `weak_ptr`                |
| :--------------------- | :------------------------------ | :-------------------------------- | :------------------------ |
| 所有权                 | 独占                            | 共享                              | 无（观察）                |
| 强引用计数             | 无                              | 有，原子操作                      | 不参与                    |
| 弱引用计数             | 无                              | 有（控制块存活）                  | 参与（控制块存活）        |
| 可否拷贝               | 否，只能移动                    | 可以                              | 从 `shared_ptr` 构造      |
| 释放时机               | 持有者离开作用域                | 强计数归零                        | 不释放对象                |
| 访问方式               | `->` / `*` 直接用               | `->` / `*` 直接用                 | 必须 `lock()`             |
| 删除器                 | **类型的一部分**，影响 `sizeof` | 不是类型的一部分，不改变 `sizeof` | 不涉及                    |
| 默认 `sizeof`（64 位） | 8（默认删除器，EBO）            | 16（对象指针 + 控制块指针）       | 16                        |
| 空指针时删除器         | **不调用**                      | 调用（控制块存在即调用）          | 不涉及                    |
| 数组支持               | `unique_ptr<T[]>`（C++11）      | `shared_ptr<T[]>`（C++17）        | 不涉及                    |
| 线程安全边界           | 移动不安全（同一实例）          | 见 4.3 四层                       | 控制块计数安全            |
| 典型场景               | 默认拥有单一对象                | 多处共同持有同一对象              | 打破循环引用、缓存/观察者 |

## 8. 常见误区与版本时间线

### 误区

**① 把 `unique_ptr` 当裸指针拷贝。** 编译直接报错，这是故意的设计，不是缺陷。

**② 同一个裸指针喂给多个智能指针。** 两套独立控制块 → double free。一开始就用 `make_unique` / `make_shared`，不要从已有裸指针反复构造。

**③ `weak_ptr` 能单独存在。** 不能。它必须由 `shared_ptr` 构造，不能搭配 `unique_ptr`。

**④ 有了 `shared_ptr` 就滥用。** 共享所有权让对象生命周期变难推断，能独占就别共享。`unique_ptr` 是默认首选。

**⑤ 智能指针管理栈对象。** 智能指针只负责堆上对象的释放；栈对象本来就有自动生命周期，交给智能指针会导致对栈地址调用 `delete`，未定义行为。

**⑥ 以为 `make_shared` 的 `weak_ptr` 会阻止对象析构。** 不会。对象析构由强计数决定，`weak_ptr` 只延迟**整块内存的归还**（见 4.1 末尾）。

### 版本时间线

| 特性                                                | 最低标准  |
| :-------------------------------------------------- | :-------- |
| `auto_ptr`（已废弃，C++17 移除）                    | C++98     |
| `unique_ptr` / `shared_ptr` / `weak_ptr`            | **C++11** |
| `make_unique`                                       | **C++14** |
| `shared_ptr<T[]>`                                   | **C++17** |
| `make_unique_for_overwrite`、`make_shared` 数组重载 | **C++20** |
| `std::atomic<std::shared_ptr<T>>`                   | **C++20** |

`auto_ptr` 的“拷贝即转移所有权”语义是后来 `unique_ptr` 用移动语义重新设计的直接动机：拷贝语义被明确删除，转移必须显式 `std::move`。

## 9. 进一步阅读：源码入口

不手写玩具实现。想深入的读者直接读工业级源码，带着问题去看：

| 实现             | 文件                                              | 建议阅读的符号                                             |
| :--------------- | :------------------------------------------------ | :--------------------------------------------------------- |
| libstdc++（GCC） | `bits/unique_ptr.h`                               | `__uniq_ptr_impl`、`default_delete`、移动构造              |
| libstdc++（GCC） | `bits/shared_ptr_base.h`                          | `_Sp_counted_base::_M_release`、`_M_dispose`、`_M_destroy` |
| libc++（Clang）  | `__memory/unique_ptr.h` / `__memory/shared_ptr.h` | `__uniq_ptr_impl`、`__shared_count`、`__shared_weak_count` |
| MSVC STL         | `<memory>`                                        | `_Ref_count_base`、`_Ref_count`、`_Ref_count_resource`     |

一个具体的阅读切入点：libstdc++ 的 `_Sp_counted_base` 构造函数把 `_M_use_count` 和 `_M_weak_count` 都初始化为 1，`_M_release()` 里先处理强计数归零（调用 `_M_dispose()` 析构对象），再处理弱计数归零（调用 `_M_destroy()` 释放控制块）。看清这两条路径，4.1 和 5.1 的“强计数归零析构对象、弱计数归零释放控制块”就不再是口头结论，而是可以在源码里逐行验证的事实。

------

**参考**

- `<memory>` 头文件总览：https://en.cppreference.com/w/cpp/memory
- RAII：https://en.cppreference.com/w/cpp/language/raii
- `std::weak_ptr`（循环引用）：https://en.cppreference.com/w/cpp/memory/weak_ptr
- `std::shared_ptr` 线程安全说明：https://en.cppreference.com/w/cpp/memory/shared_ptr