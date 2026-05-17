# Topic 01 — Scalar Floating Point (`xmm` + `addsd`)

## A story: the second workshop

**In plain words:** everything you've learned so far — `rax`, `rdi`, `add`, `sub` — works on whole numbers only. The CPU keeps a *separate* workshop for fractional numbers like `3.14`, with its own benches and its own tools.

**The analogy.** Imagine the integer registers (`rax`..`r15`) are sixteen wooden workbenches on one side of the room, and there is a second room next door full of sixteen *bigger* workbenches called `xmm0`..`xmm15`. The big benches are 128 bits wide instead of 64. On those big benches you can do woodwork the small ones can't: handle fractional numbers, and — as we'll see in the next topic — work on several numbers at once.

For this topic we ignore the "several at once" trick and use the big bench like a small bench. One fractional number, one operation at a time. That's called **scalar** floating-point.

**The technical layer.** "Floating point" is the computer's encoding for fractional numbers (the IEEE-754 standard). A `double` is 8 bytes (64 bits), a `float` is 4 bytes (32 bits). Both fit comfortably inside the 16-byte `xmm0` register; the unused upper bits are simply ignored when you use the scalar instructions.

**Check yourself.** If `xmm0` is 128 bits wide and a `double` is 64 bits, how many doubles can you fit in one `xmm0`? (Answer: two. That's a teaser for the next topic.)

## What we will build

A program that loads two doubles from memory (`2.0` and `3.0`), adds them with `addsd`, converts the result to an integer, and uses that integer as its **exit status**. We'll read the exit status back from the shell with `echo $?`.

See [`01_scalar_fp.s`](01_scalar_fp.s):

```asm
.intel_syntax noprefix

        .section .rodata
        .align  8
two:    .double 2.0
three:  .double 3.0

        .section .text
        .globl  _start
_start:
        movsd   xmm0, [rip + two]       # xmm0 = 2.0
        movsd   xmm1, [rip + three]     # xmm1 = 3.0
        addsd   xmm0, xmm1              # xmm0 = 5.0
        cvttsd2si edi, xmm0             # rdi = (int)5.0 = 5

        mov     rax, 60                 # syscall: exit
        syscall
```

## Build and run

```bash
as -o 01_scalar_fp.o 01_scalar_fp.s
ld -o 01_scalar_fp 01_scalar_fp.o
./01_scalar_fp
echo $?
# => 5
```

If you see `5`, your CPU just did real fractional arithmetic in a register you'd never used before.

## Dissecting it

### `.double` and `.align 8`

**In plain words:** "put an 8-byte fractional number here, and make sure it sits on a round address."

**The technical layer.** `.double 2.0` is an assembler directive that lays down the 8 bytes of the IEEE-754 representation of `2.0` (which happens to be `0x4000000000000000`). `.align 8` tells the assembler "before placing the next thing, slide forward until the address is a multiple of 8." Most x86_64 chips happily do unaligned loads, but staying aligned is faster and is required by some SIMD instructions (you'll meet `movaps` in the next topic and it *will* crash on misaligned data).

**Gotcha.** `.float` lays down 4 bytes; `.double` lays down 8 bytes; they are **not** the same and the wrong one silently corrupts your data. The instruction suffix has to match: `addss` for 4-byte floats, `addsd` for 8-byte doubles.

### `movsd xmm0, [rip + two]`

**In plain words:** "fetch the 8-byte double at the address called `two` and put it into the bottom half of `xmm0`."

**The technical layer.** `movsd` is "**mov**e **s**calar **d**ouble." It moves exactly 8 bytes. The `[rip + two]` is the same RIP-relative addressing you saw in Part 01 — the assembler quietly turns `two` into "the offset from the current instruction to that label."

**Gotcha.** There is a *different* instruction also written `movsd` — the string-move opcode from Part 12 (`rep movsd` for "move string of doublewords"). The assembler picks which one based on the operands. If both operands are `xmm` or memory, it's the float version; if it has no operands, it's the string version. They share a name because of a 1980s decision nobody can undo.

### `addsd xmm0, xmm1`

**In plain words:** "`xmm0` = `xmm0` + `xmm1`, as doubles."

**The technical layer.** `addsd` reads the low 64 bits of each operand as IEEE-754 doubles, adds them following the IEEE rounding rules (round-to-nearest-even by default), and writes the result back to the low 64 bits of the destination. The upper 64 bits of the destination are left alone. The naming pattern is consistent: `mulsd`, `subsd`, `divsd`, `sqrtsd` all work the same way.

### `cvttsd2si edi, xmm0`

**In plain words:** "convert the double in `xmm0` to an integer, truncating, and put it in `edi`."

**The technical layer.** Read the mnemonic left-to-right: **c**on**v**er**t** with **t**runcation, **s**calar **d**ouble, to **s**igned **i**nteger. The doubled `t` (`cvttsd2si`, not `cvtsd2si`) is what specifies *truncate toward zero* rather than *round to nearest*. There is a separate instruction without the second `t` that rounds — pick the wrong one and `3.7` becomes `4` instead of `3` and a bug appears that takes a day to find.

**Why `edi`?** Because the Linux `exit` syscall takes its status in `rdi`, and writing to `edi` zero-extends into the full `rdi` (the same free zero-extension from Part 01). Exit statuses are only 8 bits anyway, so 32-bit-into-the-low-half is plenty.

**Gotcha.** A Linux exit status is **8 bits, unsigned**. If your math comes out to `256`, `echo $?` prints `0`. If it comes out negative, you get `256 + n`. Stay between `0` and `255` for sensible output.

### Floats in the System V calling convention

**In plain words:** when C code calls a function that takes a `double`, the double rides in `xmm0`, not `rdi`. The integer cups and the float cups are *separate counters*.

**The technical layer.** The first eight floating-point arguments to a C function are passed in `xmm0`..`xmm7`. The integer arguments still use `rdi, rsi, rdx, rcx, r8, r9`. A function returning a `double` returns it in `xmm0`. This is why a function with signature `double f(int a, double b, int c, double d)` puts `a` in `edi`, `b` in `xmm0`, `c` in `esi`, `d` in `xmm1` — the two queues advance independently.

There's also the `printf` quirk you may have seen mentioned: variadic functions like `printf` use `al` to record *how many* `xmm` registers were actually used so the receiver knows how much float state to save. That is why production `printf` call sites do `xor eax, eax` before the call when no floats are passed — they're declaring "zero `xmm` regs used."

## Try it

1. **Change `.double 3.0` to `.double 3.9`.** Rebuild, run, `echo $?`. You get `5`, not `6` — because `cvttsd2si` *truncates*.
2. **Change `addsd` to `mulsd`.** You get `6` (= 2 × 3).
3. **Change `addsd` to `subsd`.** You get… `255`. Because `2.0 - 3.0 = -1.0`, the exit status wraps to `256 + (-1) = 255`.
4. **Look at the bytes:** `objdump -d -M intel 01_scalar_fp`. Notice `addsd` decodes with the `f2 0f 58` prefix sequence — that's the family marker for "scalar double" SSE2 ops.

## What's next

You now have one fractional number on the big bench. In [Topic 02](02_simd_addps.md) we use the rest of the bench — *four* numbers side by side, one instruction, one cycle.
