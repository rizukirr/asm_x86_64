# 03 — Two special cups: rip and rflags

## A story: the chef's bookmark and the chef's mood

**In plain words:** beyond the 16 general-purpose cups, the CPU has two cups you don't usually touch by name but that drive everything: `rip` (where the chef is in the recipe) and `rflags` (how the last action turned out).

**The analogy.** Imagine the chef has, off to the side of the counter, two small objects:

- A **bookmark** on the open recipe book, pointing at the *next* line they're going to read. The chef doesn't move the bookmark by hand — it shifts forward by itself after each step. The only way to "jump" to a different line is to take a special action (turn to page 47, repeat the loop, etc.).
- A small **mood ring** that changes color depending on the last thing they did. If the last step came out to exactly zero portions, one bead lights up. If the last step overflowed the mixing bowl, another bead lights up. The chef checks the ring after a step to decide what to do next.

The bookmark is `rip` — the **instruction pointer**. The mood ring is `rflags` — the **status flags**.

## `rip` — the instruction pointer

**In plain words:** `rip` always holds the address of the *next* instruction to execute. It moves itself.

**The technical layer.** Every time the CPU finishes one instruction, it adds that instruction's length to `rip` so it points at the next one. You cannot say `mov rip, X` — the CPU refuses. The only ways to change `rip` are:

- `jmp label` — unconditional jump. "Set the bookmark to that page."
- `jz label`, `jnz label`, `je label`, etc. — conditional jumps. "If the mood ring is glowing zero, jump."
- `call label` — like `jmp`, but also saves the current `rip` so you can come back later.
- `ret` — pops a saved `rip` and goes back.
- `syscall` — hands control to the kernel; when the kernel returns, `rip` resumes at the instruction after `syscall`.

**Bonus use: RIP-relative addressing.** You've already seen this:

```asm
lea     rsi, [rip + msg]
```

That `[rip + msg]` means "the address of `msg`, expressed as how far away it is from the current instruction pointer." It's the modern, position-independent way to refer to a label — it works no matter where the operating system loads your program. We cover addressing modes in depth in [Part 06](../06_Addressing/README.md).

## `rflags` — the status cup

**In plain words:** after most math or logic instructions, certain bits in `rflags` automatically light up to record what just happened.

**The technical layer.** `rflags` is 64 bits wide, but only a handful of bits matter day-to-day:

| Bit | Name | Lights up when                                                |
| --- | ---- | ------------------------------------------------------------- |
| ZF  | Zero Flag | The result was exactly zero                              |
| SF  | Sign Flag | The result was negative (top bit = 1)                    |
| CF  | Carry Flag | Unsigned math overflowed past the top                   |
| OF  | Overflow Flag | Signed math wrapped around (e.g., +127 + 1 → -128)  |
| PF  | Parity Flag | The low byte has an even number of 1 bits (rare)      |

You almost never read `rflags` directly. Instead, instructions like `jz`, `jnz`, `jg`, `jl`, `setz`, `cmovz` look at these bits *for* you. We dive into the full flag-and-jump dance in [Part 08](../08_Control_Flow/README.md).

**Gotcha.** Not every instruction touches the flags. `mov` does **not** — copying a number does not change the mood ring. `add`, `sub`, `xor`, `cmp`, `test`, `and`, `or`, etc. all do.

## The code

See [`03_rip_and_rflags.s`](03_rip_and_rflags.s):

```asm
.intel_syntax noprefix

        .section .data
zmsg:   .ascii  "ZF was set: result was zero\n"
        .equ    zlen, . - zmsg
nmsg:   .ascii  "ZF was clear: result was nonzero\n"
        .equ    nlen, . - nmsg

        .section .text
        .globl  _start
_start:
        mov     rax, 7
        sub     rax, 7                  # rax = 0, ZF = 1
        jz      print_zero

        lea     rsi, [rip + nmsg]
        mov     rdx, nlen
        jmp     do_print

print_zero:
        lea     rsi, [rip + zmsg]
        mov     rdx, zlen

do_print:
        mov     rax, 1
        mov     rdi, 1
        syscall

        mov     rax, 60
        xor     rdi, rdi
        syscall
```

**In plain words.** We put 7 in `rax`, then subtract 7 from it. The result is 0, so the CPU lights up the ZF bead in the mood ring. The `jz` ("jump if zero") instruction looks at that bead and jumps to `print_zero`. We pick the matching message and print it.

If you change `sub rax, 7` to `sub rax, 6`, the result is 1, ZF stays clear, and the program prints the other message instead. Try it.

## Build and run

```bash
as -o 03_rip_and_rflags.o 03_rip_and_rflags.s
ld -o 03_rip_and_rflags 03_rip_and_rflags.o
./03_rip_and_rflags
# => ZF was set: result was zero
```

## Watch it with gdb

```bash
gdb ./03_rip_and_rflags
(gdb) layout regs
(gdb) starti
(gdb) si
```

Two things to watch:

1. **`rip` increments by itself** after every `si`. You never wrote to it; it walks forward on its own.
2. **`eflags`** in the register pane changes after `sub rax, 7`. Look for the `Z` flag (zero) appearing. After the conditional jump, `rip` jumps to a non-adjacent address — that's `jz` consulting ZF and rewriting `rip` for you.

## Check yourself

After `mov rax, 0`, is ZF set? (Answer: **no**. `mov` doesn't touch flags. To set ZF based on a register being zero, use `test rax, rax` or `cmp rax, 0` — both of those *do* update flags without changing `rax`.)

## What's next

You've now met every register family on x86_64: the 16 GPRs and their width views, plus `rip` and `rflags`. The next chapter zooms in on the instruction that moves more data than any other — `mov` — in all its variations.

Onward to [Part 03](../03_Moving_Data/README.md).
