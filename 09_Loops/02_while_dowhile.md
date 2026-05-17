# 09.2 — `while` and `do-while`: `cmp` + `jcc`

## A story: two ways to enter a swimming pool

**In plain words:** sometimes you want to check *before* jumping in. Sometimes you want to jump first and check *afterwards*. Both are loops; the difference is **where the check lives**.

**The analogy.** Two friends approach a swimming pool.

- **Friend A** dips a toe in *first*. If the water is too cold, they don't get in at all. If it's fine, they swim a lap, climb out, and dip a toe again to decide whether to do another lap. That's a `while` loop: **check first**, then maybe do the body.
- **Friend B** cannonballs straight in. *Then*, while in the pool, they decide whether to do another lap. They always swim at least one lap, no matter what. That's a `do-while` loop: **body first**, then check.

**The technical layer.** Both shapes are built from the same primitives:

- `cmp a, b` — compare two values by subtracting them and updating the FLAGS notebook. It does **not** store the result; it just sets ZF/SF/OF/CF as if you'd done `a - b`.
- `jcc target` — a family of conditional jumps that read FLAGS. `je` (equal), `jne` (not equal), `jl` (less, signed), `jge` (greater-or-equal, signed), `jb`/`ja` (unsigned), and so on.

**Check yourself.** If `rax = 5` and `rbx = 5`, what does `cmp rax, rbx` set ZF to? (Answer: 1. `5 - 5 = 0`, so the zero flag is on, and `je`/`jz` would jump.)

## The two shapes side by side

**`while (cond) { body; }`** in assembly:

```asm
.top:
        cmp     ..., ...
        j??     .end                    # exit when the condition is FALSE
        ; body
        jmp     .top
.end:
```

Two jumps per iteration in the steady state — one conditional (might fire), one unconditional. The unconditional `jmp` is cheap because branch predictors always predict it correctly.

**`do { body; } while (cond);`**:

```asm
.top:
        ; body
        cmp     ..., ...
        j??     .top                    # loop back when the condition is TRUE
```

**One** jump per iteration. Strictly leaner. The body always runs at least once.

**Gotcha.** Notice the conditions are inverted between the two shapes. The `while` form jumps **out** when the condition fails. The `do-while` form jumps **back** when the condition holds. Mix them up and your loop either never runs or never stops.

## The program

We compute `1 + 2 + ... + 10 = 55` using a `do-while`, then print "55\n" using a `while` to convert the number to text. See [`02_while_dowhile.s`](02_while_dowhile.s):

```asm
        # do-while: sum = 0; i = 1; do { sum += i; i++; } while (i <= 10)
        xor     rax, rax                # sum = 0
        mov     rcx, 1                  # i   = 1
.sum_loop:
        add     rax, rcx                # sum += i
        inc     rcx                     # i++
        cmp     rcx, 10
        jle     .sum_loop               # keep going while i <= 10
```

```asm
        # while: while (rax != 0) { *--rdi = '0' + rax%10; rax /= 10; }
.cvt_test:
        test    rax, rax
        jz      .cvt_done               # exit when rax == 0
        xor     rdx, rdx
        div     rbx                     # rax = rax/10, rdx = rax%10
        add     dl, '0'
        dec     rdi
        mov     [rdi], dl
        jmp     .cvt_test
.cvt_done:
```

## Build and run

```bash
as -o 02.o 02_while_dowhile.s
ld -o 02 02.o
./02
# => 55
```

## Dissecting it

### `xor rax, rax` and `xor rdx, rdx`

**In plain words:** standard idiom for "set this register to zero." Shorter encoding than `mov rax, 0`. Always read it as "zero this register."

### The `do-while` accumulator

**In plain words:** start `sum` at 0 and `i` at 1. Each lap: add `i` to `sum`, bump `i`, then check whether `i` is still `<= 10`. If so, loop back. After the loop, `rax` holds 55.

**The technical layer.** `cmp rcx, 10` computes `rcx - 10` to set flags. `jle` ("jump if less or equal", **signed**) reads those flags and jumps when `rcx <= 10`. Because we use signed compare (`jle`/`jl`/`jg`/`jge`), this is correct for negative counters too — though we never go negative here.

**Gotcha.** Signed vs unsigned compare matters. `jle` is the signed version; the unsigned cousin is `jbe` ("below or equal"). For loop counters that you know are positive, either works, but mixing them is a classic bug. Pick signed for normal integers, unsigned for sizes/addresses.

### The `while` digit-converter

**In plain words:** the number is in `rax`. We carve off its last decimal digit using division, write it into a buffer working right-to-left, then divide `rax` by 10. Keep going until `rax` hits zero.

**The technical layer.** `div rbx` on x86_64 is a 128-bit-by-64-bit unsigned divide. It reads `rdx:rax` (a 128-bit dividend made of `rdx` as high and `rax` as low) and `rbx` (the divisor). After it runs, `rax` holds the quotient and `rdx` holds the remainder. That's why we `xor rdx, rdx` first — to clear the high half of the dividend.

**Why `test rax, rax` instead of `cmp rax, 0`?** `test a, a` ANDs `a` with itself (the result is just `a`) and sets flags — and the encoding is **shorter** than `cmp a, 0`. So `test rax, rax ; jz .done` is the idiomatic "is this register zero?" check.

### Which shape should you choose?

**In plain words:** if you can prove the loop runs at least once, prefer `do-while` — it's one jump per iteration leaner. Otherwise use `while`, which guards against zero iterations.

**The technical layer.** Real compilers (gcc, clang) will often **rotate** a `while` into a `do-while` when they can statically prove the loop body executes at least once. The rotation looks like:

```c
// before
while (cond) body;
// after
if (cond) do body; while (cond);
```

That `if` guard outside the loop costs one comparison once, but the hot inner loop is now one jump leaner per iteration. This pattern is so common it has a name: **loop rotation** or **loop inversion**.

**Check yourself.** In the sum-loop above, could we rotate it into a `while`? (Yes — but you'd need to guard against `N=0`. Try writing both forms.)

## Try it

1. Rewrite the sum loop as a `while` (test at the top). Use `cmp rcx, 10 ; jg .end` to exit. Count instructions per iteration; you should see one extra `jmp`.
2. Change `jle` to `jl` and see whether the sum becomes 45 (1..9) or 55 (1..10). Make sure you understand why.
3. Replace the conversion loop with a `do-while` and add an explicit guard for the special case where `rax = 0` (which should print `"0"`).

## What's next

You've now seen the three shapes every loop reduces to: counted, while, do-while. Next, a curious one-instruction loop that *looks* perfect and turns out to be a trap. → [03_loop_instruction.md](03_loop_instruction.md)
