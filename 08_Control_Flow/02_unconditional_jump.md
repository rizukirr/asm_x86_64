# 08.2 — Unconditional jump (`jmp`)

## A story: ripping out the bookmark

**In plain words:** normally the CPU reads instructions in order. `jmp` is the instruction that says "stop reading here, flip to that other page, and keep going from there."

**The analogy.** Picture the CPU as someone reading a recipe book with a bookmark. By default, after each step they slide the bookmark down one line. `jmp .target` is them pulling the bookmark out, walking it across the binder, and dropping it on the page labeled `.target`. They never glance at the pages they skipped over.

**The technical layer.** The "bookmark" is a real register called `RIP` (the **instruction pointer**) — it always holds the address of the next instruction to execute. `jmp .target` simply overwrites `RIP` with the address of `.target`. The CPU then continues normally from that new address.

```asm
jmp     .target         # RIP := address(.target)
```

No flags are checked. No flags are changed. It always happens.

**Check yourself.** What is the difference between `jmp` and `mov rip, ...`? (Answer: you cannot `mov` into `rip` directly on x86_64 — `RIP` is special. `jmp` is the *only* way to change it. The instruction even has multiple encodings: short jump if the target is nearby, near jump for further targets, plus indirect forms.)

## Labels

**In plain words:** a label is a sticky tab on a page. The assembler swaps the name for the page's address at build time.

```asm
.target:                # this line emits zero bytes; it's just a name
        mov     rax, 1
```

**The technical layer.**

- Labels written with a leading dot (`.target`, `.loop`, `.skip`) are **local** in GNU `as`. Local means the linker treats them as private to the current file/function. Two different files (or two different functions in the same file) can both have a label called `.loop` without colliding.
- Labels without a dot (`main`, `my_func`, `_start`) are **global** and can collide if you reuse the name.

**Gotcha.** Beginners often write `loop:` thinking it is local. It is global. Use `.loop:` for in-function labels.

## The whole demo

See [`02_unconditional_jump.s`](02_unconditional_jump.s):

```asm
.intel_syntax noprefix

        .section .data
good:   .ascii  "GOOD: jmp landed here\n"
        .equ    goodlen, . - good
bad:    .ascii  "BAD: should never print\n"
        .equ    badlen, . - bad

        .section .text
        .globl  _start
_start:
        jmp     .target         # always taken

        # --- this block is skipped over entirely ---
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + bad]
        mov     rdx, badlen
        syscall

.target:
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + good]
        mov     rdx, goodlen
        syscall

        mov     rax, 60
        xor     rdi, rdi
        syscall
```

**In plain words.** The very first instruction is `jmp .target`. The CPU rewrites its bookmark to the address of `.target` and continues from there. The "BAD" print block is sitting right there in memory, but the bookmark never visits it, so those bytes are never executed.

## Build and run

```bash
as -o 02_unconditional_jump.o 02_unconditional_jump.s
ld -o 02_unconditional_jump 02_unconditional_jump.o
./02_unconditional_jump
```

Expected output:

```
GOOD: jmp landed here
```

Notice we never see "BAD" — those bytes exist in the binary but were jumped over.

## Forms of `jmp`

You will eventually see three flavors:

| Form              | What it means                                                         |
| ----------------- | --------------------------------------------------------------------- |
| `jmp .label`      | **Direct**: jump to a known address baked into the instruction.       |
| `jmp rax`         | **Indirect through register**: jump to whatever address `rax` holds.  |
| `jmp [rax]`       | **Indirect through memory**: load an address from `[rax]`, jump there.|

Direct jumps are 99% of what you write. Indirect jumps are how things like function pointers, virtual method tables, and `switch` jump tables are implemented under the hood. We will not need them until [Part 10 — Functions](../10_Functions/README.md).

**Gotcha.** Indirect jumps are also the dangerous kind: if the value in `rax` is wrong, the CPU jumps to garbage and crashes (or worse, in a security context, jumps wherever an attacker wants). This is the seed of "return-oriented programming" attacks. Direct `jmp .label` is safe by comparison — the destination is fixed at build time.

## Short vs near encodings

**In plain words:** the assembler encodes `jmp` with a different number of bytes depending on how far the target is.

- **Short jump**: 2 bytes total — `EB <signed 8-bit offset>`. Works only when the target is within ±127 bytes.
- **Near jump**: 5 bytes total — `E9 <signed 32-bit offset>`. Works within ±2 GiB, which is "anywhere in your program" in practice.

You do not pick. The assembler picks for you. If you peek with `objdump -d -M intel ./02_unconditional_jump` you will see the actual encoded bytes.

```bash
objdump -d -M intel ./02_unconditional_jump
```

Look for the `jmp` line; depending on layout you will see something like:

```
4010??:  eb 1c                   jmp    40103e <.target>
```

The `eb` byte is the short-jump opcode, and `1c` is the offset (28 bytes forward).

## What's next

Unconditional jumps move the bookmark every time. To build `if`, `while`, and `for`, we need jumps that move the bookmark only when a flag says so. That is the **conditional jump** family — see [`03_conditional_jumps.md`](03_conditional_jumps.md).
