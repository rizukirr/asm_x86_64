# 05.1 — `and`, `or`, `xor`, `not`: the four logic gates

## A story: a row of light switches

**In plain words:** every number in a register is secretly a row of 64 little ON/OFF switches. The four logic gates let you compare two rows of switches, position by position, and produce a new row.

**The analogy.** Picture two long walls, each with 64 light switches. You stand in front of them with a rulebook:

- `AND` rule: turn the new switch ON only if **both** matching switches were ON.
- `OR` rule: turn it ON if **either** was ON.
- `XOR` rule: turn it ON if they **disagreed** (exactly one was ON).
- `NOT` rule: ignore wall #2 entirely — just flip every switch on wall #1.

**The technical layer.** These four instructions are called *bitwise* because they apply the rule to each bit position independently. They are about the cheapest thing the CPU can do — usually one cycle, no memory drama, no branching. Every program on your machine uses them constantly to pack flags, parse colors, mask out high bits, and toggle features.

## The four instructions

| Instruction      | Per-bit rule                            | Operand count |
| ---------------- | --------------------------------------- | ------------- |
| `and dst, src`   | `1` only if BOTH bits are `1`           | two           |
| `or  dst, src`   | `1` if EITHER bit is `1`                | two           |
| `xor dst, src`   | `1` if EXACTLY one bit is `1`           | two           |
| `not dst`        | flip every bit (no `src`)               | one           |

All four write the answer back into `dst` (just like `add` does). The first three set the zero flag (`ZF`) and the sign flag (`SF`) based on the result, and they clear `CF` and `OF`. `not` is the oddball — it doesn't touch flags at all.

**Vocabulary check.** A **bit** is one switch. A **byte** is 8 bits. A **mask** is just a number you craft on purpose so that its ON bits mark the positions you care about.

## The three classic moves

These three idioms are the bread and butter of bit manipulation:

```asm
and     al, 0x0F                # MASK: keep the bottom 4 bits, force the rest to 0
or      al, 0x80                # SET:  force bit 7 to ON, leave others alone
xor     al, 0x01                # TOGGLE: flip bit 0 from whatever it was
```

**In plain words.**

- **Mask with AND.** Wherever the mask has a `0`, the answer has a `0`. Wherever the mask has a `1`, the answer keeps whatever was in `dst`. So you "punch a window" through the mask to see only certain bits.
- **Set with OR.** Wherever the mask has a `1`, the answer has a `1`. Wherever the mask has a `0`, the answer keeps `dst`. So `OR` *adds* ON bits.
- **Toggle with XOR.** Wherever the mask has a `1`, the answer is the *opposite* of `dst`. Wherever the mask has a `0`, the answer keeps `dst`. So `XOR` *flips* the chosen bits.

**Check yourself.** What does `xor al, 0xFF` do? (Answer: flips every bit of the low byte — same as `not al`, except `xor` updates flags and `not` doesn't.)

## The code

See [`01_and_or_xor_not.s`](01_and_or_xor_not.s). It computes four results and prints each one as two hex digits:

```
AND = 0xCC AND 0xAA = 0x88
OR  = 0xF0 OR  0x0F = 0xFF
XOR = 0xFF XOR 0x0F = 0xF0
NOT = NOT  0x00     = 0xFF
```

The key fragments:

```asm
mov     al, 0xCC
and     al, 0xAA                # 0b11001100 & 0b10101010 = 0b10001000 = 0x88
```

```asm
mov     al, 0xF0
or      al, 0x0F                # 0b11110000 | 0b00001111 = 0b11111111 = 0xFF
```

```asm
mov     al, 0xFF
xor     al, 0x0F                # 0b11111111 ^ 0b00001111 = 0b11110000 = 0xF0
```

```asm
mov     al, 0x00
not     al                      # ~0x00 = 0xFF
```

A small helper, `byte_to_hex`, converts a byte in `al` into two ASCII hex digits using a lookup table:

```asm
hexchars: .ascii "0123456789ABCDEF"
...
shr     al, 4                   # high nibble (we cover shifts in 03_shifts.md)
and     al, 0x0F
lea     rdx, [rip + hexchars]
mov     al, byte ptr [rdx + rax] # rdx[index] -> ASCII digit
```

Don't worry about `shr` and `lea` yet — we cover them in the next files. For now, just trust that the helper turns one byte into two printable characters.

## Build and run

```bash
as -o 01_and_or_xor_not.o 01_and_or_xor_not.s
ld -o 01_and_or_xor_not 01_and_or_xor_not.o
./01_and_or_xor_not
```

Expected output:

```
and/or/xor/not demo
AND = 0x88
OR  = 0xFF
XOR = 0xF0
NOT = 0xFF
```

## The XOR zeroing trick (again)

You already saw `xor rdi, rdi` in Part 01. Now you can name the magic:

**In plain words:** any number XORed with itself is zero, because every bit position has matching values, so the "exactly one ON" rule fails everywhere. The result is all zeros.

**The technical layer.** `xor eax, eax` is the canonical way to zero a register on x86_64. It's:

- 2 bytes (vs. 5 for `mov eax, 0`, vs. 7 for `mov rax, 0`),
- recognized by the CPU as a *zeroing idiom* — the decoder breaks the dependency chain on `eax`, so the new instruction doesn't have to wait for whatever was computing `eax` previously.

**Gotcha.** Read `xor reg, reg` as "zero this register," not "XOR these two things." When you see it in the wild it's almost never about XOR semantics — it's just the cheapest zero.

## A note about `not` and flags

`not rax` flips every bit of `rax`, including the sign bit. But it does **not** touch any flag. That's a real surprise — every other bitwise op updates `ZF`/`SF`.

If you want the flag update too, write `xor rax, -1` instead. `-1` is all ones in two's complement, and XORing with all ones flips everything — but `xor` *does* update flags.

**Check yourself.** After `mov rax, 0` and then `not rax`, what is `rax`? (Answer: `0xFFFFFFFFFFFFFFFF`, which is `-1` if you read it as a signed number. The zero flag is still whatever it was before — `not` left it alone.)

## Try it

1. Replace `0xCC AND 0xAA` with `0xCC AND 0x0F`. Predict the answer on paper first, then run.
2. Use `or al, 0x80` to forcibly set the top bit of an arbitrary value (`0x42` for example). What's the result?
3. Use `xor al, 0xFF` on `0x55` (binary `01010101`). Predict, then run.
4. Run the program under `strace ./01_and_or_xor_not` to confirm it makes exactly two syscalls — one `write`, one `exit`.

## Next

Continue to [`02_test.md`](02_test.md): the `test` instruction, which is just `and` with the answer thrown away — and it's how every "is this bit set?" check is implemented.
