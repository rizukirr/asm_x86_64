# Part 05 — Bitwise & Shifts

## A story: the row of switches

So far we've treated each number in a register as one whole thing — "12," "120," "-8." But under the hood, every number is a row of **64 little ON/OFF switches**. A `uint8_t` is 8 switches. A `uint64_t` is 64. The CPU has a whole family of instructions that lets you fiddle with those switches one position at a time — masking some, flipping others, sliding them sideways.

These instructions are the *cheapest* things the CPU can do. They run in a single cycle, never touch memory, and rarely care about flags. They're also how nearly every higher-level operation gets implemented under the hood: multiplying by powers of two, packing flags into a byte, parsing pixel colors, hashing strings, computing parity, aligning the stack. You will see them on every page of every disassembly for the rest of your life.

This chapter splits into four small topics. Read them in order — each one builds the vocabulary the next assumes.

## Vocabulary up front

- **Bit** — one switch, one `0` or `1`.
- **Byte** — 8 bits in a row.
- **Bitwise** — an operation applied to each bit position independently.
- **Mask** — a number whose ON bits mark the positions you care about.
- **Flag** — a single-bit "light" on the CPU's dashboard (zero, sign, carry, overflow…) that conditional jumps read.

## The topics

1. [`01_and_or_xor_not.md`](01_and_or_xor_not.md) — the four logic gates. `and` masks, `or` sets, `xor` toggles, `not` flips. The bread and butter of bit manipulation.
2. [`02_test.md`](02_test.md) — `test` is `and` that throws the result away. The standard way to ask "is this bit ON?" without destroying the value.
3. [`03_shifts.md`](03_shifts.md) — `shl`/`shr`/`sar` slide the switches sideways. How the CPU multiplies and divides by powers of two — and why `shr` and `sar` give different answers for negative numbers.
4. [`04_rotates_and_bitscan.md`](04_rotates_and_bitscan.md) — `rol`/`ror` (rotates), plus the `popcnt`/`bsf`/`bsr`/`lzcnt`/`tzcnt` family for counting and locating ON bits.

Each topic has a tiny `.s` program you can build and run with:

```bash
as -o NN_topic.o NN_topic.s
ld -o NN_topic NN_topic.o
./NN_topic
```

The full build-and-run loop for all four:

```bash
cd 05_Bitwise
for f in *.s; do
    as -o /tmp/t.o "$f" && ld -o /tmp/t /tmp/t.o && /tmp/t
    echo "[$f] exit=$?"
done
```

## Idioms you'll meet here and use forever

```asm
xor     eax, eax                # rax = 0  (the canonical zero)
test    rax, rax                # set flags from rax without changing it
or      rax, -1                 # rax = -1 (all bits ON)
and     rsp, -16                # round rsp down to a multiple of 16
test    al, 0x10                # is bit 4 of al ON?
shl     rax, 3                  # rax *= 8
sar     rax, 1                  # signed rax /= 2
popcnt  rax, rax                # how many ON bits in rax?
```

If those look like noise now, they'll look like sentences by the end of this chapter.

## Next

After you've worked through all four topics, continue to [Part 06](../06_Addressing/README.md) — the **effective address**: one formula that drives every memory access on x86, and how `lea` quietly turns it into a free arithmetic instruction.
