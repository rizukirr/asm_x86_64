# Topic 02 — `mul` and `imul`

## A story: the answer that doesn't fit

**In plain words:** if you multiply two big numbers, the answer can be twice as wide as either input. The CPU has to put that wide answer *somewhere*, and one cup might not be enough.

**The analogy.** Picture two 4-digit numbers: `9999 * 9999`. The answer is `99980001` — eight digits, not four. To hold it, you need *twice* the space of either input. x86 solves this by gluing two cups together, side by side, and writing the full answer across the pair.

**The technical layer.** Multiplication has three forms on x86_64, and they trade off precision for convenience:

| Form        | Pattern                | What it computes                 |
| ----------- | ---------------------- | -------------------------------- |
| 1-operand   | `imul rcx`             | `rdx:rax = rax * rcx` (128-bit)  |
| 2-operand   | `imul rax, rcx`        | `rax = rax * rcx` (low 64 bits)  |
| 3-operand   | `imul rax, rcx, 10`    | `rax = rcx * 10`                 |

The "i" in `imul` stands for **integer signed** — negative numbers are allowed. There is also a plain `mul` (no `i`) for **unsigned** multiplication; it only has the 1-operand form. For the 2- and 3-operand forms, signed and unsigned produce the same low-64-bit answer, so the assembler always uses `imul`.

## Form 1: full-width result in `rdx:rax`

**In plain words:** the worker grabs `rax`, multiplies it by the cup you name, and pours the answer into two cups: the *high half* goes into `rdx`, the *low half* into `rax`.

```asm
mov     rax, 1000000000         # 1e9
mov     rcx, 1000000000         # 1e9
imul    rcx                     # rdx:rax = 1e18 (too big for rax alone)
```

**The technical layer.** The notation `rdx:rax` means "treat the two cups as one giant 128-bit number, with `rdx` holding the upper 64 bits and `rax` the lower 64." After the multiply, if the answer fit in 64 bits, `rdx` is just full of sign-extension bits (all 0s for positive, all 1s for negative). If it didn't fit, `rdx` carries the part that overflowed.

**Gotcha.** The 1-operand form **always** clobbers `rdx`, even when the answer would have fit in `rax` alone. If you had something useful in `rdx`, save it first. This is the same reason we'll have to be careful with `idiv` in the next topic.

## Form 2: truncated result, one cup

**In plain words:** multiply, but only keep the bottom 64 bits. Anything that overflowed is silently dropped.

```asm
mov     rax, 6
mov     rcx, 7
imul    rax, rcx                # rax = 42
```

**The technical layer.** This is what every high-level language does by default. In C, `int a = b * c;` is exactly this: if the answer overflows the type, the high bits are thrown away. It's fast, it leaves `rdx` alone, and it's almost always what you want.

**Check yourself.** What happens if `rax = 2^33` and you do `imul rax, rax`? The mathematical answer is `2^66`, which needs 67 bits. The bottom 64 bits of `2^66` are all zero, so `rax` becomes 0. Surprising, but correct per the rules.

## Form 3: multiply by a constant

**In plain words:** "multiply this cup by this immediate number and put the answer in that cup." Three things named at once.

```asm
imul    rax, rcx, 3             # rax = rcx * 3
```

**The technical layer.** The third operand is a **literal number** baked into the instruction at assemble time, not a register. This form is great for scaling by a known constant — array indexing (`offset = i * sizeof(struct)`), pointer arithmetic, scaling pixel coordinates, etc. The compiler emits this constantly.

**Gotcha.** Some assemblers will accept `imul rax, 3` with only two operands when one is a register and the other an immediate; that's actually the 3-operand form with `dst` and `src1` collapsed to the same register. Read your toolchain's docs before relying on it.

## Signed vs unsigned: when does it matter?

**In plain words:** for the 2- and 3-operand forms, never — the bottom 64 bits are the same either way. For the 1-operand form, signed (`imul`) and unsigned (`mul`) give different *high* halves.

**The analogy.** Think of decimal: `97 * 97 = 9409`. If we wrote 97 as "negative three" (using a fictional two-digit signed scheme where 99 means -1, 98 means -2, 97 means -3), then `(-3) * (-3) = 9`, with no high digits. Same low digits ("09" vs "09"), different high digits. That's exactly the situation with `mul` vs `imul` at 64 bits.

**The technical layer.** Use `imul` when your numbers are signed (can be negative). Use `mul` when they're unsigned (always positive — counters, sizes, addresses, hashes). Mixing them up only matters if you care about the upper half of the answer.

## The runnable example

See [`02_mul_imul.s`](02_mul_imul.s). It computes `6 * 7 = 42` with the 2-operand form, then `42 * 3 = 126` with the 3-operand form, then runs a 1-operand `imul` on big numbers just to exercise that encoding (the result is computed but discarded). Final printed value: `126`.

The critical lines:

```asm
mov     rax, 6
mov     rcx, 7
imul    rax, rcx                # 2-operand: rax = 42

imul    rax, rax, 3             # 3-operand: rax = 126

mov     rax, 1000000000
mov     rcx, 1000000000
imul    rcx                     # 1-operand: rdx:rax = 1e18
```

## Build and run

```bash
as -o /tmp/t.o 02_mul_imul.s && ld -o /tmp/t /tmp/t.o && /tmp/t
# => 126
```

## Check yourself

1. After `mov rax, -2 ; mov rcx, 3 ; imul rax, rcx`, what is in `rax`? (Answer: -6, encoded as a 64-bit two's-complement bit pattern.)
2. After `mov rax, 0xFFFFFFFFFFFFFFFF ; mov rcx, 2 ; imul rax, rcx`, what is in `rax`? (Answer: `0xFFFFFFFFFFFFFFFE` — the low 64 bits of -1 * 2 = -2.)
3. Why does the 1-operand `mul` instruction not name `rax` explicitly? (Answer: it's always implicit. `rax` is the hard-wired first input, and `rdx:rax` is the hard-wired output. The instruction encoding only has room to name one register.)

## Next

[Topic 03 — `div` and `idiv`](03_div_idiv.md): division, the awkward instruction with the `rdx:rax` quirk that bites every beginner.
