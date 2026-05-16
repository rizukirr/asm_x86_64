# A Journey Through x86_64 Assembly

## What is this, in one paragraph?

Imagine the inside of your computer as a kitchen. There is one extremely fast worker (the **CPU**), a small set of labeled cups on the counter where the worker keeps things they're using right now (the **registers**), and a giant warehouse of numbered shelves where everything else is stored (the **memory**, also called RAM). Every program you have ever run — your browser, your games, this very text editor — is, deep down, just a long list of tiny instructions telling that worker to move things between cups and shelves, do a little math, and occasionally ask the building manager (the **operating system**) for help. **Assembly language** is the human-readable name for those tiny instructions. This course teaches you to read and write them on the most common kind of CPU in the world today: **x86_64**.

## Why bother in 2026?

You will almost never *write* assembly for a real job except your are codec engineer, AI kernel, operating system or something related to performance critical engineering and hardware. But you will, very often, **read** it — when a program is mysteriously slow, when a crash report shows numbers instead of code, when you want to understand what a higher-level language is *actually* doing under the hood. After this course, computers should feel less like magic and more like very fast, very obedient machines you can reason about.

The goal isn't to memorize hundreds of instructions. The goal is to build a **mental model** — a picture in your head of what the CPU is doing — so that when you see assembly anywhere, you can think your way through it instead of guessing.

## How this course is shaped

We follow the same rhythm as Warren Toomey's *A Compiler Writing Journey*: each chapter introduces **one new idea**, shows you the smallest possible program that uses that idea, and then walks through it line by line in plain English.

By the end you will be able to:

- Read disassembly (the assembly code that a compiler produces from C, Rust, etc.).
- Write a tiny standalone program that talks to the Linux kernel directly.
- Have a normal conversation between assembly code and C code.
- Know where to go next: SIMD (doing math on many numbers at once), floating-point, optimization, and operating-system development.

## The tools we use (don't worry, they're all standard)

A quick word on each, in plain English:

- **Assembler: GNU `as`.** This is the program that turns your hand-written assembly text file into raw bytes the CPU can actually run. We use it in **Intel syntax** by writing `.intel_syntax noprefix` at the top of every file. Intel syntax reads naturally as `mov destination, source` — "move into the destination, from the source" — which matches almost every reference book and Intel's own manuals.
- **Linker: `ld`.** A linker stitches together one or more "object files" (the raw output of the assembler) into a single runnable program. For tiny standalone examples we use `ld` directly. When we want to use C library functions like `printf`, we use **`gcc`** instead, which knows how to pull in the C runtime for us.
- **Platform: Linux on x86_64.** Specifically the System V AMD64 ABI — that's the long name for the agreed-upon rules about which register passes which argument when one piece of code calls another. We'll explain ABI in detail when it matters.
- **Debugger: `gdb`** (the GNU Debugger). A debugger lets you pause a running program, look at the cups (registers) and shelves (memory), and step forward one instruction at a time. We use `layout asm` (show the assembly code) and `layout regs` (show the registers) for the clearest view.

Every chapter has:

- A `README.md` — the story and the explanations.
- Usually one or more `.s` files — the actual assembly code you can run.
- A short **"Try it"** section — small experiments to type in and observe. **This is where the mental model actually forms.** Reading is not enough; you have to feel the instructions execute.

## The journey

| #   | Part                                                                 | What you learn                                                                                  |
| --- | -------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| 00  | [Introduction](00_Introduction/README.md)                            | Why assembly, what x86_64 is, the whole mental model in one picture                             |
| 01  | [Hello, CPU](01_Hello_CPU/README.md)                                 | Your very first program: print "Hello, CPU!" to the screen using nothing but the CPU and Linux  |
| 02  | [Registers](02_Registers/README.md)                                  | The 16 labeled cups on the counter, and how `rax`/`eax`/`ax`/`al` are the same cup at 4 widths  |
| 03  | [Moving Data](03_Moving_Data/README.md)                              | The `mov` instruction (which actually means *copy*), and how numbers grow or shrink between cups |
| 04  | [Arithmetic](04_Arithmetic/README.md)                                | Adding, subtracting, multiplying, dividing — and the little row of "yes/no lights" called FLAGS |
| 05  | [Bitwise & Shifts](05_Bitwise/README.md)                             | Working directly on individual on/off switches: `and`, `or`, `xor`, `not`, and shift tricks     |
| 06  | [Addressing & `lea`](06_Addressing/README.md)                        | How to point at any shelf in the warehouse with a formula, and why `lea` is really a calculator |
| 07  | [The Stack](07_The_Stack/README.md)                                  | A stack of plates the CPU uses for short-term storage: `push`, `pop`, and stack frames          |
| 08  | [Control Flow](08_Control_Flow/README.md)                            | Choose-your-own-adventure for code: comparing, jumping, and the conditional jump family          |
| 09  | [Loops](09_Loops/README.md)                                          | Building `for`, `while`, and `do-while` out of the basic jump instructions                       |
| 10  | [Functions & the ABI](10_Functions/README.md)                        | "Phoning a specialist" — how to call a function and return, and the rules about who passes what  |
| 11  | [Talking to C](11_Talking_To_C/README.md)                            | Calling `printf` from assembly, and being called *by* C — assembly and C as polite neighbors    |
| 12  | [Strings & Arrays](12_Strings_Arrays/README.md)                      | Rows of identical lockers (arrays), one-letter-per-locker words (strings), and the copy robot   |
| 13  | [Syscalls](13_Syscalls/README.md)                                    | Asking the building manager (the Linux kernel) for help directly, without the C library         |
| 14  | [A Tiny Program](14_Tiny_Program/README.md)                          | A complete little app: read a number from the keyboard, double it, print the answer             |
| 15  | [Where Next](15_Where_Next/README.md)                                | The edge of the map: SIMD, floats, gdb power tools, optimization, OS development                |

## How to actually read this

A few habits that will make the difference between "I sort of get it" and "I really get it":

1. **Read in order.** Each chapter assumes you've done the previous one. Skipping creates holes in the mental model that you'll trip over later.
2. **Type the examples by hand the first time.** Copy-paste produces zero learning. Typing forces your eyes and fingers to notice every comma, register name, and bracket.
3. **Run every "Try it" experiment.** They are tiny on purpose. The point isn't to write a big program; it's to *watch what the CPU actually does* in a controlled situation.
4. **After each chapter, close the page and try to write the smallest example from memory.** If you can't, go back. Assembly rewards repetition more than almost any other topic in programming — your eyes need to get used to the shape of it.
5. **Don't panic at unfamiliar words.** Every new term will be defined in plain English the first time it appears. If you forget what something means later, the chapter where it was introduced is just a click away.

There is no quiz, no time limit, and no shame in re-reading a chapter three times. The CPU has been there since 1978; it can wait.

## Ready?

Begin with **[Part 00 — Introduction](00_Introduction/README.md)**. We start with the big picture: what a CPU actually is, what x86_64 means, and the single diagram that the rest of this course will keep coming back to.
