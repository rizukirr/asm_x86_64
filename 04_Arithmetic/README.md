# Part 04 — Arithmetic

## A story first

Imagine you have a tiny worker sitting at a desk. In front of the worker is a row of small labeled cups: one cup is called `rax`, another is called `rbx`, another `rcx`, and so on. These cups can each hold one number.

The worker is amazingly fast, but very simple. To do math, you slip the worker a tiny note that says one thing, like "add the number in cup `rbx` to the number in cup `rax`." The worker reads the note, does it, and is ready for the next one.

In this chapter we learn the notes that do **math** — adding, subtracting, multiplying, dividing.

Quick vocabulary we'll keep using:

- **CPU** = the worker (the chip inside your computer that does all the thinking).
- **Register** = one of the labeled cups on the desk. Tiny, but the worker can grab from them instantly.
- **Instruction** = one of those tiny notes. One step. One command.
- **Two operands** = the note mentions two cups (or one cup and one plain number). The first one is both an input *and* where the answer is written.

## The shape of every math instruction

Every math note we write looks like this:

```
op  dst, src
```

`op` is the name of the operation (like `add`). `dst` is the *destination* — the cup that holds the first number AND will receive the answer. `src` is the *source* — the second number that gets used.

So `add rax, rbx` means **"take what's in `rax`, add what's in `rbx`, put the answer back in `rax`."** In math homework notation: `rax = rax + rbx`. It does **not** put the answer in some new place; it overwrites `rax`.

This is called the *two-operand form* and x86 chips have done it this way since 1978. (That's older than most parents.)

## The basics

| Instruction       | What the worker does                |
| ----------------- | ----------------------------------- |
| `add dst, src`    | `dst = dst + src`                   |
| `sub dst, src`    | `dst = dst - src`                   |
| `inc dst`         | `dst = dst + 1` (just add 1)        |
| `dec dst`         | `dst = dst - 1` (just subtract 1)   |
| `neg dst`         | `dst = -dst` (flip the sign)        |
| `adc dst, src`    | `dst = dst + src + CF` (add with carry-in) |
| `sbb dst, src`    | `dst = dst - src - CF` (subtract with borrow) |

The first five are easy: plus, minus, plus one, minus one, flip the sign.

The last two — `adc` and `sbb` — are for when one cup isn't big enough to hold your number, so you split the number across **two** cups and add them in two steps. The "CF" stands for **Carry Flag**, a tiny yes/no light on the desk that turns on if your addition spilled over. `adc` says "do the add, and also add that carry light in case it was lit from the last step." You won't use these often, but it's nice to know what they're for.

Each instruction works on 8-bit, 16-bit, 32-bit, or 64-bit numbers depending on which register name you use. (A 64-bit number can be very, very large — up to around 18 quintillion.)

## Multiplication

Multiplying is trickier because two big numbers multiplied together can produce a result twice as wide. There are three flavors of `imul` (the "i" stands for *integer signed multiply*, meaning negatives are allowed):

```asm
imul    rcx                     # rdx:rax = rax * rcx   (1-operand form)
imul    rax, rcx                # rax     = rax * rcx   (truncated to 64 bits)
imul    rax, rcx, 10            # rax     = rcx * 10
```

What this actually does, in plain words:

- **First form (`imul rcx`):** the worker grabs whatever is in `rax`, multiplies it by `rcx`, and the answer might be huge — too big for one cup — so it splits the answer across **two** cups: the high half goes in `rdx`, the low half goes in `rax`. That's what `rdx:rax` means: "the pair of cups, with `rdx` on top." You get the full 128-bit answer.
- **Second form (`imul rax, rcx`):** multiply but only keep the bottom 64 bits of the answer. If the answer was too big, the top is silently chopped off. This is what regular programming languages do by default.
- **Third form (`imul rax, rcx, 10`):** multiply `rcx` by the constant 10 and put it in `rax`. Three things mentioned at once.

There's also `mul` (no `i`) for unsigned multiplication — meaning no negative numbers, all numbers treated as positive. It only has the one-operand form: `mul rcx` does `rdx:rax = rax * rcx` as unsigned. For the two- and three-operand multiplies, signed and unsigned actually give the same bottom-64-bits answer, so the assembler just always uses `imul` and saves us trouble.

## Division

Division is the awkward one. `idiv` (signed division) and `div` (unsigned division) take only **one operand**, and they secretly use *two cups together* as the input — `rdx` and `rax` glued side by side to form one giant 128-bit dividend.

```asm
;  Compute  q = a / b,  r = a % b    (signed, 64-bit)
mov     rax, a
cqo                              # sign-extend rax into rdx:rax (rdx = rax<0 ? -1 : 0)
mov     rcx, b
idiv    rcx                      # rax = quotient, rdx = remainder
```

What this actually does, in plain words:

1. Put the number we're dividing (call it `a`) into cup `rax`.
2. `cqo` is a special instruction that **stretches** `a` from one cup into the pair `rdx:rax` so the math is correct for negative numbers. If `a` is positive, `rdx` gets filled with zeros. If `a` is negative, `rdx` gets filled with `1` bits. The name is short for "Convert Quadword to Octword" — quadword means 64 bits, octword means 128.
3. Put the divisor `b` into some cup, here `rcx`.
4. `idiv rcx` then does the division. The **quotient** (the main answer) lands in `rax`, and the **remainder** (what's left over) lands in `rdx`.

For 32-bit division there's `cdq`, and for 16-bit there's `cwd`. Same idea, smaller cups.

For unsigned `div`, you don't sign-extend — you just zero out `rdx`:

```asm
xor     rdx, rdx
div     rcx                      # treats rdx:rax as unsigned
```

Forget the `cqo` or the `xor rdx, rdx` and the CPU will either crash with a "divide error" or give you a wildly wrong answer, because it'll think `rdx` contained the top half of your number and that whatever garbage was there matters.

## FLAGS — what the CPU notices

After almost every math or logic instruction, the CPU flips a few tiny **yes/no lights** on the desk to summarize what just happened. That row of lights is called the **FLAGS register**. We care about four of them most:

| Flag | Name      | Light turns on when…                                          |
| ---- | --------- | ------------------------------------------------------------- |
| `ZF` | Zero      | the result was exactly 0                                      |
| `SF` | Sign      | the result's top bit was 1 (meaning *negative* if signed)     |
| `CF` | Carry     | unsigned overflow (the answer spilled past the cup's edge)    |
| `OF` | Overflow  | signed overflow (the sign of the answer is wrong)             |

Example: `add rax, rbx` where `rax = 0xFFFF_FFFF_FFFF_FFFF` (that's the biggest unsigned 64-bit number — all 1s) and `rbx = 1`:

- The math wraps around. The result stored in `rax` is `0x0000_0000_0000_0000`. So `ZF = 1` (the zero light turns on).
- The "65th bit" that didn't fit got pushed out as a carry. So `CF = 1` (the carry light turns on).
- But if we think of these numbers as signed, that bit pattern actually represents `-1`. And `-1 + 1 = 0`. That's correct math, no signed overflow, so `OF = 0`.

Same instruction, but different lights mean different things depending on whether you meant the number to be signed or unsigned.

`cmp` and `test` (next part) use these flags to decide whether to jump. **Math itself doesn't branch; it just sets flags. Jumps read the flags.** Remember that idea — it shows up everywhere.

## A worked example: `(a + b) * 10 / 3`

Let's compute `(7 + 5) * 10 / 3`. By hand: `12 * 10 = 120`, then `120 / 3 = 40`.

```asm
.intel_syntax noprefix
        .globl  _start
_start:
        mov     rax, 7                  # a
        mov     rcx, 5                  # b
        add     rax, rcx                # rax = a + b = 12
        imul    rax, rax, 10            # rax = 120
        mov     rcx, 3
        cqo                             # sign-extend rax into rdx:rax
        idiv    rcx                     # rax = 120 / 3 = 40, rdx = 0

        # exit(rax & 0xFF) to see the result
        mov     rdi, rax
        mov     rax, 60
        syscall
```

What this actually does, in plain words:

1. Put 7 into cup `rax` and 5 into cup `rcx`.
2. Add them. `rax` now holds 12.
3. Multiply `rax` by 10 using the three-operand `imul`. `rax` is now 120.
4. Put 3 into `rcx`.
5. `cqo` stretches `rax` across `rdx:rax` so division works right.
6. Divide. `rax` ends up as 40 (the quotient), `rdx` as 0 (no remainder).
7. The last three lines ask Linux to exit and use `rax`'s value as the exit code, so we can see the answer from the shell.

Build, run, then check the exit code:

```bash
as -o arith.o arith.s && ld -o arith arith.o
./arith ; echo $?
# => 40
```

Note: the exit status only keeps the bottom 8 bits of the number you pass — Linux only stores 0–255 for exit codes. So this trick only works for small results, but it's a quick way to peek at an answer without writing any printing code.

## Try it

1. Compute `(123 * 456) % 7`. (Hint: `imul`, then `cqo`, then `idiv`. The remainder ends up in `rdx`, so move `rdx` into `rdi` before the `syscall`.)
2. Replace `idiv` with `div` and watch what happens with negative operands. The result will look very wrong because `div` treats everything as unsigned.
3. In gdb, after each arithmetic instruction, run `info registers eflags` and see which lights changed.

## What's next

We've covered the `+`, `-`, `*`, `/` of assembly. [Part 05](../05_Bitwise/README.md) does the other half of the math unit — **bitwise** operations, which work on individual on/off switches inside the number, plus shifts and tricks like `xor reg, reg` that show up in literally every program.
