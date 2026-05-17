# 08.3 — Conditional jumps (`jcc`)

## A story: jumping only when the right light is on

**In plain words:** a conditional jump is a `jmp` that first peeks at one or two of the FLAGS lights. If the lights are in the right state, it jumps. Otherwise it does nothing and the CPU keeps reading the next instruction.

**The analogy.** The worker holds the bookmark over the new page, glances up at the dashboard, and asks "is the zero light on?" If yes, they drop the bookmark there. If no, they put it back and just read the next line as usual.

**The technical layer.** The instructions are spelled `jcc`, where `cc` is a two-letter **condition code**: `je`, `jne`, `jl`, `jg`, `jb`, `ja`, `jz`, `js`, and so on. Each one consults a specific combination of `ZF`, `SF`, `CF`, and `OF`. The pattern in real code is always:

1. A flag-producing instruction (`cmp`, `test`, or any arithmetic).
2. Immediately followed by a `jcc` that reads those flags.

```asm
cmp     rax, rbx
je      .equal          # jump if ZF=1
```

**Check yourself.** If a hundred instructions happened between `cmp` and `je`, would `je` still work? (Answer: only if none of those instructions touched the flags. In practice you write `cmp` and the matching `jcc` right next to each other, exactly because so many ordinary instructions stomp on the flags.)

## Two families: signed and unsigned

**In plain words:** the bits `1111…1111` can mean either "the unsigned number 18,446,744,073,709,551,615" or "the signed number −1." Same bits, two readings. The CPU does not know which you mean — *you* tell it by picking the right conditional jump.

**The analogy.** Imagine the cup holds a token that is red on one side and blue on the other. If you flip the token red side up, you read it as "−1." If you flip it blue side up, you read it as "a huge positive number." The token is the same; the question is which side you decided to look at.

**The technical layer.** After `cmp a, b`:

### Signed comparisons (use **L**ess / **G**reater)

| Mnemonic | C meaning | Flags consulted     |
| -------- | --------- | ------------------- |
| `je`     | `==`      | `ZF=1`              |
| `jne`    | `!=`      | `ZF=0`              |
| `jl`     | `<`       | `SF ≠ OF`           |
| `jle`    | `<=`      | `ZF=1` or `SF ≠ OF` |
| `jg`     | `>`       | `ZF=0` and `SF=OF`  |
| `jge`    | `>=`      | `SF = OF`           |

### Unsigned comparisons (use **B**elow / **A**bove)

| Mnemonic | C meaning | Flags consulted     |
| -------- | --------- | ------------------- |
| `je`     | `==`      | `ZF=1`              |
| `jne`    | `!=`      | `ZF=0`              |
| `jb`     | `<`       | `CF=1`              |
| `jbe`    | `<=`      | `CF=1` or `ZF=1`    |
| `ja`     | `>`       | `CF=0` and `ZF=0`   |
| `jae`    | `>=`      | `CF=0`              |

**You do not need to memorize the flag columns.** Memorize the letters:

- **L**ess, **G**reater, **E**qual → signed.
- **B**elow, **A**bove, **E**qual → unsigned.
- `je`/`jne` work for both (equality does not care about signedness).

### After `test` (only `ZF` and `SF` matter)

| Mnemonic | Asks                                    |
| -------- | --------------------------------------- |
| `jz`     | result was zero (same opcode as `je`)   |
| `jnz`    | result was nonzero (same opcode as `jne`) |
| `js`     | result was negative (top bit set)       |
| `jns`    | result was non-negative                 |

`jz` and `je` are literally the same byte. Two mnemonics, one instruction. Use whichever reads better in context: `jz` after `test`, `je` after `cmp`.

## The classic trap: signed vs unsigned

**In plain words:** the same `cmp` instruction sets the flags for *both* worlds at once. Picking `jl` (signed) versus `jb` (unsigned) determines which world you live in.

Consider the bit pattern `0xFFFF…FFFF` (64 one-bits) and the number `1`:

- Read signed: the first is `−1`, so `−1 < 1` — **`jl` is taken**.
- Read unsigned: the first is the largest possible 64-bit number, so it is `> 1` — **`ja` is taken**.

Same `cmp`. Same flags. Two opposite branches. Using `jl` on values that are conceptually unsigned (sizes, indices, addresses) is one of the most common bugs in handwritten assembly.

## The whole demo

See [`03_conditional_jumps.s`](03_conditional_jumps.s):

```asm
        # signed comparison: -1 < 1
        mov     rax, -1
        mov     rbx, 1
        cmp     rax, rbx
        jnl     .not_signed_less        # jnl == jge
        # ... print "signed: -1 < 1 -> jl taken" ...
.not_signed_less:

        # unsigned comparison: 0xFFFF...FFFF > 1
        mov     rax, -1                 # same bits as before
        mov     rbx, 1
        cmp     rax, rbx
        jna     .not_unsigned_above
        # ... print "unsigned: -1 (as bits) > 1 -> ja taken" ...
.not_unsigned_above:

        # equality
        mov     rax, 42
        mov     rbx, 42
        cmp     rax, rbx
        jne     .not_equal
        # ... print "equality: 42 == 42 -> je taken" ...
.not_equal:
```

**In plain words.** Three little experiments demonstrating that the *same* `cmp rax, rbx` with `rax = -1, rbx = 1` is "less than" in signed land but "greater than" in unsigned land. The third experiment shows that `je` does not care which land you live in — equality is equality.

Note the pattern in the code: we test the *negation* of what we want, and use the jump to *skip over* the body. That is the canonical asm shape for "if (condition) { body }":

```
        cmp     ...
        jNOT_cond  .after_body
        # body
.after_body:
```

If you want to translate `if (a < b)`, you write `cmp a, b; jge .skip` — jumping when the condition is *false* to hop over the body.

## Build and run

```bash
as -o 03_conditional_jumps.o 03_conditional_jumps.s
ld -o 03_conditional_jumps 03_conditional_jumps.o
./03_conditional_jumps
```

Expected output:

```
signed: -1 < 1  -> jl taken
unsigned: -1 (as bits) > 1 -> ja taken
equality: 42 == 42 -> je taken
```

## Translating `if / else`

```c
if (a == b) { f(); } else { g(); }
h();
```

becomes:

```asm
        cmp     rax, rbx
        jne     .else
        call    f
        jmp     .endif
.else:
        call    g
.endif:
        call    h
```

The mechanical recipe: **invert the C condition, use a `jcc` with the inverted condition, and jump over the "then" body to the `else` label.** That is the shape every compiler emits for an `if/else` before the optimizer gets clever.

**Gotcha.** Forgetting the `jmp .endif` after the "then" branch is the most common bug. Without it, control falls straight from the end of `f` into `.else:` and calls `g` too.

## Check yourself

1. After `cmp rax, rbx` with `rax = 5, rbx = 10`, which is taken: `jl` or `jg`? (Answer: `jl`. `5 < 10` signed.)
2. After `cmp rax, rbx` with the same values, would `jb` also be taken? (Answer: yes — `5 < 10` unsigned too. Only when one operand has its high bit set do signed and unsigned diverge.)
3. What is the asm for `if (x != 0) { f(); }`? (Answer: `test rax, rax; jz .skip; call f; .skip:`. The `test` is the shorter, idiomatic zero-check.)

## What's next

We have seen how to *branch* — pick one of two paths. Sometimes you do not want a branch at all; you just want to pick one of two values. That is the job of `cmov`, the branchless conditional move — see [`04_cmov.md`](04_cmov.md).
