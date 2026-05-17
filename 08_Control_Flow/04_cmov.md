# 08.4 — `cmov`: the branchless conditional move

## A story: the worker who always grabs the cup

**In plain words:** sometimes you do not want to branch ("go here vs go there"); you just want to pick one of two values into a cup. `cmov` does exactly that: copy `src` to `dst` *only if* a certain flag condition holds — but unlike a jump, no jumping happens.

**The analogy.** Instead of two routes through the recipe, the worker walks one straight line. At one step they hold up a candidate value, glance at the dashboard, and either copy it into the destination cup or just put it down. Either way they walk on to the next step. There is no branch in the path.

**The technical layer.** `cmovcc dst, src` reads exactly like a normal `mov`, but the copy is gated by the same flag conditions as a `jcc`. The suffixes mirror the jump family one-to-one:

| Family             | Examples                                 |
| ------------------ | ---------------------------------------- |
| Equality           | `cmove` / `cmovne`                       |
| Signed compare     | `cmovl`, `cmovle`, `cmovg`, `cmovge`     |
| Unsigned compare   | `cmovb`, `cmovbe`, `cmova`, `cmovae`     |
| Zero / sign        | `cmovz`, `cmovnz`, `cmovs`, `cmovns`     |

If you know `jl`, you know `cmovl` — same condition, different action.

**Check yourself.** What does `cmove rax, rbx` do when `ZF=0`? (Answer: absolutely nothing visible. The destination is unchanged. The CPU still reads `rbx`, decodes the instruction, and decides "no, condition not met." But `rax` keeps its old value.)

## Why bother? Branch prediction

**In plain words:** modern CPUs guess which way every jump will go before they actually know. When they guess wrong, they have to throw away work and start over. `cmov` has no jump, so there is nothing to guess.

**The technical layer.** A modern x86 CPU pipelines dozens of instructions ahead. When it hits a `jcc`, it has to predict the outcome to keep the pipeline fed. The predictor is very accurate on patterned data (always-taken loops, etc.) but very bad on random data (a `cmp` against an unpredictable input). A mispredict costs roughly 15–20 cycles — sometimes the entire body of the branch you were trying to skip would have been cheaper.

`cmov` eliminates the question. The CPU computes both possibilities' inputs unconditionally and picks one. For tiny bodies like `min`/`max`/`abs`/`select`, this is usually faster than a (potentially mispredicted) branch.

**Gotcha.** "Branchless is always faster" is **false**. If the body of the branch is large or expensive, evaluating both paths is wasteful. `cmov` shines for tiny, data-dependent selections. Compilers know the tradeoff and pick for you when you write a ternary `a < b ? a : b`.

## The whole demo: branchless `min`

See [`04_cmov.s`](04_cmov.s). We compute `min(7, 3)` without any branch in the hot path:

```asm
        mov     rax, 7          # a
        mov     rbx, 3          # b
        cmp     rax, rbx        # compare a, b -> flags
        cmovg   rax, rbx        # if a > b (signed), rax = b
                                # now rax = min(a, b) = 3
```

**In plain words.** Start by assuming the answer is `a` (so put it in `rax`). Compare `a` and `b`. If it turns out `a > b`, overwrite `rax` with `b`. Either way, `rax` ends up holding the smaller of the two. There is no `jmp`, no `jcc`. Just a `cmp` and a `cmov`.

The rest of the program turns the digit into ASCII and prints it, so you can see the result:

```asm
        add     al, '0'         # turn the digit (0..9) into its ASCII byte
        lea     rcx, [rip + out]
        mov     [rcx], al       # store into the output buffer
        # ... write syscall ...
```

`out` was initialized to `"X\n"` in `.data`. We overwrite the `X` byte with the actual digit before printing.

## Build and run

```bash
as -o 04_cmov.o 04_cmov.s
ld -o 04_cmov 04_cmov.o
./04_cmov
```

Expected output:

```
min(7, 3) = 3
```

## The "always reads its source" gotcha

**In plain words:** `cmov` is not really an `if`. It is an "always look at the source value, but only sometimes write it to the destination." The CPU performs the read no matter what.

**The technical layer.** This matters when the source is memory:

```asm
cmov?? rax, [rbx]
```

If `rbx` points to an invalid address, the CPU will fault on the load **even if the condition is false**. So you cannot use `cmov` as a poor man's null-check:

```asm
        ; BUG: still faults if rbx is NULL!
        test    rbx, rbx
        cmovnz  rax, [rbx]
```

A real `if` would skip the load entirely; `cmov` does not. Use `cmov` with **register sources** or with memory you have already proven is safe to read. For null-checked loads, you still need a real `jcc`.

**Check yourself.** Why does the demo use `cmovg rax, rbx` instead of `cmovg rax, [some_memory]`? (Answer: register sources can never fault. We pre-loaded `rbx` with the candidate value, so the `cmov` is guaranteed safe.)

## Common branchless idioms

Once you know `cmov` exists, you start seeing these everywhere:

```asm
        ; rax = min(rax, rbx) (signed)
        cmp     rax, rbx
        cmovg   rax, rbx

        ; rax = max(rax, rbx) (signed)
        cmp     rax, rbx
        cmovl   rax, rbx

        ; rax = (rcx == 0) ? rbx : rdx
        test    rcx, rcx
        mov     rax, rdx
        cmovz   rax, rbx
```

Each is a `cmp` (or `test`) to produce flags, then a `cmov` to commit a value. Read them aloud: "compare; conditionally move."

## Try it

1. Change `cmovg` to `cmovl` in `04_cmov.s` and rebuild. What does the program print now? (Hint: you turned `min` into `max`.)
2. Rewrite the same `min` with a `jcc` instead. Disassemble both with `objdump -d -M intel`. Notice the `cmov` version is shorter and has no jump.
3. Write a branchless absolute value: given `rax` possibly negative, produce `|rax|`. Hint: copy `rax` to `rbx`, negate `rbx`, `test rax, rax`, then `cmovs rax, rbx`.

## What's next

That is the complete control-flow toolkit: `cmp`/`test` to produce flags, `jmp` to move unconditionally, `jcc` to move conditionally, `cmov` to pick a value without a branch. Everything else — `if`, `while`, `for`, `switch`, ternary — is built from these four pieces.

Next up: [Part 09 — Loops](../09_Loops/README.md). We put conditional jumps to work and see why the tempting-looking `loop` instruction is almost never used in real code.
