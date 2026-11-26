**English** | [中文](../../language/Cpp智能指针所有权语义.md)

# Smart Pointers: Three Ownership Semantics, and What Raw Pointers Never Tell You

> Starting from the three classes of raw-pointer problems, this article explains exactly which ownership semantics `unique_ptr` / `shared_ptr` / `weak_ptr` represent. Every example is self-contained, compilable, and produces observable destructor output.
>
> Standard reference: all three are defined in `<memory>` and available since C++11; `make_unique` since C++14. Reference: https://en.cppreference.com/w/cpp/memory.

------

## 0. The Short Version

Smart pointers are not "smarter raw pointers" — they are **carriers of three ownership semantics**:

| Type         | Ownership                   | In one sentence                                              |
| :----------- | :-------------------------- | :----------------------------------------------------------- |
| `unique_ptr` | Exclusive                   | Only one holder at a time; non-copyable, movable only; released automatically when it leaves scope |
| `shared_ptr` | Shared                      | Reference-counted; destroyed only when the count reaches zero; copy +1, destroy −1 |
| `weak_ptr`   | No ownership, observer only | Does not participate in the strong count; must `lock()` into a `shared_ptr` to access; its core purpose is to break `shared_ptr` cycles |

A raw pointer stores only an address and records no ownership; releasing is entirely on you. Smart pointers encode "who owns this memory and when it is released" into the **type system**. Everything else in this article follows from that.

**Follow-up Q0: What is the essential difference between a smart pointer and a raw pointer?**

A raw pointer is an address value; copying it copies an address, and the two pointers have no semantic relationship whatsoever. A smart pointer is a **stack object** that uses the type system to define "can it be copied, what does copying mean, and what happens on destruction". `unique_ptr` deletes its copy constructor so misuse becomes a compile error; `shared_ptr` maintains a reference count in a control block; `weak_ptr` uses the type system to forbid direct access without a check. The differences in ownership semantics are all expressed in the special member functions and type definitions of these three classes.

## 1. The Three Classes of Raw-Pointer Problems (Measured with ASan)

### 1.1 Leaks and Early Return

The program below deliberately places the two `new` expressions on line 15 and line 22, so the line numbers in the LeakSanitizer report line up with the source. Build:

```bash
g++ -std=c++17 -fsanitize=address -g 01a_leak.cpp -o 01a_leak
```

```cpp
// 01a_leak.cpp
#include <cstdio>

struct Widget {
    int id;
    explicit Widget(int i) : id(i) { std::printf("Widget(%d) constructed\n", id); }
    ~Widget() { std::printf("Widget(%d) destructed\n", id); }
};

void leak_example() {
    Widget* p = new Widget(1);          // line 15: allocated, never deleted
    std::printf("leak_example uses p->id = %d\n", p->id);
}                                       // stack pointer p gone, heap memory unreachable

void early_return_example(bool flag) {
    Widget* p = new Widget(2);          // line 22: delete written at the tail
    if (flag) {
        std::printf("early return, skipping delete\n");
        return;                         // line 25: delete never reached
    }
    delete p;
}

int main() {
    leak_example();
    early_return_example(true);
    return 0;
}
```



Output (addresses, PID, and paths vary by environment; the line numbers are what matter):

```text
Widget(1) constructed
leak_example uses p->id = 1
Widget(2) constructed
early return, skipping delete

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



Notice that the destructor print **never appears**. Neither `Widget` is ever released, and the leaked bytes, allocation stacks, and line numbers all line up.

### 1.2 Double Free

Double free aborts the process immediately; mixing it with LeakSanitizer's summary would mask both. So it gets its own program:

```cpp
// 01b_double_free.cpp  compile: g++ -std=c++17 -fsanitize=address -g 01b_double_free.cpp
#include <cstdio>

struct Widget {
    ~Widget() { std::printf("Widget destructed\n"); }
};

int main() {
    Widget* raw = new Widget();
    Widget* a = raw;                    // both raw pointers "believe" they own this memory
    Widget* b = raw;
    delete a;                           // first release
    delete b;                           // second release of the same address -> double free
    return 0;
}
```

```text
Widget destructed
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

`Widget destructed` prints only once, and then the process is terminated by ASan. The second `delete` never gets a chance to run the destructor — which shows that "number of destructor calls" is not the same as "number of deletes"; once ownership is ambiguous, destructor semantics have already broken down.

**The common root of all three classes**: a raw pointer does not record ownership. A leak is "forgot to release"; an early return is "the release path was skipped"; a double free is "two pointers both believe they own it". Smart pointers exist to move "owning" out of the programmer's memory and into the type system.

## 2. RAII: Hand Resources to a Stack Object

The one-sentence core of RAII (Resource Acquisition Is Initialization): **acquire the resource in the constructor, release it in the destructor; the object's lifetime is bound to the resource's lifetime.**

When a stack object leaves scope, its destructor **is guaranteed** to run — even on `return` and even if an exception is thrown. Smart pointers are this rule applied to heap memory: the object you `new` is wrapped inside them, the smart pointer itself lives on the stack, and when it dies, the heap object it points to is released.

Here is a minimal RAII carrier — not a smart pointer, but the same mechanism at work:

```cpp
// 02_raii.cpp  compile: g++ -std=c++17 02_raii.cpp
#include <cstdio>

class IntHolder {
    int* p_;
public:
    explicit IntHolder(int v) : p_(new int(v)) {
        std::printf("IntHolder constructed, holding %d\n", *p_);
    }
    ~IntHolder() {
        std::printf("IntHolder destructed, releasing %d\n", *p_);
        delete p_;
    }
    IntHolder(const IntHolder&) = delete;
    IntHolder& operator=(const IntHolder&) = delete;
};

void scope_example() {
    IntHolder h(42);
    std::printf("inside scope_example\n");
}   // h destructed; releases the heap memory pointed to by p_

int main() {
    scope_example();
    std::printf("back in main\n");
    return 0;
}
```

```text
IntHolder constructed, holding 42
inside scope_example
IntHolder destructed, releasing 42
back in main
```

The destructor print appears when `scope_example` ends and before `back in main` — visible proof that "when the object leaves scope, the resource is returned automatically". The internals of `unique_ptr` are essentially this `IntHolder`, except that "holding a pointer" is made a template and "releasing" is made a customizable deleter.

## 3. `unique_ptr`: Exclusive Ownership

### 3.1 Basic Semantics and Move

`unique_ptr`'s copy constructor and copy assignment are `= delete`; it can only be moved. After a move, the source is set to null (in practice `get()` returns `nullptr`; the standard describes it as "valid but unspecified").

```cpp
// 03_unique_move.cpp  compile: g++ -std=c++17 03_unique_move.cpp
#include <cstdio>
#include <memory>
#include <utility>

struct Widget {
    int id;
    explicit Widget(int i) : id(i) { std::printf("Widget(%d) constructed\n", id); }
    ~Widget() { std::printf("Widget(%d) destructed\n", id); }
};

int main() {
    auto p = std::make_unique<Widget>(1);
    std::printf("p.get() = %p, bool(p) = %d\n", (void*)p.get(), (bool)p);

    auto q = std::move(p);                    // transfer ownership
    std::printf("after move: p.get() = %p, bool(p) = %d\n",
                (void*)p.get(), (bool)p);
    std::printf("after move: q.get() = %p, bool(q) = %d\n",
                (void*)q.get(), (bool)q);
}   // q destructed -> Widget(1) destructed
```

```text
Widget(1) constructed
p.get() = 0x...  , bool(p) = 1
after move: p.get() = (nil), bool(p) = 0
after move: q.get() = 0x...  , bool(q) = 1
Widget(1) destructed
```

After the move, `p` is empty, `q` holds the sole ownership, and exactly one destruction happens. **Default to `unique_ptr`**: unless sharing is genuinely needed, always reach for it first.

**Follow-up Q1: Why can't `unique_ptr` be copied? What state is the source left in after a move?**

Copying would produce two holders that each believe they are "exclusive", and when both are destroyed, each calls `delete` on the same address — a double free. Deleting the copy constructor moves the misuse from a runtime crash to a compile error, which is the classic way of encoding ownership semantics into the type system. Move construction/assignment transfers the internal pointer to the target and nulls the source; the standard says a moved-from `unique_ptr` is "valid but unspecified", and in practice `get()` returns `nullptr`, so it can be safely destroyed, reassigned, or moved again — but dereferencing it is undefined behavior. `release()` is another path: it hands out the raw pointer and nulls itself, leaving the caller responsible for the eventual release.

### 3.2 Advanced: Deleters and `sizeof`

The size of `unique_ptr<T, Deleter>` depends on the deleter type. **The default deleter `std::default_delete<T>` and captureless lambdas / empty functors are empty classes, which under the empty base optimization (EBO) occupy no extra space, so `sizeof(unique_ptr<T>) == sizeof(T*)**`. But if the deleter is a **function pointer** or a **stateful function object**, the `unique_ptr` grows.

| Deleter type                            | `sizeof(unique_ptr)` (64-bit)                         | Reason                            |
| :-------------------------------------- | :---------------------------------------------------- | :-------------------------------- |
| `default_delete<T>`                     | `sizeof(T*)` = 8                                      | EBO, empty class takes 0 bytes    |
| Captureless lambda / empty functor      | 8                                                     | EBO applies the same way          |
| Function pointer `void(*)(T*)`          | 16                                                    | Must store an extra pointer value |
| Lambda with captures / stateful functor | `sizeof(T*) + sizeof(state)`, rounded up to alignment | Must store the captured state     |
| `std::function<void(T*)>`               | ~40+ bytes                                            | Heavy type-erasure overhead       |

The `sizeof` values can be observed directly:

```cpp
// 04_unique_sizeof.cpp  compile: g++ -std=c++17 04_unique_sizeof.cpp
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

Typical output (GCC / Clang, 64-bit Linux):

```text
sizeof(Widget*)           = 8
default_delete            = 8
empty functor             = 8
stateful functor          = 12
function pointer          = 16
std::function             = 40
```

The conclusion is clear: **if a captureless lambda or empty functor will do, don't use a function pointer**; a function pointer adds 8 bytes to every `unique_ptr`, and that cost multiplies when they live in arrays or structs.

### 3.3 Advanced: PIMPL and Incomplete Types

When a header declares a member as `std::unique_ptr<Impl>` (the PIMPL idiom) and `Impl` is only forward-declared, the compiler-generated default destructor needs a complete `Impl` in order to instantiate `default_delete`, which triggers:

```text
error: invalid application of 'sizeof' to incomplete type 'Widget::Impl'
```

The fix: **declare** the destructor in the header (declaration only, no definition) and `= default`-define it in the `.cpp`, where `Impl` is complete:

```cpp
// widget.h
#pragma once
#include <memory>

class Widget {
public:
    Widget();
    ~Widget();                               // key: declaration only, definition deferred to .cpp
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
    ~Impl() { std::printf("Impl destructed\n"); }
};

Widget::Widget() : pimpl_(std::make_unique<Impl>()) {}
Widget::~Widget() = default;                 // Impl is complete here, so the default destructor can be generated
Widget::Widget(Widget&&) noexcept = default;
Widget& Widget::operator=(Widget&&) noexcept = default;
```

Move construction and move assignment work the same way: they too need `Impl` to be complete, so they are also deferred to the `.cpp`. `std::unique_ptr` is the only smart pointer that can be used this way — `shared_ptr` type-erases its deleter, so it doesn't need `T` to be complete at destruction time, but the price is an extra allocation for the control block; `unique_ptr` gains zero extra allocation by making "the deleter part of the type", and the cost is that in PIMPL you must manually control where the destructor and moves are defined.

## 4. `shared_ptr`: Shared Ownership and Reference Counting

### 4.1 Control Block and Counts

`shared_ptr`'s count does not live in the object; it lives in a heap-allocated **control block**. All copies sharing the same object point at the same control block: copy +1, destroy −1, and **when the strong count reaches zero the object is destroyed**; the control block itself is freed only when both the strong and weak counts reach zero.

```cpp
// 05_shared_count.cpp  compile: g++ -std=c++17 05_shared_count.cpp
#include <cstdio>
#include <memory>

struct Widget {
    int id;
    explicit Widget(int i) : id(i) { std::printf("Widget(%d) constructed\n", id); }
    ~Widget() { std::printf("Widget(%d) destructed\n", id); }
};

int main() {
    auto a = std::make_shared<Widget>(1);
    std::printf("a.use_count() = %ld\n", a.use_count());
    {
        auto b = a;
        std::printf("while b alive: use_count = %ld\n", a.use_count());
    }
    std::printf("after b destroyed: use_count = %ld\n", a.use_count());
}   // a destructed, strong count hits zero -> Widget destructed
```

```text
Widget(1) constructed
a.use_count() = 1
while b alive: use_count = 2
after b destroyed: use_count = 1
Widget(1) destructed
```

**Follow-up Q2: Where is `shared_ptr`'s reference count stored? Why does `make_shared` save one allocation, and what is the cost?**

The count is not inside the `shared_ptr` object; it lives in a heap-allocated control block shared by all copies. `make_shared` puts the object and the control block in **a single heap allocation**, so it uses one fewer `operator new` than `shared_ptr<T>(new T)`, and it also closes the leak window that exists between "new the object" and "construct the shared_ptr" if an exception is thrown in between. The cost is that the object's memory and the control block live and die together: as long as any `weak_ptr` survives, the weak count is non-zero, and the entire allocation (**including the space occupied by the object**) cannot be returned to the allocator. For a large object with a long-lived `weak_ptr`, this can actually delay memory reclamation.

Note that `make_shared` delays **memory release**, not **object destruction**. When the last `shared_ptr` is destroyed, the object's destructor still runs immediately; it is only the memory that waits for the last `weak_ptr` to disappear before being returned to the OS. These two things must be understood separately.

### 4.2 Advanced: `enable_shared_from_this`

When a member function needs to safely turn `this` into a `shared_ptr`, doing `shared_ptr<T>(this)` directly creates an independent control block and leads to a double free. The correct approach is to inherit `enable_shared_from_this<T>`:

```cpp
// 06_shared_from_this.cpp  compile: g++ -std=c++17 06_shared_from_this.cpp
#include <cstdio>
#include <memory>

struct Widget : std::enable_shared_from_this<Widget> {
    ~Widget() { std::printf("Widget destructed\n"); }

    std::shared_ptr<Widget> get_self() {
        return shared_from_this();
    }
};

int main() {
    auto sp = std::make_shared<Widget>();
    auto self = sp->get_self();
    std::printf("sp.use_count() = %ld\n", sp.use_count());  // 2

    // counterexample: stack object calling shared_from_this()
    Widget stack_widget;
    try {
        stack_widget.get_self();            // throws std::bad_weak_ptr
    } catch (const std::bad_weak_ptr& e) {
        std::printf("bad_weak_ptr: %s\n", e.what());
    }
}
```

The precondition for `shared_from_this()` is that **the object is already held by at least one `shared_ptr`**, at which point the internal `weak_ptr` inside the base class gets initialized. A stack object has no `shared_ptr` owner, so the internal `weak_ptr` is empty, and the call throws `bad_weak_ptr`.

### 4.3 Advanced: Thread-Safety Boundaries

This is the most commonly misquoted sentence about `shared_ptr`: "`shared_ptr` is thread-safe." The precise statement needs four layers:

**① Multiple threads reading the same `shared_ptr` instance — safe.** Copy construction, pass-by-value, `get()`, and dereference only read the pointer field inside the instance and don't modify shared state; the read of the control block's strong count is an atomic operation in mainstream implementations. But `use_count()` returns only an **approximate** value; the standard does not guarantee precision, so in multithreaded code don't use it to make decisions like "if the count is 1, I can modify exclusively" — such a decision has its own TOCTOU window.

**② Multiple threads writing \*different\* `shared_ptr` instances (pointing to the same object) — safe.** Each thread operates on its own instance while atomically incrementing/decrementing the shared control block. The standard explicitly says: all member functions (including copy construction and copy assignment) can be called concurrently on different instances by multiple threads without extra synchronization, even if those instances share the same object.

**③ Multiple threads reading and writing the \*same\* `shared_ptr` instance — unsafe.** A `shared_ptr` instance holds at least two pointers internally (object pointer + control block pointer), and `reset`, assignment, and move **modify both fields at once**; the standard provides no synchronization for the instance itself. One thread reading while another calls `reset` is a data race. Solutions: serialize all access to that instance with a mutex, or move to C++20's `std::atomic<std::shared_ptr<T>>` (which only makes a single load/store atomic, not `if (p) p->foo()` compound operations).

**④ Multiple threads accessing the object \*through\* the `shared_ptr` — unprotected.** A smart pointer only promises that the object lives until the last holder releases it; it **does not promise** thread safety for the object's internal state. Multiple threads calling non-const member functions on the same object through their own copies is ordinary data racing, and the object must synchronize itself.

**Follow-up Q3: Is `shared_ptr` thread-safe?**

Answer in three layers. Different instances (including copies that point to the same object) are safe for concurrent reads, copies, and destruction, because the control-block counts are atomic. The same instance is unsafe for concurrent reads and writes, because the object pointer and the control-block pointer inside it are not synchronized. The pointed-to object is entirely unprotected for concurrent access; the smart pointer manages lifetime, not data. So "`shared_ptr` is thread-safe" only holds in the narrow sense of "multiple threads each holding a copy and managing lifetime through their own copies". C++20's `atomic<shared_ptr>` solves "atomic load/store on the same instance", but still does not solve data races inside the object.

## 5. `weak_ptr`: Observer, and Cycles

### 5.1 Strong Count vs Weak Count

`weak_ptr` does not increase the **strong count** (which decides the object's lifetime) but does increase the **weak count**. The control block is released only when `strong count == 0 && weak count == 0`: when the strong count reaches zero the object is destroyed; when the weak count reaches zero the control block itself is freed.

```cpp
// 07_weak_count.cpp  compile: g++ -std=c++17 07_weak_count.cpp
#include <cstdio>
#include <memory>

struct Widget {
    ~Widget() { std::printf("Widget destructed\n"); }
};

int main() {
    std::weak_ptr<Widget> wp;
    {
        auto sp = std::make_shared<Widget>();
        wp = sp;
        std::printf("while sp alive: wp.expired() = %d, wp.use_count() = %ld\n",
                    wp.expired(), wp.use_count());
    }   // sp destructed, strong count hits zero -> Widget destructed
    std::printf("after sp destroyed: wp.expired() = %d, wp.use_count() = %ld\n",
                wp.expired(), wp.use_count());

    auto locked = wp.lock();
    std::printf("lock() returned null: %d\n", locked == nullptr);
}   // wp destructed, weak count hits zero -> control block freed
```

```text
while sp alive: wp.expired() = 0, wp.use_count() = 1
Widget destructed
after sp destroyed: wp.expired() = 1, wp.use_count() = 0
lock() returned null: 1
```

Note that after `Widget` is destroyed, `wp` still exists and `expired()` is true; the control block is only freed when `wp` itself is destroyed. `lock()` is an **atomic** "check + promote": if the strong count is > 0, it returns a valid `shared_ptr`; otherwise it returns an empty one.

**Follow-up Q4: What does `weak_ptr::lock()` return when the object has already been destroyed? Are `expired()` and `use_count() == 0` equivalent?**

`lock()` atomically checks the strong count: if it is > 0 it increments and returns a valid `shared_ptr`; if it is 0 it returns an empty `shared_ptr` — it never throws. `expired()` is semantically "is the strong count zero", so in single-threaded code it is usually consistent with `use_count() == 0`; but the standard does not guarantee `use_count()` precision, so it may read a stale value under concurrency. **To determine whether the object is alive, use `expired()` or check the result of `lock()`** — don't rely on `use_count() == 0`, whose documented purpose is debugging/diagnostics.

### 5.2 Cycles: Full Comparison

When two nodes hold each other via `shared_ptr`, each count is 2; after leaving scope each drops by 1, leaving 1, and neither is destroyed. Changing one side to `weak_ptr` breaks the cycle.

```cpp
// 08_cycle.cpp  compile: g++ -std=c++17 08_cycle.cpp
#include <cstdio>
#include <memory>
#include <string>

struct Node {
    std::string name;
    std::shared_ptr<Node> next;             // default: strong ownership
    explicit Node(std::string n) : name(std::move(n)) {
        std::printf("Node(%s) constructed\n", name.c_str());
    }
    ~Node() { std::printf("Node(%s) destructed\n", name.c_str()); }
};

void leak_cycle() {
    auto a = std::make_shared<Node>("A");
    auto b = std::make_shared<Node>("B");
    a->next = b;
    b->next = a;                            // cycle: a and b strongly own each other
    std::printf("before leak_cycle returns: a.use_count = %ld, b.use_count = %ld\n",
                a.use_count(), b.use_count());  // both 2
}   // stack pointers a, b destroyed, but each count remains 1 -> neither Node destructed

// ---------- Positive: one side becomes weak_ptr ----------

struct Node2 {
    std::string name;
    std::shared_ptr<Node2> next;            // strong ownership
    std::weak_ptr<Node2>   prev;            // weak ownership, not counted in strong
    explicit Node2(std::string n) : name(std::move(n)) {
        std::printf("Node2(%s) constructed\n", name.c_str());
    }
    ~Node2() { std::printf("Node2(%s) destructed\n", name.c_str()); }
};

void no_leak() {
    auto a = std::make_shared<Node2>("A");
    auto b = std::make_shared<Node2>("B");
    a->next = b;
    b->prev = a;                            // weak reference, strong count unchanged
    std::printf("before no_leak returns: a.use_count = %ld, b.use_count = %ld\n",
                a.use_count(), b.use_count());  // a=1, b=2
}   // a, b destroyed, strong counts hit zero -> both Node2 destructed normally

int main() {
    std::printf("=== Negative: shared_ptr cycle ===\n");
    leak_cycle();
    std::printf("=== Positive: one side weak_ptr ===\n");
    no_leak();
    return 0;
}
```

```text
=== Negative: shared_ptr cycle ===
Node(A) constructed
Node(B) constructed
before leak_cycle returns: a.use_count = 2, b.use_count = 2
=== Positive: one side weak_ptr ===
Node2(A) constructed
Node2(B) constructed
before no_leak returns: a.use_count = 1, b.use_count = 2
Node2(B) destructed
Node2(A) destructed
```

In the negative case, **no destructor print appears** after `leak_cycle` returns — both `Node`s have a strong count stuck at 1 and neither lets go. In the positive case, after changing one side to `weak_ptr`, the cycle is broken and both objects are destroyed normally.

**Follow-up Q5: What happens when you construct two `shared_ptr`s from the same raw pointer?**

The two `shared_ptr`s each create **an independent control block**, each with a strong count of 1, unaware of each other. The first to be destroyed `delete`s the object; the second to be destroyed `delete`s the same address again — a double free, structurally identical to the raw-pointer case in §1.2. Note the distinction: copying from an **existing `shared_ptr`** shares the same control block and is completely safe; the problem only arises when constructing independently from a raw pointer. Ways to avoid it: prefer `make_shared`; let the object's creator construct the `shared_ptr` exactly once and pass copies or `weak_ptr`s elsewhere; when a class needs to construct from `this`, inherit `enable_shared_from_this` and call `shared_from_this()`.

## 6. Custom Deleters: Smart Pointers Manage More Than Heap Memory

The bigger value of smart pointers is managing **any resource that requires paired release**: `FILE*`, POSIX fds, `HANDLE`s, `mmap` regions, and so on. The way `unique_ptr` and `shared_ptr` handle deleters is itself an extension of their ownership semantics:

|                                          | `unique_ptr`                                                 | `shared_ptr`                                                 |
| :--------------------------------------- | :----------------------------------------------------------- | :----------------------------------------------------------- |
| Is the deleter part of the type?         | **Yes**, `unique_ptr<T, D>` and `unique_ptr<T>` are different types | **No**, passed at construction and erased into the control block |
| Does the deleter affect `sizeof`?        | Yes (see §3.2)                                               | No, `shared_ptr` size is unchanged                           |
| Is the deleter called on a null pointer? | **No** (guaranteed since C++11)                              | **Yes** (as long as the control block exists)                |

That last difference is the source of many bugs: if the deleter has side effects (closing an fd, writing a log), `unique_ptr` skips the deleter on a null pointer while `shared_ptr` executes it. Don't write critical logic that depends on "the deleter is always called".

Here is a `FILE*` comparison of the two styles:

```cpp
// 09_file_deleter.cpp  compile: g++ -std=c++17 09_file_deleter.cpp
#include <cstdio>
#include <memory>

struct FileCloser {
    void operator()(std::FILE* f) const {
        if (f) {
            std::printf("closing file\n");
            std::fclose(f);
        }
    }
};

int main() {
    // unique_ptr: deleter is part of the type; empty functor is zero-overhead
    using FilePtr = std::unique_ptr<std::FILE, FileCloser>;
    {
        FilePtr f(std::fopen("/tmp/demo_unique.txt", "w"), FileCloser{});
        if (!f) { std::printf("open failed\n"); return 1; }
        std::fputs("hello from unique_ptr", f.get());
    }   // f destructed -> FileCloser called -> fclose

    // shared_ptr: deleter is not part of the type, passed at construction
    {
        std::shared_ptr<std::FILE> g(
            std::fopen("/tmp/demo_shared.txt", "w"),
            [](std::FILE* fp) {
                if (fp) { std::printf("closing shared file\n"); std::fclose(fp); }
            }
        );
        if (!g) { std::printf("open failed\n"); return 1; }
        std::fputs("hello from shared_ptr", g.get());
    }   // g destructed, strong count hits zero -> deleter called

    return 0;
}
```

With the stateless `FileCloser`, `unique_ptr<FILE, FileCloser>` is still 8 bytes; `shared_ptr<FILE>` keeps the same size because the deleter is type-erased into the control block, at the cost of the control block's extra allocation.

## 7. Comparison Cheat Sheet

| Aspect                    | `unique_ptr`                           | `shared_ptr`                                   | `weak_ptr`                           |
| :------------------------ | :------------------------------------- | :--------------------------------------------- | :----------------------------------- |
| Ownership                 | Exclusive                              | Shared                                         | None (observer)                      |
| Strong ref count          | None                                   | Yes, atomic                                    | Not involved                         |
| Weak ref count            | None                                   | Yes (keeps control block alive)                | Involved (keeps control block alive) |
| Copyable?                 | No, move only                          | Yes                                            | Constructed from `shared_ptr`        |
| Release timing            | When the holder leaves scope           | When the strong count hits 0                   | Does not release the object          |
| Access                    | `->` / `*` directly                    | `->` / `*` directly                            | Must `lock()`                        |
| Deleter                   | **Part of the type**, affects `sizeof` | Not part of the type, does not affect `sizeof` | N/A                                  |
| Default `sizeof` (64-bit) | 8 (default deleter, EBO)               | 16 (object ptr + control-block ptr)            | 16                                   |
| Deleter on null pointer   | **Not called**                         | Called (if the control block exists)           | N/A                                  |
| Array support             | `unique_ptr<T[]>` (C++11)              | `shared_ptr<T[]>` (C++17)                      | N/A                                  |
| Thread-safety boundary    | Moving is unsafe (same instance)       | See §4.3 four layers                           | Control-block counts safe            |
| Typical use               | Default for owning a single object     | Multiple sites jointly holding one object      | Breaking cycles, caches/observers    |

## 8. Common Misconceptions and Version Timeline

### Misconceptions

**① Treating `unique_ptr` like a raw pointer and copying it.** The compiler rejects it outright; that's by design, not a defect.

**② Feeding the same raw pointer to multiple smart pointers.** Two independent control blocks → double free. Use `make_unique` / `make_shared` from the start and never reconstruct from an existing raw pointer.

**③ `weak_ptr` can stand alone.** It cannot. It must be constructed from a `shared_ptr`, and it cannot pair with `unique_ptr`.

**④ Abusing `shared_ptr` just because it exists.** Shared ownership makes object lifetimes harder to reason about; if exclusive ownership will do, don't share. `unique_ptr` is the default first choice.

**⑤ Using a smart pointer on a stack object.** Smart pointers only release heap objects; stack objects already have automatic lifetime, and handing one to a smart pointer leads to `delete` on a stack address — undefined behavior.

**⑥ Believing that `make_shared`'s `weak_ptr` prevents object destruction.** It doesn't. Object destruction is determined by the strong count; `weak_ptr` only delays the return of the **entire allocation** (see the end of §4.1).

### Version Timeline

| Feature                                                   | Minimum standard |
| :-------------------------------------------------------- | :--------------- |
| `auto_ptr` (deprecated, removed in C++17)                 | C++98            |
| `unique_ptr` / `shared_ptr` / `weak_ptr`                  | **C++11**        |
| `make_unique`                                             | **C++14**        |
| `shared_ptr<T[]>`                                         | **C++17**        |
| `make_unique_for_overwrite`, `make_shared` array overload | **C++20**        |
| `std::atomic<std::shared_ptr<T>>`                         | **C++20**        |

`auto_ptr`'s "copy means transfer ownership" semantics is exactly what motivated `unique_ptr` to redesign with move semantics: copy semantics are explicitly deleted, and a transfer must be an explicit `std::move`.

## 9. Further Reading: Entry Points into the Source

No toy implementation is written here. Readers who want to go deeper should read industrial-grade sources, with a question in hand:

| Implementation  | File                                              | Symbols to read                                            |
| :-------------- | :------------------------------------------------ | :--------------------------------------------------------- |
| libstdc++ (GCC) | `bits/unique_ptr.h`                               | `__uniq_ptr_impl`, `default_delete`, move constructor      |
| libstdc++ (GCC) | `bits/shared_ptr_base.h`                          | `_Sp_counted_base::_M_release`, `_M_dispose`, `_M_destroy` |
| libc++ (Clang)  | `__memory/unique_ptr.h` / `__memory/shared_ptr.h` | `__uniq_ptr_impl`, `__shared_count`, `__shared_weak_count` |
| MSVC STL        | `<memory>`                                        | `_Ref_count_base`, `_Ref_count`, `_Ref_count_resource`     |

A concrete entry point: in libstdc++, the `_Sp_counted_base` constructor initializes both `_M_use_count` and `_M_weak_count` to 1, and inside `_M_release()` it first handles the strong-count-hits-zero case (calling `_M_dispose()` to destruct the object) and then handles the weak-count-hits-zero case (calling `_M_destroy()` to free the control block). Once you see those two paths clearly, the "strong count hits zero destroys the object, weak count hits zero frees the control block" statements in §4.1 and §5.1 stop being verbal conclusions and become facts you can verify line by line in the source.

------

**References**

- `<memory>` header overview: https://en.cppreference.com/w/cpp/memory
- RAII: https://en.cppreference.com/w/cpp/language/raii
- `std::weak_ptr` (cycles): https://en.cppreference.com/w/cpp/memory/weak_ptr
- `std::shared_ptr` thread-safety notes: https://en.cppreference.com/w/cpp/memory/shared_ptr