# Topic 02 — SIMD: Four Adds in One Instruction (`addps`)

## A story: the four-handed carpenter

**In plain words:** instead of adding one pair of numbers at a time, the CPU can add *four* pairs in a single instruction. Same time, four times the work.

**The analogy.** Picture a carpenter with one hammer, hammering one nail per second. Now picture a carpenter with a special jig that holds four hammers side by side; one swing drives four nails at once. The big jig is no slower than one hammer — every swing just does more. That jig is **SIMD**: *Single Instruction, Multiple Data*. One instruction, multiple numbers processed in parallel.

**The technical layer.** An `xmm` register is 128 bits wide. A `float` is 32 bits. So one `xmm` register holds **four floats laid end to end** — call them lane 0, lane 1, lane 2, lane 3. SIMD instructions like `addps` ("**add** **p**acked **s**ingle") take two such registers and add lane-0 to lane-0, lane-1 to lane-1, and so on, all in one shot. This is how image filters, audio mixers, neural networks, and game physics get their speed.

**Check yourself.** A 128-bit register holds 4 floats; how many doubles? (Answer: 2 — and the packed-double instruction is `addpd`.) How many 16-bit integers? (Answer: 8 — and there's a `paddw` for that.) The pattern keeps going.

## What we will build

A program that defines two arrays of four floats in memory, loads them both into `xmm` registers, adds them in **one** instruction, and uses the first lane of the result (`1.0 + 10.0 = 11.0`) as the exit status.

See [`02_simd_addps.s`](02_simd_addps.s):

```asm
.intel_syntax noprefix

        .section .rodata
        .align  16
a:      .float  1.0, 2.0, 3.0, 4.0
b:      .float  10.0, 20.0, 30.0, 40.0

        .section .text
        .globl  _start
_start:
        movaps  xmm0, [rip + a]         # load 4 floats:  1, 2, 3, 4
        movaps  xmm1, [rip + b]         # load 4 floats: 10,20,30,40
        addps   xmm0, xmm1              # parallel add: 11,22,33,44

        # take lane 0 (= 11.0) and use it as the exit code.
        cvttss2si edi, xmm0             # rdi = (int)11.0 = 11

        mov     rax, 60                 # syscall: exit
        syscall
```

## Build and run

```bash
as -o 02_simd_addps.o 02_simd_addps.s
ld -o 02_simd_addps 02_simd_addps.o
./02_simd_addps
echo $?
# => 11
```

If you see `11`, you just performed four floating-point additions in one CPU instruction.

## Dissecting it

### `.align 16` — and why it really matters now

**In plain words:** "before placing the next thing, slide forward until the address ends in a `0x0` nibble."

**The technical layer.** `movaps` is **move aligned packed single** — the "aligned" part is not a suggestion. If the address is not a multiple of 16, the CPU raises a `#GP` general-protection fault and the kernel kills your program with `SIGSEGV`. We use `.align 16` to make absolutely sure the array starts on a 16-byte boundary.

**Gotcha.** Forget `.align 16` and the program *might* still work — it depends on what the assembler happens to place before `a:`. That's the worst kind of bug: works on your machine, crashes on someone else's. The cure is `movups` (the "unaligned" variant), which is one byte different in encoding and works at any address. On modern CPUs the speed difference is tiny; on old CPUs it was significant. Many people just use `movups` everywhere now and stop worrying.

### `.float 1.0, 2.0, 3.0, 4.0`

**In plain words:** "lay down sixteen bytes here — four IEEE-754 single-precision floats in a row."

**The technical layer.** Each `.float` is 4 bytes. The four values are placed contiguously in memory, **little-endian** within each float but lane-0-first across the array. So when you load with `movaps`, the byte at `[a]` becomes the low 32 bits of `xmm0` (= lane 0), the next 4 bytes become lane 1, and so on.

### `addps xmm0, xmm1`

**In plain words:** "for each of the four lanes, add the matching lane of `xmm1` into `xmm0`."

**The technical layer.** Four IEEE-754 single-precision additions happen in parallel — independently, with separate rounding for each — and the four results go back into `xmm0`. There are no flags raised in `rflags`; if you care about overflow or NaN you check the dedicated `MXCSR` status register, but most code doesn't bother.

| Mnemonic | Operation                       | Element type    |
| -------- | ------------------------------- | --------------- |
| `addss`  | scalar single (1 float)         | one `float`     |
| `addsd`  | scalar double (1 double)        | one `double`    |
| `addps`  | packed single (4 floats)        | four `float`s   |
| `addpd`  | packed double (2 doubles)       | two `double`s   |

Read the suffix as "**s**calar/**p**acked" + "**s**ingle/**d**ouble" and most of the float-instruction vocabulary suddenly makes sense.

### `cvttss2si edi, xmm0`

**In plain words:** "convert lane 0 of `xmm0` (a single float) to a signed integer, truncate, put it in `edi`."

**The technical layer.** Just like `cvttsd2si` from the last topic, but the `ss` means **scalar single** — the source is a 4-byte float, not an 8-byte double. The other three lanes of `xmm0` are ignored. (If we wanted them, we'd `shufps` or use `pextrd` to pull a different lane down to lane 0 first.)

## Peek at one lane in `gdb`

**In plain words:** let's actually *see* the four numbers sitting in `xmm0` after the add.

```
$ gdb ./02_simd_addps
(gdb) break _start
(gdb) run
(gdb) layout asm
(gdb) si      # step until just after  addps xmm0, xmm1
(gdb) si
(gdb) si
(gdb) print $xmm0.v4_float
$1 = {11, 22, 33, 44}
```

`$xmm0.v4_float` is gdb's syntax for "show me `xmm0` as a vector of four floats." There's also `.v2_double`, `.v16_int8`, etc. — gdb knows the same register holds many possible interpretations.

**Gotcha.** Before the `addps` step, `$xmm0.v4_float` shows the *loaded* values `{1, 2, 3, 4}`. After it, `{11, 22, 33, 44}`. Stepping one instruction at a time and watching a register change is the fastest way to internalise what SIMD is doing.

## What about AVX (`ymm`) and AVX-512 (`zmm`)?

**In plain words:** wider benches. Same idea.

**The technical layer.**

- `ymm0..ymm15` are 256 bits — 8 floats or 4 doubles at a time. The mnemonics get a `v` prefix and a three-operand form: `vaddps ymm0, ymm1, ymm2`. The three-operand form is non-destructive: the source registers are not overwritten, the result goes into a separate destination.
- `zmm0..zmm31` are 512 bits — 16 floats or 8 doubles — and there are *32* of them instead of 16. They also add "mask" registers `k0..k7` so each lane can be conditionally enabled.

The mental model from `addps` carries straight up. The only new things are wider lanes and (in AVX-512) per-lane masking.

## Try it

1. **Replace `addps` with `mulps`.** Exit becomes `10` (= 1 × 10).
2. **Replace `addps` with `subps`.** Lane 0 is `1 - 10 = -9`, so exit becomes `247` (= `256 - 9`, due to 8-bit unsigned wrap).
3. **Change `movaps` to `movups` and remove `.align 16`.** Should still work — `movups` doesn't care about alignment.
4. **Change `movaps` to `movdqa` and load `a` as `.long 1, 2, 3, 4`** — same register, integer interpretation. SIMD reaches into integer math too (`paddd`, `pmullw`, `pcmpeqb`, …).

## What's next

In [Topic 03](03_lea_and_disasm.md) we drop back to integer land and look at the tools that let you *see* what the compiler (and you) actually produced: `objdump` and `gdb`.
