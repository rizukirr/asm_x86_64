# 12.3 — `rep movsb` and `rep stosb`: the tireless robot

## The picture first: a robot that walks both shelves at once

**In plain words:** the CPU has a built-in instruction that copies one byte from one shelf to another, takes one step forward on both shelves, and repeats — over and over — until a counter runs out. It's a one-line `memcpy`.

**The analogy.** Imagine a tireless little robot standing in front of two parallel rows of lockers. In its right hand, a pointer to "the locker I'm reading from." In its left hand, a pointer to "the locker I'm writing to." On its back, a counter showing how many more steps to take. Tell it "go," and it does this, forever, until the counter hits zero:

1. Read the byte from the right-hand locker.
2. Write that byte into the left-hand locker.
3. Step both hands forward one locker.
4. Subtract one from the counter.
5. If the counter is still positive, go back to step 1.

That robot is called `rep movsb`. The same robot, but holding a fixed letter in one hand instead of a second pointer, is `rep stosb` — "paint every locker with this letter."

## The implicit operands

**In plain words:** these instructions don't take operands the usual way. The CPU already knows which registers to use — they're baked in. You just have to set them up before saying the magic word.

| Register | Role with `movs`/`stos`                                |
| -------- | ------------------------------------------------------ |
| `rsi`    | **S**ource pointer (the right hand). Used by `movs`.   |
| `rdi`    | **D**estination pointer (the left hand). Used by both. |
| `rcx`    | The counter on the robot's back.                       |
| `al`     | For `stosb`: the byte to paint with.                   |
| `DF`     | Direction flag: 0 = walk forward, 1 = walk backward.   |

The trailing letter on the mnemonic is the step size: `b` = 1 byte, `w` = 2, `d` = 4, `q` = 8. So `rep movsb` copies one byte per step; `rep movsq` would copy eight bytes per step (faster, but only if the count is a multiple of 8 and the pointers are aligned).

**The direction flag.** `DF` is a one-bit switch inside the CPU's flags register. Two tiny instructions exist just to set it:

- `cld` — **cl**ear **d**irection. `DF = 0`. The robot walks forward (rsi and rdi increase).
- `std` — **s**e**t d**irection. `DF = 1`. The robot walks backward.

The System V calling convention requires `DF = 0` whenever you enter a function, so it's almost always already zero. We still write `cld` explicitly when it matters, the same way we wear a seatbelt even on short trips.

## `rep movsb` — copy a block

**In plain words:** load a source pointer into `rsi`, a destination pointer into `rdi`, a byte count into `rcx`, then say `rep movsb`, and the CPU does the whole copy in one instruction.

```asm
        cld
        lea     rsi, [rip + src]
        lea     rdi, [rip + dst]
        mov     rcx, srclen
        rep     movsb           # while (rcx--) *rdi++ = *rsi++
```

**The technical layer.** Pseudocode for `rep movsb`:

```
while (rcx != 0) {
    *rdi = *rsi;
    rsi += (DF ? -1 : +1);
    rdi += (DF ? -1 : +1);
    rcx -= 1;
}
```

That is `memcpy` in three preparation lines plus one execution line. On modern Intel and AMD CPUs the microcode for `rep movsb` is heavily tuned: for big copies it competes with hand-rolled SIMD; for tiny copies the compiler usually unrolls into plain `mov`s instead. Either way, when you read assembly in the wild and see `rep movsb`, mentally translate it to "memcpy."

**Gotcha.** `rep movsb` is *not safe* for overlapping regions where the destination is ahead of the source (because the robot would copy a byte forward, then re-read the byte it just wrote). That's `memmove`'s job — and `memmove` handles it by walking backward (`std` plus pointers at the end) when overlap requires it. For our worked example the buffers don't overlap, so plain forward `rep movsb` is fine.

## `rep stosb` — paint a block with one byte

**In plain words:** same robot, but it doesn't read from anywhere — it just stamps the byte sitting in `al` into every destination locker.

```asm
        cld
        lea     rdi, [rip + fill]
        mov     al, '*'
        mov     rcx, 7
        rep     stosb           # while (rcx--) *rdi++ = al
```

**The technical layer.** This is `memset` (set every byte of a memory region to one value). After this code runs, the seven bytes starting at `fill` all hold the ASCII value of `'*'`. The `b` variant uses `al`; `stosw` would use `ax`, `stosd` would use `eax`, `stosq` would use `rax`. Pick the size that matches the value you want to splat.

**Gotcha.** `stosb` reads `al`, not `rax`. If you want to splat the byte zero, `xor eax, eax` works (it zeros all of `rax`, so `al` is zero too). If you want to splat a non-zero byte, make sure you load just that byte into `al`; loading 0x2A into `eax` is fine but won't help if you accidentally typed `stosq`.

## The worked program

[`03_rep_movsb_stosb.s`](03_rep_movsb_stosb.s) demonstrates both: first it copies a literal string from `.data` into a `.bss` buffer with `rep movsb` and prints the destination, then it paints seven `'*'` bytes plus a newline into another buffer with `rep stosb` and prints that.

```asm
.intel_syntax noprefix

        .section .data
src:    .ascii  "copied with rep movsb\n"
        .equ    srclen, . - src

        .section .bss
dst:    .skip   64
fill:   .skip   8

        .section .text
        .globl  _start
_start:
        cld
        lea     rsi, [rip + src]
        lea     rdi, [rip + dst]
        mov     rcx, srclen
        rep     movsb

        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + dst]
        mov     rdx, srclen
        syscall

        cld
        lea     rdi, [rip + fill]
        mov     al, '*'
        mov     rcx, 7
        rep     stosb
        mov     byte ptr [rip + fill + 7], '\n'

        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + fill]
        mov     rdx, 8
        syscall

        mov     rax, 60
        xor     rdi, rdi
        syscall
```

**In plain words, step by step:**

1. Clear the direction flag so the robot walks forward.
2. Point `rsi` at the source string, `rdi` at the empty destination buffer, and load the count into `rcx`.
3. `rep movsb` does the copy.
4. After the copy, `rsi` and `rdi` have walked *past* the end of their buffers, and `rcx` is zero. That's normal — anybody who needs the original pointers should have saved them first.
5. Print the destination buffer (now containing the copied bytes) by handing its address back to the `write` syscall.
6. Set up `rdi` at the start of the second buffer, load `'*'` into `al`, set the count to seven, and `rep stosb` paints.
7. Manually drop a newline into the eighth byte of `fill`, then print all eight.

## Build and run

```bash
as -o /tmp/_t.o 03_rep_movsb_stosb.s
ld -o /tmp/_t /tmp/_t.o
/tmp/_t
```

Expected output (verbatim):

```
copied with rep movsb
*******
```

## Two cousins for searching and comparing

`movs` and `stos` are the bread and butter, but there are two more `rep`-able instructions worth knowing about (we'll use them sparingly):

| Instruction       | What the robot does on each step                                          |
| ----------------- | ------------------------------------------------------------------------- |
| `repe cmpsb`      | Compare `[rsi]` and `[rdi]`. Stop when they differ **or** `rcx` runs out. |
| `repne scasb`     | Compare `al` to `[rdi]`. Stop when they match **or** `rcx` runs out.      |

`repne scasb` with `al = 0` and `rcx = -1` is the classic asm `strlen`: scan the destination buffer until you trip over a NUL byte. We did the same job the hand-rolled way in topic 1; the `rep`-prefixed version is one line, but harder to read for beginners, which is why we kept the manual scan there.

**The technical layer.** `repe` / `repne` extend the basic `rep` rule with the zero flag: the loop also stops as soon as the comparison's result disagrees with the prefix.

- `repe` (also spelled `repz`): keep going while `rcx > 0` **and** `ZF == 1` (still equal).
- `repne` (also spelled `repnz`): keep going while `rcx > 0` **and** `ZF == 0` (still not equal).

That matches "search until found" and "compare until different" exactly.

## Try it

1. Change `srclen` to a smaller number (say, 6) before `rep movsb` and rerun. You'll see only the first six characters printed — the robot did fewer steps.
2. Replace `rep movsb` with a hand-written `mov` loop (read a byte, store a byte, increment both pointers, decrement counter, loop). Confirm you get identical output. Now you know what `rep movsb` is shorthand for.
3. Use `rep stosb` to zero a 64-byte buffer in `.bss` before using it. (Yes — `.bss` is already zero at program start, so this is redundant. Do it anyway for the practice. Real programs zero buffers between reuses.)

## Next

We've leaned on the `write` and `exit` syscalls in every chapter so far without really opening them up. [Part 13](../13_Syscalls/README.md) takes a proper look at the Linux syscall mechanism — the full table of arguments, the return-value convention, errors, and when you'd want to bypass libc entirely.
