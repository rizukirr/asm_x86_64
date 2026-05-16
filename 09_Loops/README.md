# Part 09 — Loops

Picture a **treasure hunt** with a stack of clue cards. The very last card on each clue says: "Did you find the chest? If yes, stop. If no, go back to the first clue and try again." That tiny piece of paper — "go back and try again if you haven't found it yet" — is exactly what a loop is. There is no special "loop" thing in the world. There is just normal walking, plus the instruction "if the chest is still missing, walk back to where you started."

Loops are conditional jumps in a circle. The CPU has no native concept of "loop"; you build one by jumping backwards to a label, with a `jcc` controlling whether you keep going.

**Plain words:** The CPU only knows one thing: read the next instruction, then the next, then the next. To make a loop, you write some code, then at the end you put a `jmp` that points backwards to where you started. That makes the CPU read the same chunk of code over and over. To eventually stop, you put a conditional jump (a `jcc`) that says "if we are done, jump out of this circle."

Reminders:

- `rip` is the bookmark in the recipe book. A jump moves the bookmark.
- A backwards jump moves the bookmark to an earlier page; that is what creates the circle.
- FLAGS (the yes/no lights) are set by `cmp`, `test`, and arithmetic operations like `dec`. The conditional jump reads those lights.

## Three classic shapes

Every loop in C boils down to one of three patterns. Same idea each time — jump in a circle until a condition tells you to stop — but the *check* happens in a different place.

### `while`

```c
while (cond) { body; }
```

```asm
.loop:
        ; test cond
        cmp     ..., ...
        j??     .end                    # exit when negation of cond is true
        ; body
        jmp     .loop
.end:
```

Two jumps per iteration in the common case (one conditional, one unconditional). Branch predictors don't mind because the unconditional `jmp` is always taken and trivially predicted.

**What this actually does, in plain words:**

1. Land on the sticky tab `.loop`.
2. Check the condition. If the loop should be done, jump out to `.end`.
3. Otherwise run the body.
4. Unconditionally jump back up to `.loop` to check again.

Picture:

```
.loop: check condition --done--> .end
         |
         not done
         v
       body
         |
         v
       jmp .loop  (back to top)
```

Each lap goes through *two* jumps: the conditional one (which might fire) and the unconditional `jmp` at the bottom. The CPU is fine with this — the unconditional one is trivially predictable.

### `do-while`

```c
do { body; } while (cond);
```

```asm
.loop:
        ; body
        ; test cond
        cmp     ..., ...
        j??     .loop                   # jump back if cond is true
```

**One** jump per iteration — strictly more efficient. Compilers often rotate `while` into `do-while` form when they can prove the loop runs at least once.

**What this actually does, in plain words:** Run the body once, then check the condition, then jump back if you should keep going. Notice we did the body *before* checking. That means a `do-while` always runs at least once, even if the condition is false from the start. Only one jump per lap, so it is the leanest loop shape.

### `for`

```c
for (i = 0; i < n; i++) { body; }
```

```asm
        xor     rcx, rcx                # i = 0
        jmp     .test
.body:
        ; body
        inc     rcx                     # i++
.test:
        cmp     rcx, rdx                # rdx holds n
        jl      .body
```

This is the classic "test at the bottom" form: enter at `.test`, fall into `.body` if the condition holds, increment, jump back. One conditional jump per iteration, with a guard for `n <= 0`.

**What this actually does, in plain words:**

1. `xor rcx, rcx` is the asm idiom for "set the `rcx` cup to zero." (XOR-ing a cup with itself always gives zero, and it is the shortest way to write it.) So we are saying `i = 0`.
2. Jump straight down to `.test` — we want to check the condition *before* running the body, in case `n` was zero and the body should never run.
3. `.body` runs the work, then increments the counter.
4. `.test` compares the counter to `n` and jumps back to `.body` if `i < n`.

This shape is called "test at the bottom" because the conditional jump (the test) lives at the bottom of the loop, jumping backwards. It is the compiler's favorite.

## A worked example: sum 1..N

```asm
.intel_syntax noprefix
        .globl  _start
_start:
        mov     rcx, 10                 # N
        xor     eax, eax                # sum = 0
        xor     rdx, rdx                # i = 0
        jmp     .test
.body:
        add     rax, rdx
        inc     rdx
.test:
        cmp     rdx, rcx
        jle     .body                   # iterate while i <= N

        mov     rdi, rax                # exit(sum)
        mov     rax, 60
        syscall
```

```bash
as -o sum.o sum.s && ld -o sum sum.o
./sum ; echo $?
# => 55     (1 + 2 + ... + 10)
```

**What this actually does, in plain words:** We want `1 + 2 + 3 + ... + 10`.

- Put `10` in the `rcx` cup (this is `N`, the upper limit).
- Empty the `rax` cup; that is where we keep the running total.
- Empty the `rdx` cup; that is our counter `i`.
- Jump to the test first.
- The body adds `i` to the total and bumps `i` up by one.
- The test compares `i` to `N` and loops back as long as `i <= N`.

When the loop ends, `rax` holds `55`. We then ask the operating system to exit with that number as the program's status code. Running the program and printing `$?` shows `55`.

(Side note: program exit codes only go up to 255, so this trick only works for small sums. For bigger numbers you would print with `write` or `printf`.)

## The `loop` instruction (and why it's a trap)

x86 has a single-instruction loop:

```asm
        mov     rcx, 10
.body:
        ; ...
        loop    .body                   # rcx-- ; if rcx != 0, jump
```

Tempting! Short! Self-explanatory!

In practice it's been microcoded badly since the Pentium 4 and is **slower** than the equivalent `dec rcx ; jnz .body`. Modern compilers never emit it. You shouldn't either, except as a curiosity. The historical lesson: not every instruction in the manual is good; some only exist for backwards compatibility.

**Plain words:** Decades ago, Intel added a special "do a whole loop in one instruction" gadget. It decrements `rcx` and jumps if the result is not zero, all in one step. It *looks* like the perfect loop instruction. But Intel's later CPUs handle it slowly — it is faster to use two separate instructions. The single-instruction `loop` survives only so old programs from the 1980s still run. Lesson: a CPU's instruction list is a museum as well as a toolbox. Some exhibits are display-only.

(Aside: there's also `jrcxz` — "jump if `rcx` is zero" — and the same applies. Neat-looking, slow in practice.)

## Loop unrolling and patterns the CPU likes

Compilers and high-performance hand-coders unroll loops to reduce the per-iteration branch overhead:

```asm
.body:
        add     rax, [rsi]
        add     rax, [rsi + 8]
        add     rax, [rsi + 16]
        add     rax, [rsi + 24]
        add     rsi, 32
        sub     rcx, 4
        jnz     .body
```

Four loads per branch instead of one. With SIMD ([Part 15](../15_Where_Next/README.md)), it gets dramatically further. The cost is code size — and irrelevance once data fits in registers anyway. Profile before unrolling by hand.

**What this actually does, in plain words:** Instead of looping "one item per lap," do four items per lap. The branch at the bottom still fires once per lap, but each lap does four times the work. Picture an assembly line where each worker picks up four boxes instead of one. The downside is that your code is bigger (four copies of the instruction), and modern CPUs are so good at predicting branches that the savings are often tiny. Measure before doing this by hand; most of the time the compiler can do it for you.

## Nested loops

There's no special syntax. Just give each loop its own labels:

```asm
        mov     r8, 5                   # outer count
.outer:
        mov     r9, 5                   # inner count
.inner:
        ; do something with (r8, r9)
        dec     r9
        jnz     .inner
        dec     r8
        jnz     .outer
```

Two counters, two branches. Make sure the inner loop's registers don't clobber the outer's — a very common asm bug is "I called a helper from the inner loop and it trashed my outer counter."

**What this actually does, in plain words:** Two loops, one inside the other. The outer loop counter sits in cup `r8`; the inner counter sits in cup `r9`. Each time the outer counter ticks down by one, the inner counter restarts at 5 and ticks all the way down again. Net effect: the inner body runs `5 × 5 = 25` times.

The classic trap: if you call a helper function inside the inner loop, that helper might use cup `r8` for its own work and accidentally trash your outer counter. The fix is either to use a *callee-saved* register (we will meet those in the next chapter) or to push your counter onto the stack before the call and pop it back after.

## Try it

1. Rewrite the sum-1..N example as a `do-while`. Count instructions per iteration; you should save one `jmp` per iteration after the first.
2. Use `loop` instead of `dec`/`jnz` and time both with `time ./prog` after wrapping each in a 10⁹-iteration outer loop. (`loop` will be measurably slower on most chips.)
3. Implement Fibonacci as an asm loop that exits when `F(n) > 200` and returns `n`.

## What's next

We have flow control inside one function-shaped blob of code. To compose anything bigger, we need actual *functions*: `call`, `ret`, and a calling convention. [Part 10](../10_Functions/README.md).
