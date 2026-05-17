# 01 — Sixteen cups on the counter

## A story: a chef with sixteen cups

**In plain words:** the CPU has a tiny set of super-fast slots called registers. Almost every instruction works on them. There are exactly 16 of them on x86_64.

**The analogy.** Picture a chef in a tiny kitchen. On the counter, right in front of them, are 16 labeled cups. The chef can grab from any cup or drop something into any cup in a blink — no walking, no reaching. Far away, in the back room, is a giant pantry with millions of shelves. The pantry stores way more, but reaching it means walking.

So what does the chef do? They bring ingredients from the pantry to the cups, do all the chopping at the cups, and only then walk back and put the finished food on a pantry shelf.

The cups are **registers**. The pantry is **memory** (RAM).

**The technical layer.** A register is a storage cell built **inside** the CPU itself. Reading one takes a single **cycle** — one tick of the CPU's clock, less than a billionth of a second. Reading from main memory takes hundreds of cycles. That speed gap is why every program spends most of its life shuffling data through registers.

x86_64 gives you **16 general-purpose registers** (GPRs), each **64 bits** wide. "General-purpose" means you can use them for almost anything. "64 bits wide" means each cup can hold any whole number from 0 up to about 18 quintillion. Plenty of room.

## The full roster

Don't memorize this table. Refer back to it whenever you forget what a name means.

| 64-bit | Historical role / convention                |
| ------ | ------------------------------------------- |
| `rax`  | **A**ccumulator — return value, `mul`/`div` |
| `rbx`  | **B**ase — callee-saved scratch             |
| `rcx`  | **C**ounter — shifts use `cl`; 4th C arg    |
| `rdx`  | **D**ata — `mul`/`div` high half; 3rd C arg |
| `rsi`  | **S**ource **I**ndex — 2nd C arg            |
| `rdi`  | **D**estination **I**ndex — 1st C arg       |
| `rbp`  | **B**ase **P**ointer — frame pointer        |
| `rsp`  | **S**tack **P**ointer — *do not clobber*    |
| `r8`   | 5th C arg                                   |
| `r9`   | 6th C arg                                   |
| `r10`  | Scratch (4th *syscall* arg)                 |
| `r11`  | Scratch                                     |
| `r12`  | Callee-saved                                |
| `r13`  | Callee-saved                                |
| `r14`  | Callee-saved                                |
| `r15`  | Callee-saved                                |

A few unfamiliar words explained:

- **Callee-saved** means: if your function uses this cup, you must restore it before returning. Like borrowing a cup — wash it and return it.
- **Scratch** (also called **caller-saved**) means: feel free to scribble in it; whoever called you knew that and saved their own stuff first.
- **C arg** refers to the **calling convention** — the agreement about which cups hold which arguments when one function calls another. Full coverage in a later chapter.
- **`mul`/`div`** are multiply and divide instructions, covered in Part 04.

**Gotcha.** `rsp` (the stack pointer) is technically a GPR, but in practice you never use it for arbitrary data. The CPU and the operating system both assume it points to a valid stack. If you scramble it, your program dies in confusing ways.

## Why so many names?

Two reasons:

1. **History.** The Intel 8086 chip in 1978 had 16-bit registers named `ax bx cx dx`. The 80386 in 1985 extended them to 32 bits as `eax ebx ecx edx` (the "E" stood for "Extended"). AMD64 in 2003 extended them again to 64 bits as `rax` etc. and added 8 brand new ones: `r8`–`r15`. Each generation kept the old names usable so old code still assembled. You are working inside a 50-year-old archaeology site where every layer is still functional.
2. **Specialization.** A handful of instructions are hardwired to specific cups. `mul`/`div` implicitly use `rdx:rax`. Shift counts must come from `cl`. String instructions use `rsi`/`rdi`. The C calling convention picks `rdi rsi rdx rcx r8 r9` for the first six function arguments. You'll see these patterns over and over.

## The code

See [`01_sixteen_cups.s`](01_sixteen_cups.s):

```asm
.intel_syntax noprefix

        .section .data
msg:    .ascii  "16 cups on the counter\n"
        .equ    msglen, . - msg

        .section .text
        .globl  _start
_start:
        mov     rbx, 2
        mov     rcx, 3
        mov     r8,  8
        mov     r9,  9
        mov     r12, 12
        mov     r15, 15

        mov     rax, 1                  # write
        mov     rdi, 1                  # stdout
        lea     rsi, [rip + msg]
        mov     rdx, msglen
        syscall

        mov     rax, 60                 # exit
        xor     rdi, rdi
        syscall
```

**In plain words.** We poke small numbers into a few cups just to show we can — `rbx`, `rcx`, `r8`, `r9`, `r12`, `r15`. Then we use the four syscall cups (`rax`, `rdi`, `rsi`, `rdx`) to print a line, and exit cleanly.

## Build and run

```bash
as -o 01_sixteen_cups.o 01_sixteen_cups.s
ld -o 01_sixteen_cups 01_sixteen_cups.o
./01_sixteen_cups
# => 16 cups on the counter
```

## Watch it with gdb

The print is fine but the real lesson is *seeing* every cup change.

```bash
gdb ./01_sixteen_cups
(gdb) layout regs
(gdb) starti
(gdb) si
```

`gdb` is the **debugger** — a tool that pauses your program at any instruction and shows every cup. `layout regs` opens a side panel of registers. `starti` starts the program but pauses *before* the very first instruction. `si` steps exactly one instruction. Hit `si` over and over and watch `rbx`, `rcx`, `r8`, `r9`, `r12`, `r15` light up one by one.

## Check yourself

If a function you write uses `r12` for a loop counter, do you need to save and restore it? (Answer: yes — `r12` is callee-saved. If you didn't restore it, your caller would find their `r12` mysteriously changed. The opposite is true for `r10`/`r11`: they're scratch, so you can stomp on them freely.)

## What's next

You've met the 16 cups. Next: the same cup can be looked at as 64, 32, 16, or 8 bits — and one of those views has a surprising side effect. See [`02_register_widths.md`](02_register_widths.md).
