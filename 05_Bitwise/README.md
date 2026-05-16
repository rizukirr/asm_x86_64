# Part 05 — Bitwise & Shifts

## A story first

Picture a row of light switches on a wall — say 8 of them in a row. Each switch is either ON (`1`) or OFF (`0`). Together, those 8 switches spell out a *byte*. A 64-bit register is just a row of **64** switches.

So far we've treated the number in a register as one whole number — like "12" or "120." But that number is actually made of 64 little switches under the hood. Sometimes we want to fiddle with just **one switch** at a time, or compare two rows of switches one position at a time.

That's what bitwise instructions do. They're the cheapest things the CPU can do — usually one cycle, no flag drama, no memory drama. They're also how the CPU implements multiplying by powers of two, picking apart pieces of a number, packing flags together, and a hundred other tricks you'll see in every program.

Vocabulary check:

- **Bit** = one switch, one tiny `0` or `1`.
- **Byte** = 8 bits in a row.
- **Bitwise operation** = does the same little operation on each switch position independently.

## The four logic gates

There are four basic bitwise operations. Compare each switch of `dst` with the matching switch of `src`, and produce a new switch from the rule:

| Instruction      | Rule per switch position                |
| ---------------- | --------------------------------------- |
| `and dst, src`   | `1` only if BOTH are `1`                |
| `or  dst, src`   | `1` if EITHER is `1`                    |
| `xor dst, src`   | `1` if EXACTLY one is `1` (different)   |
| `not dst`        | flip every switch (no second operand)   |

All four of those write the answer back into `dst`, just like `add` does.

The first three (`and`, `or`, `xor`) update the `ZF` (zero) and `SF` (sign) lights based on the result, and they **turn off** the `CF` (carry) and `OF` (overflow) lights. `not` is special: it doesn't touch any flag lights at all — it just flips bits.

### Common uses

- **Masking (keeping only some bits):** `and rax, 0xFF` — keep only the bottom 8 switches, force the rest to OFF. (`0xFF` is binary `11111111`, so `AND`-ing keeps those 8 bits and zeros the rest.)
- **Setting bits (turning a switch ON):** `or rax, 0x100` — force bit 8 to ON, leave everything else alone.
- **Toggling bits (flipping a switch):** `xor rax, 0x100` — flip bit 8 from whatever it was to its opposite.
- **Zeroing a register:** `xor eax, eax` — set `rax` to 0 in only 2 bytes of machine code. (Why does writing `eax` zero `rax`? Because 32-bit writes on x86_64 automatically clear the top 32 bits. A quirk worth memorizing.)
- **Testing a bit:** `test rax, 0x10` followed by `jnz` ("jump if not zero") to jump when bit 4 is on. `test` is like `and` but it throws away the answer and just keeps the flag lights.

## Shifts

Shifting means sliding all the switches sideways. If you slide everything one position to the left, the number doubles (because each switch's "value" doubles). Slide it right, and the number halves. It's how the CPU multiplies and divides by powers of two for free.

| Instruction      | What happens                                        |
| ---------------- | --------------------------------------------------- |
| `shl dst, n`     | Shift left by `n`. Same as multiplying by 2ⁿ.       |
| `shr dst, n`     | Shift right by `n`, **filling the top with zeros**. |
| `sar dst, n`     | Shift right by `n`, **filling the top with the sign bit** (arithmetic shift; keeps negatives negative). |
| `rol dst, n`     | Rotate left — bits that fall off the left wrap around to the right. |
| `ror dst, n`     | Rotate right — bits that fall off the right wrap around to the left. |

The shift count `n` is either a plain number written right in the instruction, or — if you want to compute the count at runtime — it must be in the specific 8-bit register **`cl`**:

```asm
mov     cl, 5
shl     rax, cl                 # rax <<= 5  (rax = rax * 32)
```

You can't shift by, say, `bl`. It has to be `cl` or a constant. Another historical leftover from way back.

### `shr` vs `sar` — the one that bites you

```asm
mov     rax, -8                 # 0xFFFFFFFFFFFFFFF8
shr     rax, 1                  # rax = 0x7FFFFFFFFFFFFFFC  (huge positive)
mov     rax, -8
sar     rax, 1                  # rax = 0xFFFFFFFFFFFFFFFC  (-4, as expected)
```

What this actually does, in plain words:

`-8` in 64-bit two's complement is `0xFFFF...FFF8` (lots of `1` switches on the left, plus the bottom). If you `shr` (shift right with zeros) by 1, the topmost switch becomes `0`, which makes the number look positive — suddenly the value is gigantic and positive. If you `sar` (shift right keeping the sign bit), the topmost switch *copies itself* in, so the result stays negative and equals `-4` — which is what `-8 / 2` should be.

So: **signed division by powers of two uses `sar`, unsigned uses `shr`**. Compilers know this. If you mix them up by hand, you'll get answers that are wrong only for negative inputs.

## Bit-scan and friends

A small zoo of "tell me where the bits are" instructions:

| Instruction      | What it does                                              |
| ---------------- | --------------------------------------------------------- |
| `bsf dst, src`   | Find the position of the **lowest** ON bit in `src`. If `src` is 0, sets `ZF=1`. |
| `bsr dst, src`   | Find the position of the **highest** ON bit (roughly `log2`). |
| `popcnt dst, src`| Count how many bits are ON.                               |
| `lzcnt dst, src` | Count how many zero bits are at the top before the first 1. |
| `tzcnt dst, src` | Count how many zero bits are at the bottom before the first 1. |

`popcnt`, `lzcnt`, `tzcnt` are newer (~2008) extensions, but any modern x86_64 chip has them.

## Idioms you will see everywhere

```asm
xor     eax, eax                # rax = 0    (2 bytes; the canonical "zero")
test    rax, rax                # set flags as if rax was just produced
                                # used right before "jz" / "jnz" to test for zero
sub     rax, rax                # also zeroes rax, also 2 bytes; sets flags
or      rax, -1                 # rax = -1 (3 bytes)
and     rsp, -16                # align rsp down to 16 bytes
```

What this actually does, in plain words:

- `xor eax, eax`: anything XOR'd with itself is zero. Cheapest known way to zero a register.
- `test rax, rax`: AND `rax` with itself — the answer is unchanged, so it's thrown away. But the flag lights now reflect whether `rax` is zero, negative, etc. Used right before a conditional jump that asks "is this zero?"
- `sub rax, rax`: another zeroing trick. Same end result, but it does set the carry/overflow flags differently than `xor`.
- `or rax, -1`: ORing with all-ones forces every bit to ON, so `rax` becomes all `1`s, which equals `-1`.
- `and rsp, -16`: this one needs unpacking.

`-16` in 64-bit two's complement is `0xFFFFFFFFFFFFFFF0` — every bit is `1` *except* the bottom four, which are `0`. When you `and` `rsp` with that, the top bits of `rsp` stay the same, and the bottom 4 bits get forced to `0`. Forcing the bottom 4 bits to zero is the same as rounding `rsp` *down* to the nearest multiple of 16. The C calling convention requires `rsp` to be a multiple of 16 right before any function call, so this is the standard "make sure we're aligned" trick.

## A worked example: parity in 6 instructions

Parity means "is the count of ON bits even or odd?" Let's check whether the byte `10110100` (binary) has an even number of `1`s — count them: 1, 0, 1, 1, 0, 1, 0, 0 → four `1`s → even → answer `0`.

```asm
.intel_syntax noprefix
        .globl  _start
_start:
        mov     rax, 0b10110100         # 4 set bits -> parity even -> 0
        popcnt  rax, rax
        and     rax, 1
        mov     rdi, rax
        mov     rax, 60
        syscall
```

What this actually does, in plain words:

1. Put `10110100` in binary into `rax`. (The `0b` prefix means binary.)
2. `popcnt rax, rax` counts the ON bits and puts the count back in `rax`. Now `rax = 4`.
3. `and rax, 1` keeps only the bottom bit, which tells us "is the count odd?" 4 is even, so the bottom bit is 0. Now `rax = 0`.
4. Last three lines: ask Linux to exit with that value as the exit code.

```bash
as -o parity.o parity.s && ld -o parity parity.o
./parity ; echo $?
# => 0   (even number of set bits)
```

## Try it

1. Replace `0b10110100` with `0b10110101` (now 5 ON bits) and re-run. You should see `1`.
2. Write a program that tests whether a 64-bit number is a power of two. Easy way: `popcnt`, then check for 1. Sneaky way: `x & (x-1) == 0` (works for non-zero `x`).
3. Swap two registers using only *three* `xor`s and no temporary or stack:
   ```asm
   xor rax, rbx
   xor rbx, rax
   xor rax, rbx
   ```
   Walk through what each step does on paper. It's a cute trick — in real code, just use `xchg` or a temporary register.

## What's next

[Part 06](../06_Addressing/README.md) — the **effective address**. This is the single most important formula in x86: one shape that drives every memory access, and (thanks to a special instruction called `lea`) it secretly doubles as a free arithmetic instruction.
