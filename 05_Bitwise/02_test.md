# 05.2 — `test`: AND that only keeps the flag lights

## A story: the customs officer who only checks, never stamps

**In plain words:** `test` does the same per-bit AND that `and` does, but it throws the result away. The only thing it leaves behind is the set of flag lights on the CPU's dashboard. We use it to ask yes/no questions about bits without disturbing the number.

**The analogy.** Imagine you're at customs. The officer holds up a stencil (the mask) against your suitcase contents (the value). If anything pokes through the stencil's holes, the officer triggers an alarm — but they don't *keep* anything they saw. Your suitcase is untouched. The only change is whether the alarm light is now ON.

**The technical layer.** `test dst, src` computes `dst & src` exactly like `and` would, but it discards the result and only updates the flags:

- `ZF` (zero flag) is set if the AND result is zero — meaning no overlapping ON bits.
- `SF` (sign flag) copies the top bit of the result.
- `CF` and `OF` are forced to `0`.

`dst` is **not** modified. That's the whole point.

## Why we need it

If you wrote `and rax, 0x10` to test whether bit 4 is on, you'd get the answer in the flags — but you'd also have destroyed `rax`. The next instruction would have to recover it somehow. `test` avoids that:

```asm
test    rax, 0x10               # is bit 4 of rax ON?
jnz     bit_was_on              # jump if non-zero (bit was ON)
```

Read it as: "AND `rax` with the mask, set flags, but don't touch `rax`."

## The flag-and-jump pattern

Every "is this bit set?" check in every compiler looks roughly like this:

| You write              | The CPU does                        |
| ---------------------- | ----------------------------------- |
| `test reg, mask`       | flags = (reg & mask) == 0           |
| `jz  label`            | jump if AND result was zero (bit OFF) |
| `jnz label`            | jump if AND result was non-zero (bit ON) |

`jz` ("jump if zero") and `jnz` ("jump if not zero") are just two names for "jump based on `ZF`." They read like English when paired with `test`.

**Vocabulary check.** `ZF` is one of several bits the CPU keeps in a special register called `RFLAGS`. After most arithmetic and logic instructions, the CPU automatically updates these flag bits to describe the result (was it zero, was it negative, did it carry, did it overflow). Conditional jumps read those bits to decide whether to jump.

## The classic `test reg, reg`

```asm
test    rax, rax
jz      it_was_zero
```

**In plain words:** AND `rax` with itself. The answer is `rax` unchanged — but the flags get updated. So this is the canonical way to ask "is `rax` zero?" right before a jump.

**Why not `cmp rax, 0`?** Both work. `test rax, rax` is shorter to encode and was historically faster on some chips. They're roughly interchangeable today, but `test reg, reg` is the idiom you'll see most often.

## The code

See [`02_test.s`](02_test.s). We store the byte `0b10100101` (bits 0, 2, 5, 7 are ON) and probe bit 0 and bit 3:

```asm
value:  .byte   0b10100101              # bits 0, 2, 5, 7 are ON
```

```asm
mov     al, byte ptr [rip + value]
test    al, 0x01                # bit 0 mask
jz      .Lb0_off                # ZF=1 means bit 0 was OFF
... print "bit 0: ON" ...
```

The mask `0x01` is `00000001` in binary — only bit 0 is ON. ANDing `0b10100101` with `0b00000001` gives `0b00000001`, which is non-zero, so `ZF=0`, so `jz` is **not** taken, and we fall through to the "ON" branch. For bit 3, the mask `0x08` is `00001000`, ANDed with `0b10100101` gives `0b00000000`, so `ZF=1` and we jump to the "OFF" branch.

Then we do one more demo to prove flags are the only output:

```asm
mov     rax, 0xDEADBEEF
test    rax, 0                  # anything AND 0 is 0, so ZF=1
jnz     .Lend                   # not taken
... print "value & 0 -> ZF=1 ..." ...
```

`rax` is still `0xDEADBEEF` after `test` — we never wrote to it. Only the flags moved.

## Build and run

```bash
as -o 02_test.o 02_test.s
ld -o 02_test 02_test.o
./02_test
```

Expected output:

```
bit 0: ON
bit 3: OFF
value & 0 -> ZF=1 (any number AND zero is zero)
```

## Gotcha: `test` vs `cmp`

Both set flags, neither writes to the destination. The difference is the operation:

- `cmp a, b` computes `a - b` (subtraction). Use it to compare *magnitudes*: equal, less, greater.
- `test a, b` computes `a & b` (bitwise AND). Use it to ask *which bits are on*.

Mixing them up is a common bug: `test rax, 5` does **not** check whether `rax == 5`. It checks whether any of the bits in `5` (i.e., bits 0 and 2) are ON in `rax`.

## Check yourself

Given `rax = 0b10110000`, what does `test rax, 0b00001111` do to `ZF`? (Answer: the AND is `0b00000000`, so `ZF=1`. None of the low 4 bits are on.)

What about `test rax, 0b10000000`? (Answer: the AND is `0b10000000`, non-zero, so `ZF=0`. The top bit *is* on.)

## Try it

1. Change `value` to `0b00001000` (only bit 3 ON) and re-run. The two output lines should swap.
2. Probe bit 7 (mask `0x80`) by adding another `test`/`jz` pair.
3. Walk through `test rax, rax; jnz somewhere` in your head for `rax = 0` and `rax = 5`. Confirm which one jumps.

## Next

Continue to [`03_shifts.md`](03_shifts.md): sliding the bits sideways, why `shr` and `sar` give different answers for negative numbers, and why the count must live in `cl`.
