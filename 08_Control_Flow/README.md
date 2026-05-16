# Part 08 — Control Flow

Imagine a **choose-your-own-adventure book**. Most of the time you read pages in order: page 1, page 2, page 3. But every few pages the book says something like "if you opened the door, turn to page 47; if you ran away, turn to page 12." Suddenly you are not reading in order anymore. You are jumping around based on a choice.

The CPU's normal behavior is exactly like reading a book in order. It reads one instruction, then the next, then the next. **Control flow** is the name for everything that breaks this orderly reading: jumping to a different page, picking one of two paths, calling a helper chapter and coming back. Without control flow, programs would just be a straight line. With it, they can make decisions.

A quick reminder of our cast of characters:

- **CPU** = the fast worker sitting at a desk.
- **Registers** = labeled cups on the desk for holding numbers right now.
- **Memory** = numbered shelves further away from the desk.
- **Instruction pointer (`rip`)** = a bookmark in the recipe book that says "this is the next step I will do."
- **FLAGS** = a row of tiny yes/no lights on the desk. After each compare or math step, these lights blink on or off to remember things like "was the result zero?" or "was it negative?"

In this chapter we learn the building blocks: **jumps** (moving the bookmark) and **conditional jumps** (moving the bookmark *only if* a yes/no light is on). With those two tools alone we can build every `if`, `while`, `for`, and `switch` you have ever seen in a high-level language.

## Unconditional jump

```asm
jmp     .label
```

`jmp` sets `rip` to the address of `.label`. No flags involved, no condition. It's a `goto`.

**What this actually does, in plain words:** "Move my bookmark to the page named `.label`. Forget where you were. The next instruction I do is whatever is written at that label." There is no question asked, no condition checked. It always happens.

Labels starting with `.` are **local** to the file/function in GNU `as` — useful so labels don't collide with each other across functions. Plain labels are global.

Think of a *label* as a sticky tab you put on a page of the book. The dot in front (`.skip` instead of `skip`) is a hint to the assembler that says "this sticky tab is private — don't let other files see it." That way two different functions can both have a `.loop` label without confusing each other.

## `cmp` and `test`: producing flags

```asm
cmp     a, b            # like (a - b), but discard the result; keep the flags
test    a, b            # like (a & b), but discard the result; keep the flags
```

Two **non-destructive** operations whose only purpose is to set FLAGS. After:

```asm
cmp     rax, rbx
```

…you can ask "was `rax == rbx`?" (`ZF=1`), "`rax < rbx`?" (depends on signed/unsigned interpretation), and so on. The actual comparison is just a subtraction; nothing else is left behind.

**What this actually does, in plain words:** `cmp` pretends to subtract one number from the other, just to see what happens. It does *not* save the answer anywhere — the numbers in your cups stay exactly as they were. The only thing it changes is the row of yes/no lights (the FLAGS). For example, if the two numbers were equal, the subtraction would have given zero, so the "result was zero" light (called `ZF`, the Zero Flag) lights up. Later instructions can peek at that light to decide what to do next.

`test rax, rax` is the idiomatic "is `rax` zero?" — `rax & rax == 0` iff `rax == 0`, and `test` doesn't disturb `rax`. Use this instead of `cmp rax, 0` (one byte shorter).

**Plain words:** `test rax, rax` is the asm trick for asking "is this cup empty?" (empty meaning zero). `&` is the bitwise AND operation; a number ANDed with itself is itself, so the result is zero only when the number was zero. Same answer as `cmp rax, 0` but a tiny bit smaller in the final binary.

## Conditional jumps

After a flag-setting instruction, you branch with a `jcc` ("jump if condition"). There are a lot of mnemonics, but they collapse into two groups:

**Plain words:** A *conditional jump* is "skip to page X, but only if a particular yes/no light is in a particular state." That is, "if `cake == brown`, skip to page 20; otherwise just keep reading." The light it checks was set by the most recent `cmp` or `test` or math operation. So the pattern in asm is always: do a `cmp`, then immediately do a `jcc`.

The `cc` part of `jcc` stands for "condition code" — there are many of them, one per question you might want to ask.

### After `cmp a, b` — signed comparisons

| Asm    | C     | Meaning              | Flags read           |
| ------ | ----- | -------------------- | -------------------- |
| `je`   | `==`  | equal                | `ZF=1`               |
| `jne`  | `!=`  | not equal            | `ZF=0`               |
| `jl`   | `<`   | signed less          | `SF≠OF`              |
| `jle`  | `<=`  | signed less-or-equal | `ZF=1 or SF≠OF`      |
| `jg`   | `>`   | signed greater       | `ZF=0 and SF=OF`     |
| `jge`  | `>=`  | signed greater-or-eq | `SF=OF`              |

### After `cmp a, b` — unsigned comparisons

| Asm    | C     | Meaning              | Flags read   |
| ------ | ----- | -------------------- | ------------ |
| `je`   | `==`  | equal                | `ZF=1`       |
| `jne`  | `!=`  | not equal            | `ZF=0`       |
| `jb`   | `<`   | unsigned below       | `CF=1`       |
| `jbe`  | `<=`  | unsigned below-or-eq | `CF=1 or ZF=1`|
| `ja`   | `>`   | unsigned above       | `CF=0 and ZF=0`|
| `jae`  | `>=`  | unsigned above-or-eq | `CF=0`       |

You don't have to memorize the flag bits — just remember **L/G/E for signed, B/A/E for unsigned, with `jne`/`je` as the universal equality tests.** The most common mistake in handwritten asm is using `jl` (signed) on values that are unsigned (like addresses or sizes), or vice versa. Picking the wrong one only fails on values near `INT64_MAX` — i.e., almost never in tests and immediately in production.

**Plain words about signed vs unsigned:** A *signed* number can be negative or positive (like `-5` or `+5`). An *unsigned* number is always zero or positive (like `0`, `1`, `2`, …, `huge`). The CPU stores them in the same kind of cup; only the instruction you use decides which way to read the bits. For "are these whole numbers like marbles you can count?" use unsigned (`jb`, `ja`). For "could this be negative, like temperature?" use signed (`jl`, `jg`). Mixing them up is a real bug that programmers have shipped to production for decades.

The letters help you remember: **L**ess, **G**reater, **E**qual (signed). **B**elow, **A**bove, **E**qual (unsigned). Different letters because they are different questions.

### After `test`

`test` always clears `CF` and `OF`, so only `ZF` and `SF` are interesting:

| Asm    | Meaning           |
| ------ | ----------------- |
| `jz`   | result was 0      |
| `jnz`  | result was nonzero|
| `js`   | result was negative (top bit set) |
| `jns`  | result was non-negative |

`jz` and `je` are literally the same instruction (same opcode, different mnemonic). Same for `jnz`/`jne`. Use whichever reads better.

**Plain words:** After a `test`, the only useful lights left on the dashboard are "was it zero?" and "was the top bit a 1?" (which, in signed land, means "was it negative?"). `jz` reads "jump if zero," `jnz` reads "jump if not zero." `je` and `jz` are the exact same machine instruction — two names for one thing, the way "soda" and "pop" can mean the same drink.

## Translating `if`

```c
if (a == b) {
    f();
} else {
    g();
}
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

**What this actually does, in plain words:**

1. Compare the numbers in `rax` and `rbx`.
2. If they are **not** equal, jump down to the `.else` sticky tab. (Notice we test the *opposite* of what the C code asked. C says "if equal, do f"; asm says "if not equal, skip f.")
3. Otherwise just fall through and call `f`. After calling `f`, jump over the `else` part to `.endif`.
4. At `.else` we call `g`.
5. Either path ends up at `.endif`, where we call `h`. Both branches merge here.

ASCII picture of the flow:

```
        cmp rax, rbx
            |
            v
        equal? -----no----> .else: call g ----+
            |                                  |
           yes                                 |
            |                                  |
            v                                  |
        call f                                 |
            |                                  |
            v                                  |
         jmp .endif --------------------------+
                                              |
                                              v
                                           .endif: call h
```

The pattern: **test the negation of the C condition, and jump over the "then" branch.** That's the canonical shape. Some compilers reorder for branch prediction or code locality, but the structure is the same.

## Translating `if (...) { ... }` (no else)

```c
if (a < b) {
    f();
}
g();
```

```asm
        cmp     rax, rbx
        jge     .skip                   # negation of < is >=
        call    f
.skip:
        call    g
```

**What this actually does, in plain words:** Compare the two numbers. The C code says "do `f` if `a < b`." The asm says the opposite: "if `a >= b`, skip over `f`." Either way, we always call `g` afterwards. Notice again the trick — when there is no `else`, you just need one conditional jump that hops over the body.

## `cmov`: branchless conditional move

Sometimes you want a value, not a branch:

```c
x = (a < b) ? a : b;
```

```asm
        mov     rax, rcx                # rax = a
        cmp     rcx, rdx                # compare a, b
        cmovge  rax, rdx                # if a >= b, rax = b
```

`cmov??` copies `src` to `dst` **only if** the flag condition is true. No branch, no mispredict, no flushing the pipeline. Compilers reach for `cmov` for tight ternaries and `min`/`max`. The mnemonic suffixes mirror `jcc` exactly (`cmovl`, `cmovg`, `cmovne`, …).

**What this actually does, in plain words:** `cmov` is short for "conditional move." It is like saying to the worker, "look at the yes/no lights; if the right ones are lit, copy this cup into that cup; if not, do nothing." It is a tiny `if` that does not involve any jumping around. Modern CPUs do a clever thing called *branch prediction* — they guess which way a jump will go before they know — and they get penalized when they guess wrong. `cmov` removes the jump, so there is nothing to guess wrong about. For little "pick the smaller of two numbers" jobs this is faster.

The catch: `cmov` always reads its source. If the source is a memory address that might fault, you cannot use `cmov` to avoid the load — the load happens regardless of the condition.

**Plain words on the catch:** A real `if` would never look at a value when the condition is false. `cmov` always grabs the source value first, *then* decides whether to keep it. So if the source is a memory address that might be invalid (say, pointing to a forbidden shelf), `cmov` still tries to read that shelf and crashes the program. Use `cmov` only for safe sources like registers or definitely-valid memory.

## Try it

1. Write a tiny program that exits with `1` if `argc > 1` and `0` otherwise. (Tip: `argc` is at `[rsp]` on entry to `_start`.)
2. Replace one `jcc` chain with a `cmov` equivalent. Disassemble both with `-O0` and `-O2`; observe which the compiler prefers.
3. Make a mistake on purpose: use `jl` instead of `jb` to compare two unsigned values where one is `(uint64_t)-1`. Notice the bug; this is exactly the class of bug `signed_compare(size_t, size_t)` warnings exist to catch.

## What's next

[Part 09](../09_Loops/README.md) puts conditional jumps to work: `for`, `while`, `do-while`, and how the `loop` instruction looks tempting but isn't actually used.
