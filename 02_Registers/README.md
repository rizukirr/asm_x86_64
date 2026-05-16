# Part 02 — Registers

## A story: cups on a chef's counter

Imagine a chef working in a tiny kitchen.

On the chef's counter, right in front of them, are 16 labeled cups. The chef can grab from any cup or drop something into any cup in a blink — no walking, no reaching, no thinking. The cups are *that* close.

Far away, in the back room, is a giant pantry with millions of shelves. The pantry has way more storage, but the chef has to walk all the way back, find the right shelf, and walk back to the counter to use anything from it. Slow.

So what does the chef do? Most cooking happens at the cups. You bring ingredients from the pantry to the cups, you do all the chopping and mixing at the cups, and only then do you walk back and put the finished food onto a pantry shelf.

The cups are **registers**. The pantry is **memory** (RAM). And in x86_64, the chef has **16 cups**.

Registers are the CPU's hands. They are tiny, fast storage cells **inside** the CPU itself. Reading one takes a single **cycle** (one tick of the CPU's clock, less than a billionth of a second). Reading from main memory takes hundreds of cycles — sometimes thousands if the data is far away. Almost every CPU instruction works on registers; the few that touch memory mostly exist to move data **into** registers so the next instruction can work on it.

x86_64 gives you **16 general-purpose registers** (GPRs — "general-purpose" means you can use them for almost anything, unlike specialized registers that only one instruction cares about), each **64 bits** wide. "64 bits wide" means each cup can hold a number with up to 64 binary digits — that's any whole number from 0 up to about 18 quintillion. Plenty of room.

## The sixteen GPRs

Here's the full list of cups. Don't try to memorize this table — refer back to it as you go.

| 64-bit | 32-bit | 16-bit | 8-bit low | 8-bit high* | Historical role / convention                |
| ------ | ------ | ------ | --------- | ----------- | ------------------------------------------- |
| `rax`  | `eax`  | `ax`   | `al`      | `ah`        | **A**ccumulator — return value, `mul`/`div` |
| `rbx`  | `ebx`  | `bx`   | `bl`      | `bh`        | **B**ase — callee-saved scratch             |
| `rcx`  | `ecx`  | `cx`   | `cl`      | `ch`        | **C**ounter — shifts use `cl`; 4th C arg    |
| `rdx`  | `edx`  | `dx`   | `dl`      | `dh`        | **D**ata — `mul`/`div` high half; 3rd C arg |
| `rsi`  | `esi`  | `si`   | `sil`     | —           | **S**ource **I**ndex — 2nd C arg            |
| `rdi`  | `edi`  | `di`   | `dil`     | —           | **D**estination **I**ndex — 1st C arg       |
| `rbp`  | `ebp`  | `bp`   | `bpl`     | —           | **B**ase **P**ointer — frame pointer        |
| `rsp`  | `esp`  | `sp`   | `spl`     | —           | **S**tack **P**ointer — *do not clobber*    |
| `r8`   | `r8d`  | `r8w`  | `r8b`     | —           | 5th C arg                                   |
| `r9`   | `r9d`  | `r9w`  | `r9b`     | —           | 6th C arg                                   |
| `r10`  | `r10d` | `r10w` | `r10b`    | —           | Scratch (4th *syscall* arg)                 |
| `r11`  | `r11d` | `r11w` | `r11b`    | —           | Scratch                                     |
| `r12`  | `r12d` | `r12w` | `r12b`    | —           | Callee-saved                                |
| `r13`  | `r13d` | `r13w` | `r13b`    | —           | Callee-saved                                |
| `r14`  | `r14d` | `r14w` | `r14b`    | —           | Callee-saved                                |
| `r15`  | `r15d` | `r15w` | `r15b`    | —           | Callee-saved                                |

A few unfamiliar words in that table, explained in plain English:

- **"Callee-saved"** means: if you're writing a function that uses this register, you must put back whatever was in it before you return. Like borrowing a cup — wash it and return it. The opposite is **"scratch"** (or "caller-saved"), which means: feel free to scribble in it; whoever called you knew that and saved their own stuff first.
- **"C arg"** refers to the **calling convention** — the agreement about which cups hold which arguments when one function calls another. We'll cover this in detail in a later chapter.
- **`mul`/`div`** are multiply and divide instructions, covered in Part 04.

\* The `ah`/`bh`/`ch`/`dh` "high byte" registers exist only for `rax`–`rdx`, and *cannot* be used in the same instruction as `r8`–`r15` or the newer 8-bit names. You'll basically never need them — they're a leftover from older CPUs.

Plus two specials (cups you don't usually touch directly):

- **`rip`** — the **instruction pointer**, the cup that always holds "address of the next instruction to run." You can't `mov` to it directly; you change it indirectly with jumps and calls.
- **`rflags`** — the **status flags** cup. After almost every math or logic instruction, certain bits in this cup automatically light up to record what happened: CF (carry — did the math overflow past the top?), ZF (zero — was the result zero?), SF (sign — was the result negative?), OF (overflow — did a signed calculation wrap around?), and others. We come back to this in [Part 04](../04_Arithmetic/README.md) and [Part 08](../08_Control_Flow/README.md).

## "Same register, different widths"

This is the single most important picture for x86_64. `rax`, `eax`, `ax`, `ah`, `al` are **not five separate registers**. They are five **views** of the same 64-bit storage cell — like looking at a single ruler and choosing to read just the inch marks, or just the centimeter marks, or just the millimeter marks. Same ruler.

```
 63                              31              15      7       0
 +-------------------------------+---------------+-------+-------+
 |                       rax (64 bits)                          |
 +-------------------------------+---------------+-------+-------+
                                 |          eax (32 bits)        |
                                 +---------------+-------+-------+
                                                 |   ax (16)     |
                                                 +-------+-------+
                                                 |  ah   |  al   |
                                                 +-------+-------+
```

Reading the picture top-down:
- `rax` is the whole 64-bit cup.
- `eax` is just the bottom 32 bits of that same cup.
- `ax` is just the bottom 16 bits.
- `al` is just the bottom 8 bits (the very low byte).
- `ah` is the *second-lowest* byte (bits 8–15).

So `mov al, 0xFF` writes one byte into the bottom 8 bits of `rax` and leaves the rest alone. `mov ax, 0xFFFF` writes two bytes and leaves the top 48 alone. But — and this is the big surprise — **`mov eax, 0xFFFFFFFF` zeroes the top 32 bits** of `rax`. Even though you only "wrote to `eax`," the CPU silently wipes the upper half of `rax` to zero.

That last rule is a 64-bit-only quirk and absolutely worth memorizing:

> **Writing to a 32-bit register zero-extends into the full 64-bit register.**

("Zero-extends" means: fill the extra bits with zeros.) This is why compilers love `xor eax, eax` to zero out `rax` — it's only two bytes long and zeroes all 64 bits in one shot.

## Why so many names?

Two reasons:

1. **History.** The Intel 8086 chip in 1978 had 16-bit registers named `ax bx cx dx`. The 80386 in 1985 extended them to 32 bits and called the new versions `eax ebx ecx edx` (the "E" stood for "Extended"). AMD64 in 2003 extended them again to 64 bits as `rax` etc. (the "R" for "Register," sort of) and added 8 brand new ones: `r8`–`r15`. Each generation kept the old names usable so old code still assembled. You are essentially working inside a 50-year-old archaeology site where every layer of history is still visible and still functional.
2. **Specialization.** A handful of instructions are hardwired to specific cups. The `mul`/`div` (multiply/divide) instructions implicitly use the pair `rdx:rax`. Shift counts have to come from `cl`. String instructions automatically use `rsi`/`rdi`. The C calling convention picks `rdi rsi rdx rcx r8 r9` for the first six function arguments. You'll see these patterns over and over.

## A picture-only exercise

Predict what each line leaves in `rax`, starting from `rax = 0x1122334455667788` (that's a 64-bit number written in hexadecimal — each hex digit represents 4 bits, so 16 hex digits = 64 bits).

```asm
mov     al, 0xAA
mov     ax, 0xBBCC
mov     eax, 0xDDEEFF00
```

Answer:

| After                     | `rax`                |
| ------------------------- | -------------------- |
| `mov al,  0xAA`           | `0x11223344556677AA` |
| `mov ax,  0xBBCC`         | `0x112233445566BBCC` |
| `mov eax, 0xDDEEFF00`     | `0x00000000DDEEFF00` |

Walkthrough of each line:
- `mov al, 0xAA` — only the bottom 8 bits change. The original `88` becomes `AA`; everything else (`1122334455667788` → `11223344556677AA`) stays.
- `mov ax, 0xBBCC` — only the bottom 16 bits change. `77AA` becomes `BBCC`.
- `mov eax, 0xDDEEFF00` — writing to a 32-bit register **wipes the top 32 bits to zero**. So `11223344` (the top half) becomes `00000000`, and the bottom half becomes the new value. This is the rule that catches everyone.

If that last one surprised you, re-read the rule above.

## Try it (gdb)

Save this as `regs.s`:

```asm
.intel_syntax noprefix
        .globl  _start
_start:
        mov     rax, 0x1122334455667788
        mov     al,  0xAA
        mov     ax,  0xBBCC
        mov     eax, 0xDDEEFF00
        mov     rax, 60
        xor     rdi, rdi
        syscall
```

**What this actually does, in plain words:** stuff a big test number into `rax`, then poke at different "views" of it one byte / two bytes / four bytes at a time, then finally do the standard "exit cleanly" syscall (form 60, status 0).

Build and step through it:

```bash
as -o regs.o regs.s && ld -o regs regs.o
gdb ./regs
(gdb) layout regs
(gdb) starti
(gdb) si                    # step one instruction at a time
```

`gdb` is the **debugger** — a tool that lets you pause your program at any instruction and peek at every cup. `layout regs` opens a side panel showing all the registers. `starti` means "start the program but pause it *before* the very first instruction." `si` means "step one instruction" — run exactly one instruction and pause again. Hit `si` over and over to walk through your program one instruction at a time.

Watch `rax` change in the register pane. You are now the CPU.

## What's next

We have a workbench. In [Part 03](../03_Moving_Data/README.md) we look at the instruction that does most of the work: `mov`, in all its variations — register, immediate, memory, sign-extension, zero-extension.
