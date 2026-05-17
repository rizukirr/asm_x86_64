# Topic 01 — `add`, `sub`, `inc`, `dec`, `neg`

## A story: the worker with the cups

**In plain words:** the CPU does math by reading short notes that say things like "add the number in this cup to the number in that cup." That's it. No expressions, no parentheses, no order of operations — just one tiny step per note.

**The analogy.** Picture a worker at a desk with a row of labeled cups in front of them: `rax`, `rbx`, `rcx`, and so on. Each cup holds exactly one number. You hand the worker one note at a time. The worker reads it, does the one thing it says, and waits for the next note.

A math note always looks like:

```
op  dst, src
```

`op` is the operation (`add`, `sub`, …). `dst` is the **destination** — the cup that holds the first input *and* will receive the answer. `src` is the **source** — the second input. So `add rax, rbx` means: take what's in `rax`, add what's in `rbx`, write the sum back into `rax`. In plain math notation, `rax = rax + rbx`.

**The technical layer.** This is called the **two-operand form**, and x86 has used it since 1978. The destination is overwritten — there is no third cup for the result. If you wanted to keep the old value of `rax`, you had to save it somewhere first.

**Gotcha.** The destination is *always* clobbered. There is no `add rcx, rax, rbx` (three operands) for plain integer addition. If you're used to higher-level languages where `c = a + b` leaves `a` and `b` alone, this will feel cramped at first.

## The five basic notes

**In plain words.** Five small instructions cover the bread and butter of integer math.

| Instruction    | What the worker does                |
| -------------- | ----------------------------------- |
| `add dst, src` | `dst = dst + src`                   |
| `sub dst, src` | `dst = dst - src`                   |
| `inc dst`      | `dst = dst + 1` (just add 1)        |
| `dec dst`      | `dst = dst - 1` (just subtract 1)   |
| `neg dst`      | `dst = -dst` (flip the sign)        |

**The technical layer.** `inc` and `dec` are not just shorthands for `add dst, 1` / `sub dst, 1` — they are their own instructions, encoded in fewer bytes. There is one subtle difference: `inc` and `dec` do **not** touch the carry flag (`CF`); only the zero, sign, and overflow flags. That can matter inside tight loops that pre-compute a carry and then increment a pointer between adds. For everyday code, it's invisible.

`neg dst` flips the sign by computing `0 - dst`. So `neg rax` where `rax = 5` leaves `rax = -5`. If `rax` was already negative, it becomes positive.

**Gotcha.** `neg` of the most-negative 64-bit number (`0x8000000000000000`, which represents -2^63) gives back itself — there is no positive 2^63 in 64 bits, so the result wraps. The overflow flag (`OF`) lights up to tell you.

## The "carry-in" cousins

**In plain words:** sometimes a number is too big to fit in one cup, so you split it across two cups and add them in two steps. `adc` and `sbb` are the helpers for the second step.

```
adc dst, src    # dst = dst + src + CF   (add with carry-in)
sbb dst, src    # dst = dst - src - CF   (subtract with borrow-in)
```

**The analogy.** Imagine adding two 4-digit numbers by hand: `9876 + 1234`. You add the right pair of digits, write the result digit, and if the answer was 10 or more you *carry the 1* into the next column. `adc` is exactly that. The "carry light" on the desk (`CF`) is the 1 you're carrying.

**The technical layer.** On x86_64 one cup holds 64 bits, which fits numbers up to about 18 quintillion — so most programs never need `adc`. You only reach for it when implementing big-integer math (cryptography, arbitrary-precision libraries) or when working with 32-bit registers and adding numbers that need 64 bits of precision.

**Don't panic.** You can skip `adc`/`sbb` for now. We're flagging them so you recognize them in other people's code.

## Widths: same instruction, different cup sizes

**In plain words:** each register name implies a width. `rax` is 64 bits, `eax` is the bottom 32 bits of `rax`, `ax` the bottom 16, `al` the bottom 8. The same `add` instruction quietly becomes 8-, 16-, 32-, or 64-bit math depending on which name you use.

```asm
add al, 1      # 8-bit add
add ax, 1      # 16-bit add
add eax, 1     # 32-bit add (zero-extends top half of rax — see Part 02)
add rax, 1     # 64-bit add
```

**Gotcha.** Mixing widths in the same instruction is illegal: `add rax, ebx` won't assemble. The two operands must agree on size (with a few special exceptions like `movsx`/`movzx` which exist precisely because plain `mov` won't mix widths).

## The runnable example

**In plain words:** we'll compute a small chain of these instructions and print the result, so you can actually *see* the math happening.

Goal: start at 10, add 5, subtract 1, increment, decrement, negate twice (so we're back where we were), then increment once more. Final answer: 15.

See [`01_add_sub_inc_dec_neg.s`](01_add_sub_inc_dec_neg.s). The interesting lines are:

```asm
mov     rax, 10                 # rax = 10
mov     rbx, 5                  # rbx = 5
add     rax, rbx                # rax = 15
sub     rax, 1                  # rax = 14
inc     rax                     # rax = 15
dec     rax                     # rax = 14
neg     rax                     # rax = -14
neg     rax                     # rax = 14
inc     rax                     # rax = 15   final value
```

The rest of the file is a small **itoa** (integer-to-ASCII) routine that converts the number to printable digit characters and feeds them to the `write` syscall. We'll explain itoa properly when we get to loops; for now treat it as a "print this integer" black box.

## Build and run

```bash
as -o /tmp/t.o 01_add_sub_inc_dec_neg.s && ld -o /tmp/t /tmp/t.o && /tmp/t
# => 15
```

If you see `15` on its own line, your worker is moving cups correctly.

## Check yourself

1. After `mov rax, 3` then `sub rax, 10`, what does `rax` hold? (Hint: subtraction can go negative. In two's-complement 64-bit, -7 is the bit pattern `0xFFFFFFFFFFFFFFF9`.)
2. What's the difference between `neg rax` and `sub rax, rax`? (Answer: `neg rax` flips the sign of whatever was there. `sub rax, rax` always produces 0, because anything minus itself is 0.)
3. Why might `inc rax` be preferred over `add rax, 1`? (Answer: fewer bytes of encoding. The CPU does the same math either way.)

## Next

[Topic 02 — `mul` and `imul`](02_mul_imul.md): multiplication, including why the full result needs *two* cups to fit.
