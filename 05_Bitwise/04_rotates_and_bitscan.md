# 05.4 — Rotates and bit-scanning

## A story: the conveyor belt

**In plain words:** a *shift* slides bits sideways and drops whatever falls off the end. A *rotate* wraps the falling bit back around to the other end — the belt is a loop, not a flat rail.

**The analogy.** Imagine the 64 switches sitting on a circular conveyor belt that joins end to end. When you `rol` (rotate left) by one, the top switch doesn't fall off — it loops around and reappears at the bottom. When you `ror` (rotate right), the bottom switch reappears at the top. No information is lost, ever.

**The technical layer.** Rotates preserve the entire bit pattern; they just renumber the positions. They show up in cryptography (mixing bits without losing them), checksums, and any algorithm that needs cyclic patterns.

## Rotate instructions

| Instruction      | What happens                                                    |
| ---------------- | --------------------------------------------------------------- |
| `rol dst, n`     | Rotate left by `n`. Bits leaving the top reappear at the bottom. |
| `ror dst, n`     | Rotate right by `n`. Bits leaving the bottom reappear at the top. |
| `rcl dst, n`     | Rotate left **through** `CF` (the carry flag joins the loop).   |
| `rcr dst, n`     | Rotate right through `CF`.                                      |

`rcl`/`rcr` use the carry flag as an extra "65th switch" in the loop. You see them in multi-precision arithmetic — chaining shifts across two registers. For everyday code, `rol`/`ror` are what you'll reach for.

Just like shifts, a variable rotate count must live in `cl`.

## A pair of small rotate examples

```asm
mov     rax, 0x8000000000000001
rol     rax, 1                  # 0x0000000000000003
```

**In plain words.** Bits 63 and 0 were both ON. After rotating left by 1, the bit that was at position 63 wraps around to position 0; the bit that was at position 0 moves to position 1. So we end up with bits 0 and 1 ON — `0x0000000000000003`.

```asm
mov     rax, 0x0000000000000003
ror     rax, 1                  # 0x8000000000000001
```

**In plain words.** Same thing in reverse. Bit 0 wraps to bit 63; bit 1 moves to bit 0. So the result has bit 63 and bit 0 ON.

A useful intuition: `ror x, n` is the inverse of `rol x, n` — the two undo each other exactly.

## The bit-scanning zoo

A handful of instructions exist to answer "where are the ON bits?" and "how many are there?"

| Instruction        | What it tells you                                                       |
| ------------------ | ----------------------------------------------------------------------- |
| `popcnt dst, src`  | Number of ON bits in `src` (the "population count").                    |
| `bsf dst, src`     | Position of the **lowest** ON bit (bit scan forward). `ZF=1` if `src=0`. |
| `bsr dst, src`     | Position of the **highest** ON bit (bit scan reverse). Roughly `floor(log2(src))`. |
| `lzcnt dst, src`   | Count of leading zeros before the first ON bit.                         |
| `tzcnt dst, src`   | Count of trailing zeros before the first ON bit.                        |

**In plain words.**

- `popcnt` answers "how many switches are ON?"
- `bsf` answers "what's the smallest index where a switch is ON?"
- `bsr` answers "what's the largest index where a switch is ON?"
- `lzcnt` answers "how many OFF switches at the top before the first ON one?"
- `tzcnt` answers "how many OFF switches at the bottom before the first ON one?"

**The technical layer.** `popcnt`, `lzcnt`, and `tzcnt` are newer (around 2008 onward). They're fast: one cycle on modern chips. `bsf`/`bsr` are older, slightly slower, and have one foot-gun: when `src` is zero, the destination is *undefined*. Always check `ZF` after them.

## The code

See [`04_rotates_and_bitscan.s`](04_rotates_and_bitscan.s). It demonstrates all five instructions and prints each result as a 16-digit hex number:

```asm
mov     rax, 0b10110100
popcnt  rax, rax                # 4 ON bits -> rax = 4
```

```asm
mov     rbx, 0b00010000         # only bit 4 is ON
bsf     rax, rbx                # rax = 4 (lowest ON bit)
bsr     rax, rbx                # rax = 4 (highest ON bit)
```

When only one bit is ON, `bsf` and `bsr` give the same answer — there's only one "lowest" and "highest" candidate.

## Build and run

```bash
as -o 04_rotates_and_bitscan.o 04_rotates_and_bitscan.s
ld -o 04_rotates_and_bitscan 04_rotates_and_bitscan.o
./04_rotates_and_bitscan
```

Expected output:

```
rol 0x8000000000000001, 1 = 0x0000000000000003
ror 0x0000000000000003, 1 = 0x8000000000000001
popcnt(0b10110100)        = 0x0000000000000004
bsf (0b00010000)          = 0x0000000000000004
bsr (0b00010000)          = 0x0000000000000004
```

## A worked example: is `x` a power of two?

A power of two has exactly one ON bit. So two equivalent answers:

```asm
popcnt  rax, rdi                # count ON bits
cmp     rax, 1                  # exactly one?
```

Or the classic trick that doesn't need `popcnt` at all:

```asm
mov     rax, rdi
dec     rax                     # x - 1
and     rax, rdi                # (x - 1) & x
                                # == 0 iff x was a power of two (and non-zero)
```

**Why does `(x-1) & x == 0` work?** When `x` is a power of two, it has exactly one ON bit, say at position `k`. Subtracting 1 flips that bit OFF and turns all the bits below it ON. So `x` and `x-1` have **no overlapping ON bits**, and their AND is zero. For any other `x` (with more than one ON bit), at least one bit will survive the AND.

## Idioms you'll see in real code

```asm
xor     eax, eax                # rax = 0 (2 bytes; canonical zero)
test    rax, rax                # set flags as if rax was just produced
or      rax, -1                 # rax = -1 (all bits ON)
and     rsp, -16                # round rsp down to a multiple of 16
```

The last one deserves a final look. `-16` in two's complement is `0xFFFFFFFFFFFFFFF0` — every bit is `1` except the bottom four. ANDing `rsp` with that forces the bottom 4 bits to `0`, which is exactly the same as rounding `rsp` *down* to a multiple of 16. The C calling convention requires `rsp` to be 16-aligned right before any function call, so this single instruction is the standard alignment trick.

## Try it

1. Rotate `0xDEADBEEF` left by 4. Predict and confirm.
2. Write the power-of-two check above. Exit with status 0 if it's a power of two, 1 otherwise.
3. Find the position of the highest ON bit in `0x8000000000000000` (it's 63). Confirm with `bsr`.
4. Bonus: implement an XOR swap using only `xor` instructions, no temporary:
   ```asm
   xor rax, rbx
   xor rbx, rax
   xor rax, rbx
   ```
   Walk through what each step does to `rax` and `rbx` on paper. (In real code, just use `xchg` — it's clearer.)

## Next

You've now seen every common bit operation: logic, masking, testing, shifting, rotating, scanning. In [Part 06](../06_Addressing/README.md) we look at the *effective address* — the one formula that drives every memory access, and how `lea` secretly turns it into a free arithmetic instruction.
