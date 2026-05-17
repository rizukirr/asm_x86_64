# Part 08 — Control Flow

## A story: the choose-your-own-adventure book

**In plain words:** by default the CPU reads instructions in order, like reading a book one page at a time. **Control flow** is everything that breaks that orderly reading — jumping to a different page, picking one of two paths, calling a helper chapter and coming back.

**The analogy.** Picture a choose-your-own-adventure book. Most of the time you read pages in sequence. But every few pages the book says "if you opened the door, turn to page 47; if you ran away, turn to page 12." Suddenly you are not reading in order anymore. You are jumping based on a choice.

The CPU's "current page" is a register called `RIP` (the instruction pointer). Control-flow instructions are exactly the ones that mess with `RIP`. The decisions are based on a tiny row of yes/no lights called **FLAGS** that the most recent `cmp` / `test` / arithmetic step blinked on or off.

**The four pieces we will learn:**

1. **`cmp` and `test`** — produce flags without changing your data.
2. **`jmp`** — move the bookmark unconditionally.
3. **`jcc`** — move the bookmark only when the right flag is on (`je`, `jl`, `jb`, …).
4. **`cmov`** — pick one of two values without any jump at all.

With these four pieces you can build every `if`, `while`, `for`, `switch`, and ternary you have ever seen in a high-level language.

## Topics

1. [`01_cmp_and_test.md`](01_cmp_and_test.md) — `cmp`, `test`, and the FLAGS row.
2. [`02_unconditional_jump.md`](02_unconditional_jump.md) — `jmp` and labels.
3. [`03_conditional_jumps.md`](03_conditional_jumps.md) — the `jcc` family, signed vs unsigned.
4. [`04_cmov.md`](04_cmov.md) — branchless conditional move.

Each topic ships with a tiny `.s` program you can build with `as` + `ld` and run on the spot. Build them all:

```bash
for f in *.s; do
  as -o /tmp/_t.o "$f" && ld -o /tmp/_t /tmp/_t.o && /tmp/_t
  echo "[$f] exit=$?"
done
```

## What's next

[Part 09 — Loops](../09_Loops/README.md). We put conditional jumps to work building `for`, `while`, and `do-while`, and see why the tempting-looking `loop` instruction is almost never used in real code.
