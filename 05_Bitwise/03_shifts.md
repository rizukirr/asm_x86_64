# 05.3 — Shifts: `shl`, `shr`, `sar`

## A story: sliding the switches sideways

**In plain words:** a shift takes the entire row of 64 switches and slides them left or right by some number of positions. Whatever falls off one end disappears; the other end is filled with new switches (usually zeros).

**The analogy.** Imagine the 64 switches sit on a wide rail, and you give the rail a shove. Sliding everything one position to the left makes the number twice as big — every switch is now in a position whose "value" is double. Sliding right halves it. It's how the CPU multiplies and divides by powers of two for free, in a single instruction, without the overhead of `mul` or `div`.

**The technical layer.** Each bit position has a positional value: bit 0 means 1, bit 1 means 2, bit 2 means 4, bit 3 means 8, etc. Each position doubles the one to its right. So shifting one bit left is the same as multiplying by 2; shifting `n` bits left is multiplying by 2ⁿ.

## The instructions

| Instruction      | What happens                                           |
| ---------------- | ------------------------------------------------------ |
| `shl dst, n`     | Shift left by `n`. Same as multiplying by 2ⁿ. The bottom fills with `0`. |
| `shr dst, n`     | Shift right by `n`, **filling the top with zeros** (logical shift). |
| `sar dst, n`     | Shift right by `n`, **filling the top with a copy of the original sign bit** (arithmetic shift). |
| `sal dst, n`     | Synonym for `shl`. Same instruction, just a different mnemonic. |

The shift count `n` is either a small constant baked into the instruction, or — if you want to compute it at runtime — it must live in the 8-bit register **`cl`**:

```asm
mov     cl, 5
shl     rax, cl                 # rax <<= 5  (same as rax *= 32)
```

**Gotcha.** You cannot put the count in `bl`, `dl`, or anything else. The shift count must be `cl` (or a constant). This is a historical quirk of the original 8086 — modern chips still honor it.

## `shr` vs `sar`: the gotcha that bites real code

When the value you're shifting is negative (top bit is `1`), the two right-shifts give different answers:

```asm
mov     rax, -8                 # 0xFFFFFFFFFFFFFFF8 in two's complement
shr     rax, 1                  # -> 0x7FFFFFFFFFFFFFFC (huge positive!)

mov     rax, -8
sar     rax, 1                  # -> 0xFFFFFFFFFFFFFFFC (= -4, correct halving)
```

**In plain words.** `shr` (the *logical* shift) doesn't know or care that the number is negative — it just slides the bits right and pours a `0` into the top. Suddenly the top bit is `0`, so the value looks positive, and you get a gigantic wrong answer. `sar` (the *arithmetic* shift) duplicates the original top bit as it slides — so a negative number stays negative, and you get the right "divide by two."

**The technical layer.** Two's complement says the top bit determines the sign. A correct signed divide-by-2 must preserve that bit. `sar` does that; `shr` does not.

**Rule of thumb:**

- **Unsigned values** (counts, sizes, addresses): use `shr`.
- **Signed values** (anything that could be negative): use `sar`.

Compilers know this and pick the right one automatically. If you mix them up by hand, your code will look correct for positive numbers and silently wrong for negatives.

## What the flags do

All three shifts update flags. The interesting one is `CF` (carry): for a right shift, `CF` ends up holding the *last bit shifted out*. So `shr rax, 1; jc was_odd` jumps if `rax` was originally odd — its low bit (which determines odd/even) just fell into `CF`.

`ZF` and `SF` also update normally. `OF` is only defined for shifts of exactly 1.

## The code

See [`03_shifts.s`](03_shifts.s). It runs four cases and prints each result as a 16-digit hex number:

```asm
mov     rax, 5
shl     rax, 3                  # 5 << 3 = 40 = 0x28
```

```asm
mov     rax, 16
shr     rax, 1                  # 16 >> 1 = 8
```

```asm
mov     rax, -8
shr     rax, 1                  # 0xFFFFFFFFFFFFFFF8 -> 0x7FFFFFFFFFFFFFFC
```

```asm
mov     rax, -8
sar     rax, 1                  # 0xFFFFFFFFFFFFFFF8 -> 0xFFFFFFFFFFFFFFFC
```

A helper, `print_hex64`, prints `rax` as 16 hex digits. It uses `shr` itself in a loop to peel off one nibble at a time — a nice live demo of shifts in action:

```asm
mov     rsi, rax
and     rsi, 0x0F               # low nibble of rax
... lookup char ...
shr     rax, 4                  # drop the bottom nibble, expose the next one
```

## Build and run

```bash
as -o 03_shifts.o 03_shifts.s
ld -o 03_shifts 03_shifts.o
./03_shifts
```

Expected output:

```
shl 5, 3       = 0x0000000000000028
shr 16, 1      = 0x0000000000000008
shr -8, 1 (u)  = 0x7FFFFFFFFFFFFFFC
sar -8, 1 (s)  = 0xFFFFFFFFFFFFFFFC
```

Read carefully: case 3 and case 4 start with the same input (`-8`), and produce wildly different answers. That's the whole lesson.

## A handy mental conversion

If you see `shl rax, 4`, think "multiply by 16." If you see `sar rax, 3`, think "signed divide by 8." If you see `and rsp, -16`, think "round `rsp` down to a multiple of 16" (we'll see this trick in the next chapters on the stack).

## Variable shift count

```asm
mov     cl, 5
shl     rax, cl
```

**In plain words:** put the shift count in `cl`, then use `cl` as the operand. Only the bottom 6 bits of `cl` are used for 64-bit shifts (the CPU masks the count), so a count of 64 actually shifts by 0 — beware.

**Gotcha.** Many beginners try `shl rax, rcx` and get a syntax error. The count register is *strictly* `cl`, never `rcx` or `cx` or `ecx`.

## Try it

1. Change the `shl 5, 3` case to `shl 5, 10`. Predict the hex result (5 × 1024 = 5120 = 0x1400).
2. Replace `sar rax, 1` with `sar rax, 2` on `-8`. You should see `0xFFFFFFFFFFFFFFFE` (= -2). Two halvings = divide by 4.
3. Shift a value by 64. Run it. Notice the value didn't change — the count was masked to 0 (only the low 6 bits matter for `r64`).
4. Open the program in `gdb` (`gdb ./03_shifts`, then `break _start`, `run`, `stepi`) and watch `rax` change after each shift.

## Next

Continue to [`04_rotates_and_bitscan.md`](04_rotates_and_bitscan.md): rotates (where bits wrap around instead of falling off), plus the `popcnt`, `bsf`, `bsr` family that lets you *count* and *locate* set bits.
