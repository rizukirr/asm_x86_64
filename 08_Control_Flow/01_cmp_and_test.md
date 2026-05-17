# 08.1 — `cmp`, `test`, and the FLAGS row

## A story: the dashboard of tiny lights

**In plain words:** the CPU has a row of yes/no lights on its desk. Some instructions make those lights blink. Other instructions later peek at the lights to decide what to do.

**The analogy.** Imagine the worker at the desk has a small dashboard above the cups. Each light is a single bulb labeled with a letter: `ZF` (zero), `SF` (sign), `CF` (carry), `OF` (overflow). When the worker does an arithmetic step — even a fake one — they flip the bulbs to describe what happened.

- "The answer came out to zero" → flip `ZF` on.
- "The top bit of the answer was a 1" → flip `SF` on.
- "The subtraction borrowed past the end" → flip `CF` on.
- "Two positive numbers added together looked negative" → flip `OF` on.

That row of bulbs is collectively called the **FLAGS register** (on x86_64 the full 64-bit version is named `RFLAGS`). It is not really a cup you can put a number into; it is a strip of individual single-bit lights, packed into one register so the CPU has somewhere to store them.

**The technical layer.** Every arithmetic-ish instruction (`add`, `sub`, `and`, `or`, `inc`, `dec`, …) updates these flags as a side effect. But often you just want the flags *without* changing your real values. That is why x86 has two dedicated instructions whose only job is to set flags: `cmp` and `test`.

**Check yourself.** If you do `add rax, rbx` and the result is zero, which flag turns on? (Answer: `ZF`. The same flag a later `cmp` would set when two numbers are equal — because `cmp` is literally a subtraction that throws the answer away.)

## `cmp` — subtract and discard

**In plain words:** `cmp a, b` pretends to compute `a - b`, looks at the result long enough to update the lights, and then throws the answer away. Your cups `a` and `b` are untouched.

**The technical layer.**

```asm
cmp     rax, rbx        # like (rax - rbx), but result is discarded
```

After this:
- `ZF = 1` if `rax == rbx` (subtraction produced zero)
- `SF = 1` if the subtraction's top bit was 1 (looked negative)
- `CF` and `OF` record borrow / signed overflow, used by signed/unsigned comparison jumps

The actual register `rax` is unchanged. Only the FLAGS row is touched.

**The analogy.** You and a friend each hold up a number of fingers. You do not actually grab your friend's hand and subtract; you just *imagine* the subtraction long enough to answer "were they the same?" or "was yours bigger?" The fingers stay where they were.

**Gotcha.** `cmp` is not "ask a question" — it is "do a subtraction, but quietly." The question (`==`, `<`, `>`, …) is asked by the *next* instruction, which reads the flags.

## `test` — bitwise AND and discard

**In plain words:** `test a, b` pretends to compute `a & b` (bitwise AND), looks at the result, updates the lights, and discards the answer.

**The technical layer.**

```asm
test    rax, rax        # like (rax & rax), but result is discarded
```

The most common idiom is `test rax, rax` — ANDing a register with itself. A number ANDed with itself is itself, so the result is zero exactly when the register is zero. So `test rax, rax` is the standard "is `rax` zero?" probe.

`test` always clears `CF` and `OF`. Only `ZF` (was the result zero?) and `SF` (was the top bit 1?) carry information.

**The analogy.** `cmp` asks "are these two cups the same?" `test rax, rax` asks "is this one cup empty?" Both leave the cups alone; both only flip the dashboard lights.

**Gotcha.** `test rax, rax` is one byte shorter than `cmp rax, 0`. They are otherwise interchangeable for the zero-check, but real-world assembly and compiler output almost always prefer `test`. Learn to read it as "is this register zero?" rather than as "AND it with itself."

## The whole demo

See [`01_cmp_and_test.s`](01_cmp_and_test.s):

```asm
.intel_syntax noprefix

        .section .data
msg1:   .ascii  "cmp 7,7 -> ZF=1 (equal)\n"
        .equ    msg1len, . - msg1
msg2:   .ascii  "test rax,rax -> ZF=1 (rax was zero)\n"
        .equ    msg2len, . - msg2
msg3:   .ascii  "values are unchanged: rax still 7\n"
        .equ    msg3len, . - msg3

        .section .text
        .globl  _start
_start:
        mov     rax, 7
        mov     rbx, 7
        cmp     rax, rbx        # 7 - 7 = 0 -> ZF=1
        jne     .skip1
        # ... print msg1 ...
.skip1:
        xor     rax, rax        # rax = 0
        test    rax, rax        # 0 & 0 = 0 -> ZF=1
        jnz     .skip2
        # ... print msg2 ...
.skip2:
        mov     rax, 7
        cmp     rax, 9          # rax stays 7 even after cmp
        # ... print msg3 ...
```

**In plain words.** Three little experiments:

1. Put 7 in two cups, compare them. They are equal, so `ZF` lights up, so `jne` (jump-if-not-equal) does **not** jump, so we fall through and print the equal message.
2. Zero out `rax`, then do `test rax, rax`. The AND of zero with zero is zero, so `ZF` lights up, so `jnz` does **not** jump, so we print the zero message.
3. Put 7 back in `rax`, do `cmp rax, 9` (which sets flags as if we computed `7 - 9 = -2`), then immediately print `rax`. The cup still holds 7. Proof that `cmp` does not mutate its operands.

## Build and run

```bash
as -o 01_cmp_and_test.o 01_cmp_and_test.s
ld -o 01_cmp_and_test 01_cmp_and_test.o
./01_cmp_and_test
```

Expected output:

```
cmp 7,7 -> ZF=1 (equal)
test rax,rax -> ZF=1 (rax was zero)
values are unchanged: rax still 7
```

## The five flags you will actually meet

| Flag | Name      | Set when…                                              |
| ---- | --------- | ------------------------------------------------------ |
| `ZF` | Zero      | the result was exactly zero                            |
| `SF` | Sign      | the top bit of the result was 1 (looked negative)      |
| `CF` | Carry     | unsigned subtraction borrowed, or unsigned addition wrapped |
| `OF` | Overflow  | signed addition/subtraction overflowed the type        |
| `PF` | Parity    | low byte of result has an even number of 1-bits (rarely used) |

You will mostly look at `ZF`, then `CF` for unsigned comparisons, then `SF`/`OF` for signed comparisons. The next file (`03_conditional_jumps.md`) shows exactly which flag each jump consults.

**Check yourself.** After `cmp rax, rbx` where `rax = 5` and `rbx = 5`, which flags are set? (Answer: `ZF=1`, `SF=0`, `CF=0`, `OF=0`. The subtraction `5 - 5` is zero, non-negative, no borrow, no overflow.)

## What's next

The flags by themselves are just lights. To turn them into decisions, we need to learn how to jump — first unconditionally (next file, [`02_unconditional_jump.md`](02_unconditional_jump.md)) and then based on each flag (file [`03_conditional_jumps.md`](03_conditional_jumps.md)).
