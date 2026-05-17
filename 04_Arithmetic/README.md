# Part 04 — Arithmetic

This chapter teaches the four pillars of integer math on x86_64: addition, subtraction, multiplication, division — and the **flags** the CPU silently updates after every operation. Those flags are how *all* later branching works.

The big mental model: **math instructions don't branch. They compute, then set flags. Jumps read the flags.** Keep that in your head; it explains everything that follows in this course.

## Topics

1. [`01_add_sub_inc_dec_neg`](01_add_sub_inc_dec_neg.md) — the basic five: `add`, `sub`, `inc`, `dec`, `neg`. Two-operand form, register widths, and a brief look at the carry-in cousins `adc` / `sbb`.
2. [`02_mul_imul`](02_mul_imul.md) — the three forms of `imul` (1-, 2-, 3-operand), the `rdx:rax` full-width result, and when signed vs unsigned actually matters.
3. [`03_div_idiv`](03_div_idiv.md) — the awkward instruction: why you must `cqo` (signed) or `xor rdx, rdx` (unsigned) before dividing, and how the quotient and remainder come out together.
4. [`04_flags_cf_zf_sf_of`](04_flags_cf_zf_sf_of.md) — the four flags every arithmetic instruction touches, the difference between `CF` (unsigned overflow) and `OF` (signed overflow), and `setcc` for reading them.

Each topic has a small runnable program in the matching `.s` file. Build any of them with:

```bash
as -o foo.o NN_topic.s && ld -o foo foo.o && ./foo
```

## Next

[Part 05 — Bitwise operations](../05_Bitwise/README.md).
