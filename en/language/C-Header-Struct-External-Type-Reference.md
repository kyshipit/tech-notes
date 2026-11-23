**English** | [简体中文](../../language/C头文件结构体外部类型引用.md)

# Referencing External Types in C Header Files: Complete Decisions for typedef, struct and include

You have almost certainly run into errors like these:

```text
error: unknown type name 'Course'
error: conflicting types for 'Student'
```

A header file needs to reference a type defined in another header file. This type may be a structure, union, or enumeration; in what follows it is collectively referred to as an **external type**, denoted `X`; the header file that defines it is referred to as the **definition header**.

Including the definition header directly causes three problems: two headers include each other to form a circular dependency; one header is indirectly included by a large number of source files, so changing one place triggers a broad rebuild; the same alias is defined repeatedly across multiple headers, triggering a `conflicting types` error.

This article answers only three questions: **whether to introduce an alias for `X`, whether to write `struct X` or `X` when referencing it, and whether to use `include` or a forward declaration in the header file.** The criteria for these three questions are completely different and must be considered separately.

There is only one criterion running through the entire article:

> **When the compiler compiles this header file, does it need to know the complete size and member layout of `X`.**

## Layer 1: Whether to Introduce an Alias for `X`

This is not a language issue; it is an engineering style choice. Large C projects are roughly divided into two schools, with no single mandatory standard, but every project must be internally consistent and cannot mix the two styles.

**School A: Do not introduce aliases for ordinary structures.** All references write `struct X`. The rationale is to retain the visual reminder that "this is a structure", preventing developers from passing large structures by value without realizing it. Formal exceptions apply only to opaque types, fixed-width integers, sparse types, and shared userspace types; function pointer typedef is a practical consensus, not a formal documented exception.

**School B: Uniformly introduce aliases for structures.** Everywhere the alias is visible, write `X`. The tradeoff is that typedefs must be centrally managed, defined in only one place, and copying them everywhere is prohibited.

The two schools write the same business logic as follows:

```c
/* School A */
struct Course {
    int code;                  /* course code */
    char title[64];            /* course name */
    int credits;               /* credits */
    struct Student *monitor;   /* class representative */
};

struct Course *course_create(int code, const char *title, int credits);
```

typedef style

```c
/* School B */
typedef struct Course {
    int code;                  /* course code */
    char title[64];            /* course name */
    int credits;               /* credits */
    struct Student *monitor;   /* class representative */
} Course;

Course *course_create(int code, const char *title, int credits);
```

Both are correct, but **the project must be consistent internally**. A `Course *` appearing in School A's code is wrong; writing `struct Course *` everywhere in School B's code is legal but violates the project style. Mixing the two will not produce compile errors, but it increases reading costs and makes refactoring more error-prone.

Code comments only state the business meaning (course code, course name, credits, class representative) and do not annotate categories such as "this is a pointer member". Classification belongs in the prose; the code stays faithful to itself.

## Layer 2: Write `struct X` or `X`

This layer depends on the result of Layer 1.

If the project does not introduce an alias for `X`, this question does not exist; write `struct X` everywhere.

If the project has introduced an alias for `X`, whether to write `X` or `struct X` when referencing it depends solely on **whether the alias is visible at the current location**:

- Alias visible (definition header already included, or common forward header already included) → writing `X` is legal, and writing `struct X` is also legal; the project style may uniformly prescribe which one to use.
- Alias not visible → `struct X` **must** be written.

**When the alias is not visible, do not add a line `typedef struct X X;` in the current header file just to write `X`.** That introduces the risk of duplicate typedefs across translation units.

The most typical "alias not visible" scenario is when two headers each need a pointer to the other:

student.h

```c
/* student.h */
#ifndef STUDENT_H
#define STUDENT_H

struct Course;   /* forward declaration; the alias Course does not exist yet */

typedef struct Student {
    int id;                     /* student ID */
    char name[32];              /* name */
    struct Course *course;      /* currently selected course; must write struct Course * */
} Student;

Student *student_create(int id, const char *name);

#endif
```

course.h

```c
/* course.h */
#ifndef COURSE_H
#define COURSE_H

struct Student;   /* forward declaration; the alias Student does not exist yet */

struct Course {
    int code;                  /* course code */
    char title[64];            /* course name */
    int credits;               /* credits */
    struct Student *monitor;   /* class representative; must write struct Student * */
};

struct Course *course_create(int code, const char *title, int credits);

#endif
```

The two headers **do not include each other**; each uses a forward declaration, cutting the circular dependency at the header level.

In `student.h`, `struct Course *` must be written, because `struct Course;` only declares the tag, and the alias `Course` does not yet exist in the ordinary namespace. In `student.c`, `course.h` is included, the alias `Course` becomes visible, and `Course *` can then be written:

student.c

```c
/* student.c */
#include "student.h"
#include "course.h"   /* included only in the implementation file to obtain the complete Course definition */

void student_enroll(Student *s, Course *c)
{
    s->course = c;
    c->credits = 3;   /* members of Course can be accessed here */
}
```

## Layer 3: Include or Forward Declaration

This layer is independent of the typedef style. There is only one criterion: **whether the compiler needs a complete type.**

**Complete type not needed → forward declaration, do not include the definition header.** Typical cases: only a pointer to `X` appears in the header — structure member, function parameter, function return value, or function pointer parameter. (For example, holding a course pointer in the student structure.)

**Complete type needed → the definition header must be included.** Typical cases: the structure member is an entity of `X`; `sizeof(X)` is needed; an inline function in the header accesses members of `X` through a pointer; macros, enumeration values, or the alias itself from the definition header are used. (For example, placing a grade entity directly in the student structure requires including the grade definition header.)

Both treatments may coexist in the same header. The criterion applies separately to each type:

grade.h

```c
/* grade.h —— grade, independent entity, no circular dependency */
#ifndef GRADE_H
#define GRADE_H

typedef struct Grade {
    int score;                 /* score */
    int semester;              /* semester */
} Grade;

#endif
```

student.h

```c
/* student.h */
#ifndef STUDENT_H
#define STUDENT_H

#include "grade.h"       /* Grade is an entity member; must include */
#include <stdbool.h>

struct Course;           /* Course appears only as a pointer member; a forward declaration suffices */

typedef void (*EnrollCallback)(struct Course *course, void *user);

typedef struct Student {
    int id;                     /* student ID */
    char name[32];              /* name */
    struct Course *course;      /* currently selected course */
    Grade grade;                /* grade, entity member */
    EnrollCallback on_enroll;   /* callback on successful enrollment */
    void *user;                 /* callback context */
    bool enrolled;              /* whether enrolled */
} Student;

Student *student_create(int id, const char *name);
void student_destroy(Student *s);
void student_set_callback(Student *s, EnrollCallback cb, void *user);
void student_enroll(Student *s, struct Course *c);
int  student_get_course_credits(Student *s);

#endif
```

- `grade.h` is included because `Grade grade;` is an entity member; the compiler needs `sizeof(Grade)` to allocate space for `Student`. `course.h` is not included because `Course` appears only as a pointer; pointer size is fixed, and the forward declaration `struct Course;` is sufficient.
- If `Course` were also written as an entity member without inclusion, the compiler would report `incomplete type` directly. **A forward declaration is completely ineffective for entity members.**
- After including the complete header in `student.c`, members can be accessed and callbacks invoked:

student.c

```c
/* student.c */
#include "student.h"
#include "course.h"   /* included only in the implementation file */

#include <stdlib.h>

void student_enroll(Student *s, struct Course *c)
{
    s->course = c;
    s->enrolled = true;

    if (s->on_enroll != NULL) {
        s->on_enroll(c, s->user);   /* invoke callback */
    }
}

int student_get_course_credits(Student *s)
{
    if (s->course == NULL) return -1;
    return s->course->credits;   /* members of Course can be accessed */
}
```

The callback type `EnrollCallback` takes `struct Course *` as its parameter, which likewise only needs a forward declaration. When the callback is invoked, what is passed in is also a pointer.

## Cheat Sheet

| What appears in the header                                   | What to do                                                   |
| :----------------------------------------------------------- | :----------------------------------------------------------- |
| `struct X *p;` (e.g., course pointer in student)             | `struct X;` forward declaration, do not include the definition header |
| `X obj;` or `struct X obj;` (entity member, e.g., grade in student) | `#include` the definition header                             |
| `sizeof(X)`                                                  | `#include` the definition header                             |
| `p->member` in an inline function                            | `#include` the definition header                             |
| Using macros, enumerations, or the alias itself from the definition header | `#include` the definition header                             |
| Two headers each need a pointer to the other                 | Both use `struct X;`, neither includes the other             |
| Want to write `X *` but the alias is not visible             | Fall back to `struct X *`; do not duplicate the typedef      |

## Summary

**The typedef style determines whether to write `X` or `struct X`; whether the alias is visible determines whether `struct` may be omitted; whether the compiler needs a complete type determines include or forward declaration. Judge the three layers separately; do not mix them.** The criterion remains the same throughout: whether the compiler needs to know the size and member layout of this type. Once this line is drawn clearly, the two classes of errors `unknown type name` and `conflicting types` will not occur structurally.
