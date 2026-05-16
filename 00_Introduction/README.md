# Part 00 — Introduction

> "The CPU is a stupid machine that does one tiny thing extremely fast, billions of times per second. Assembly is the list of those tiny things."

## A story before we start

Imagine a very fast worker sitting at a desk in a giant warehouse.

The worker can only do tiny, simple jobs: "grab the cup labeled A," "add one to whatever is in cup A," "put cup A back down." That's it. No big tasks. No "make me a sandwich." Just one tiny action at a time.

But the worker is *insanely* fast — they can do billions of these tiny actions every second. Stack enough tiny actions together and suddenly you have web browsers, video games, and Netflix.

That worker is the **CPU** (the Central Processing Unit — the brain chip inside every computer).

The list of tiny actions you hand the worker is called **assembly language**. This course teaches you how to write that list.

## Why learn assembly in 2026?

Be honest: you will (almost) never *write* assembly to ship a real product. So why bother?

Because you will often need to **read** it. Here are the moments where knowing assembly suddenly matters:

- A **profiler** (a tool that measures which parts of a program are slow) points at a tiny chunk of assembly code and says "this is your bottleneck." You need to understand what it's showing you.
- A bug only shows up when the program is built in "release mode" (the optimized version), and the original code you wrote no longer matches what's actually running on the CPU.
- A program crashes and there are no helpful labels left — just raw machine instructions.
- You want to know what mysterious programming words like `volatile`, `restrict`, atomics, or SIMD intrinsics *actually* do down at the metal.
- You're learning how compilers, operating systems, security, or embedded chips work.

The real payoff isn't "I can write assembly now." The real payoff is **demystification** — losing the feeling that computers are magic. Once you know what registers, the stack, calling conventions, and addressing modes are (don't worry, we'll explain all of these), every higher-level programming language stops feeling like sorcery and starts feeling like a tool.

## The mental model, in one picture

Here is the picture to keep in your head for this whole course:

```
                +----------------------------------+
                |              CPU                 |
                |  +----------------------------+  |
                |  |        Registers           |  |
                |  |  rax  rbx  rcx  rdx        |  |
                |  |  rsi  rdi  rbp  rsp        |  |
                |  |  r8 .. r15                 |  |
                |  |  rip   rflags              |  |
                |  +----------------------------+  |
                |             ^   |                |
                |   load / lea|   |store           |
                +-------------|---|----------------+
                              |   v
                +----------------------------------+
                |             Memory               |
                |   .text   (your instructions)    |
                |   .data   (initialized globals)  |
                |   .bss    (zero-init globals)    |
                |   stack   (grows down from top)  |
                |   heap    (grows up, via mmap)   |
                +----------------------------------+
```

Translating that picture into our warehouse story:

- The **CPU** is the worker.
- **Registers** are a small set of labeled cups sitting right on the worker's desk. They have funny names like `rax`, `rbx`, `rcx`. The worker can grab from a cup in basically zero time.
- **Memory** (also called RAM) is the giant warehouse of numbered shelves behind the desk. There are billions of shelves. Reaching back to grab from a shelf is *much* slower than grabbing from a cup — but there is *way* more room out there.
- The arrows in the picture are the worker walking back and forth: **load** = "go fetch from a shelf and put it in a cup"; **store** = "take what's in a cup and put it on a shelf."

A CPU is a tiny machine that, forever, does this loop:

1. Look at the address stored in a special cup called **`rip`** (the **instruction pointer** — the cup that always says "what should I do next?").
2. Walk to that shelf in the warehouse and read the instruction written on it.
3. Figure out what that instruction means ("decode" it).
4. Do it — usually this moves bits between **registers** (cups) and **memory** (shelves), or does some math on cups.
5. Bump `rip` to point at the *next* shelf in line (unless the instruction was a "jump," meaning "go look at a different shelf instead").
6. Go back to step 1.

Forever. Billions of times per second. That's it. That's the whole CPU.

Everything else — functions, loops, objects, garbage collectors, web servers, video games — is built on top of that one loop.

## What is "x86_64"?

"x86_64" is the name of a particular family of CPUs and the language they speak. A quick history:

- **x86**: a family of CPU designs starting with the Intel 8086 chip in 1978. ("x86" because most of the chip names ended in 86 — 8086, 80286, 80386, etc.) The first ones could only handle 16 bits at a time, then later 32 bits.
- **x86_64** (also called AMD64, x64, or Intel 64): the **64-bit** version, designed by AMD in 2003 and later adopted by Intel. "64-bit" means each cup (register) can hold a number up to 64 binary digits long — enormously larger than before. Addresses (shelf numbers) are also 64 bits, and there are 16 general-purpose cups on the desk instead of the original 8.

When you write assembly, you write **symbolic** instructions — readable words like `mov rax, 60`. Then several tools take over:

- The **assembler** is a program that turns your readable words into the actual numeric bytes the CPU eats (`48 c7 c0 3c 00 00 00`). "Assembling" = translating from words to bytes.
- The **linker** glues together multiple bundles of bytes (from different files) into one finished program, and figures out the real shelf numbers (addresses) for everything.
- The **OS loader** is part of your operating system (Linux, in our case). When you double-click or run a program, the loader copies it into the warehouse (memory), sets `rip` to point at the first instruction, and lets the CPU loose.

## Tools you need

On any Linux distro, check that these programs are installed:

```bash
which as ld gcc gdb objdump   # should all exist
```

What each one is:
- `as` — the **assembler** (turns your `.s` files into `.o` files of bytes).
- `ld` — the **linker** (glues `.o` files into a runnable program).
- `gcc` — a C compiler; we'll occasionally use it to compare what C turns into.
- `gdb` — the **debugger**, a magic tool that lets you step through your program one instruction at a time and peek at every cup.
- `objdump` — a tool that shows you the bytes inside a built program, translated back into readable instructions.

If `as` is missing, install `binutils`. If `gcc` is missing, install `build-essential` (Debian/Ubuntu) or `base-devel` (Arch).

## AT&T vs Intel syntax (and why we pick Intel)

There are two different "dialects" for writing assembly that mean the exact same thing to the CPU, but look different on the page. Here is one instruction in both:

```
AT&T:    movq  $60, %rax
Intel:   mov   rax, 60
```

Both say "put the number 60 into the cup named `rax`." They just argue about how to write it.

Differences:

| Aspect          | AT&T              | Intel              |
| --------------- | ----------------- | ------------------ |
| Operand order   | `src, dst`        | `dst, src`         |
| Register prefix | `%rax`            | `rax`              |
| Immediate       | `$60`             | `60`               |
| Memory          | `8(%rbp,%rcx,4)`  | `[rbp + rcx*4 + 8]`|
| Size suffix     | `movq`, `movl`    | size from operands |

The trickiest difference is **operand order**: AT&T writes "from, to" while Intel writes "to, from." Most beginners find Intel more natural ("`mov rax, 60`" reads almost like English: "move into rax the value 60").

GCC and `objdump` default to AT&T on Linux. But Intel's official manuals, Intel's optimization guides, and almost every textbook use Intel. **We will use Intel** in this course and put `.intel_syntax noprefix` at the top of every file (that's the line that tells the assembler "I'm writing in Intel style, and please don't make me put `%` in front of register names"). When you run `objdump` on a program, pass `-M intel` to get the same view.

## Scope and limitations

This course makes specific choices so explanations can be concrete instead of hedged with "well, on some systems..." every paragraph. Here's what we're including and what we're skipping:

- **OS: Linux only.** Every example uses Linux **syscalls** (a "syscall" is when your program politely asks the operating system to do something for it, like "please print this text to the screen" — we cover this in detail in Part 01) and the System V AMD64 ABI ("ABI" = the agreed-upon rulebook for how programs talk to each other on this OS). On **macOS** the rulebook is similar but the syscall numbers are different and you can't make syscalls directly — you have to go through a library called libc. On **Windows** everything OS-related is completely different. The *instructions* and *registers* themselves are identical on every OS; only the parts of the course that talk to the OS (Parts 01, 11, 13, 14) would need changes.
  - On Windows, run this course inside **WSL2** (Windows Subsystem for Linux — a way to run Linux inside Windows) for the smoothest experience.
- **Architecture: x86_64 only.** Other CPU families like ARM64 (the chips in iPhones and Apple Silicon Macs), RISC-V, and 32-bit x86 use different register names, different byte encodings, and different ways of doing math with addresses. The big-picture mental model — fetch/decode/execute, cups on a desk, shelves in a warehouse, a calling convention — carries over; the exact spellings do not.
- **Assembler: GNU `as` in Intel syntax.** Other assemblers (NASM, FASM, MASM) have slightly different rules for things like "how do you mark the start of a data section." The actual instructions are identical.
- **Mode: 64-bit user-space.** "User-space" means we write normal programs that the operating system runs for us. We never touch 16-bit real mode, 32-bit protected mode, "ring 0" (the kernel's special privileged mode), paging, interrupts, or the boot process. If you want to write your own operating system, this course gives you the foundation but not the destination — see [Part 15](../15_Where_Next/README.md).
- **No floating point or SIMD** until the closing pointers in [Part 15](../15_Where_Next/README.md). The CPU has a whole separate set of cups (named `xmm`, `ymm`, `zmm`) and instructions for working with decimal numbers and for doing many calculations in parallel. It's a parallel universe; we stay in "whole-number land" to keep the model tight.
- **No security topics.** Topics like buffer overflows, stack canaries, and ASLR are all visible from here, but we don't cover them.
- **Performance is mentioned, not pursued.** We sometimes note when an instruction is fast or slow, but this is not a tuning guide.
- **Modern CPUs only.** We freely use instructions added since around 2008. If you're targeting a 1995 Pentium, you have other problems.

If any of these are dealbreakers, the right pivot:

| You want…                       | Better resource                                    |
| ------------------------------- | -------------------------------------------------- |
| Windows-native asm              | "Modern x64 Assembly" (Daniel Kusswurm), MASM docs |
| ARM64                           | ARM's official *Learn the architecture* series     |
| OS development                  | OSDev wiki, *Operating Systems: Three Easy Pieces* |
| Performance / microarchitecture | Agner Fog's manuals, Intel optimization guide      |
| Security / exploitation         | *Hacking: The Art of Exploitation*, pwn.college    |

## What's next

In [Part 01](../01_Hello_CPU/README.md) we write the smallest possible Linux program that prints `Hello, CPU!\n` and exits. We will inspect every single line and every single byte of the resulting binary.
