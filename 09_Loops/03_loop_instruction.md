# 09.3 — The `loop` Instruction (a Beautiful Trap)

## A story: the kitchen gadget that looks great in the catalog

**In plain words:** x86 has a single instruction called `loop` that does decrement-and-jump in one go. It looks like the perfect counted-loop primitive. It is not. Modern CPUs run it *slower* than the two-instruction equivalent.

**The analogy.** Imagine a kitchen-store catalog from 1985. There's a gleaming gadget called the "Salad-O-Matic 3000" that chops, slices, dices, and washes lettuce in one machine. It looks revolutionary. You buy it, get it home, and discover that it's slower and clumsier than just using a knife. But the catalog still sells it because *some* old kitchens (and some old recipes) call for it by name. So the manufacturer keeps making it, but no chef ever uses one.

**The technical layer.** `loop` is exactly that gadget. Intel introduced it in the 8086 (1978) as a one-byte way to express "do a counted loop." But starting with the Pentium 4 (2000), it was **microcoded slowly** — implemented inside the CPU as a small program rather than as a fast hardwired path. The two-instruction sequence `dec rcx ; jnz target` runs faster on every modern x86 chip. Compilers stopped emitting `loop` in the 1990s.

**Check yourself.** If `loop` is slower, why does it still exist? (Answer: backwards compatibility. Programs from the DOS era — and even some bootloaders — use `loop`. Removing it would break decades of binaries. The instruction set is a museum as well as a toolbox.)

## What `loop` actually does

**In plain words:** `loop target` decrements `rcx` and jumps to `target` if the result is not zero. All in one instruction.

**The technical layer.** Pseudo-code:

```text
loop target:
    rcx = rcx - 1
    if rcx != 0:
        rip = target
```

A few hard-coded restrictions:

- It **always** uses `rcx` as the counter. You don't get to pick.
- It **does not** set FLAGS. Unlike `dec`, `loop`'s decrement is invisible to ZF/SF/etc. That makes it awkward to compose with other conditional jumps.
- The jump offset is a single signed byte: the target must be within −128..+127 bytes. Too far away and the assembler refuses.

There are two siblings:

- `loope target` / `loopz target` — loop while `rcx != 0` **and** ZF = 1.
- `loopne target` / `loopnz target` — loop while `rcx != 0` **and** ZF = 0.

Same speed problem. Same disuse.

## The program

We print `ABCDE` using `loop` instead of `dec`/`jnz`. See [`03_loop_instruction.s`](03_loop_instruction.s):

```asm
.intel_syntax noprefix

        .section .data
digit:  .byte   'A'
nl:     .byte   '\n'

        .section .text
        .globl  _start
_start:
        mov     rcx, 5                  # `loop` always uses rcx
        mov     bl, 'A'

.body:
        lea     rsi, [rip + digit]
        mov     [rsi], bl

        # Save rcx across the syscall; the kernel clobbers rcx and r11.
        push    rcx
        mov     rax, 1
        mov     rdi, 1
        mov     rdx, 1
        syscall
        pop     rcx

        inc     bl
        loop    .body                   # rcx-- ; if rcx != 0 jump .body

        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + nl]
        mov     rdx, 1
        syscall

        mov     rax, 60
        xor     rdi, rdi
        syscall
```

## Build and run

```bash
as -o 03.o 03_loop_instruction.s
ld -o 03 03.o
./03
# => ABCDE
```

## Dissecting it

### Why `push rcx` / `pop rcx`?

**In plain words:** the kernel scrambles `rcx` on every `syscall`. `loop` *requires* its counter in `rcx`. So we save and restore.

**The technical layer.** `push rcx` decrements `rsp` by 8 and writes `rcx` to the new top of the stack. `pop rcx` does the reverse. It's the cheapest, most universal "preserve this register across a noisy call" trick on x86_64. (In the previous file, we sidestepped the problem by using `r12` instead — but `loop` doesn't give us that choice.)

**Gotcha.** You must `pop` exactly once for every `push`. An imbalance — say, an early `jmp` that skips a `pop` — leaves the stack misaligned and the next `ret` or `syscall` does something terrifying.

### Why is `loop` slow on modern CPUs?

**In plain words:** fast x86 instructions are decoded directly into the CPU's internal ops. Slower ones get expanded by an internal interpreter called the **microcode engine**, which takes extra cycles. `loop` ended up on the microcode side.

**The technical layer.** On most Intel chips from Pentium 4 onward, `loop` decodes to multiple internal micro-ops with extra latency compared to `dec rcx ; jne target`. On Skylake and later, the gap shrank but didn't vanish; on some AMD chips `loop` is actually fine. The point is **the assumption it's faster because it's one instruction is wrong**, and the variance across microarchitectures means you should never rely on it for performance. (Reference: Agner Fog's instruction tables.)

### Disassembling the program

```bash
objdump -d -M intel 03 | grep -A1 loop
```

You'll see `e2 ??` — the two-byte encoding of `loop` (opcode `0xE2`, followed by a signed one-byte displacement). Tiny and tempting. Still slow.

## When `loop` *is* fine

**In plain words:** if you are writing assembly for size, not speed — like a hand-shrunk bootloader, an obfuscated demo, or a code-golf entry — `loop` saves bytes. Otherwise: don't.

**The technical layer.** Real-world places `loop` still shows up:

- 16-bit bootloaders that must fit in 512 bytes.
- The hand-written assembly inside some retro game engines.
- Some teaching examples that prioritize readability over speed.

In production code from this millennium, `loop` is a smell.

## Try it

1. Rewrite the program with `dec rcx ; jnz .body` (and keep the `push`/`pop` so the comparison is fair). Disassemble both and compare the byte counts.
2. Try removing the `push rcx` / `pop rcx` pair. Watch the program spray a flood of garbage bytes — you've just trained a permanent reflex about syscall-clobbered registers.
3. Read about `jrcxz` (jump if `rcx` is zero) and `jecxz` (jump if `ecx` is zero) — they're cousins of `loop`, also slow, also pretty-looking. Do not use them.

## What's next

We have one-counter loops in three shapes plus the legacy `loop` instruction. Next: **nested loops** and **iterating over arrays** with indexed addressing — that's where loops earn their keep. → [04_nested_and_arrays.md](04_nested_and_arrays.md)
