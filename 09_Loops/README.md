# Part 09 — Loops

## A story: a treasure hunt with one extra clue

**In plain words:** the CPU has no native concept of "loop." A loop is just normal straight-line code with a **jump back to an earlier label**, plus a condition that eventually lets you escape.

**The analogy.** Picture a treasure hunt with a stack of clue cards. The very last card says: "Did you find the chest? If yes, stop. If no, walk back to the first clue and try again." That single line — *go back if not done* — is everything a loop is. The CPU just reads cards forward, and one card happens to point backwards.

**The technical layer.** Building blocks you already know:

- `rip` is the bookmark. Any jump moves the bookmark.
- A backwards jump creates the circle.
- FLAGS (the yes/no lights) are set by `cmp`, `test`, and arithmetic ops like `dec`.
- A conditional jump (`jcc`) reads those lights and decides whether to take the bookmark backwards.

Every loop you'll ever write is some combination of those four ingredients.

## The topics

This chapter splits the loop story across four short, runnable lessons. Read in order; each one builds a tiny program you can assemble, link, and run.

1. **[01 — Counted loops: `dec` + `jnz`](01_counted_loops.md)** — the bread-and-butter shape. Counter in a register, body, decrement, conditional jump. We print `12345`.
2. **[02 — `while` and `do-while`](02_while_dowhile.md)** — `cmp` + `jcc` driven loops. The difference is *where the check lives*. We sum `1..10` with a `do-while` and convert the result to text with a `while`.
3. **[03 — The `loop` instruction (a trap)](03_loop_instruction.md)** — x86 has a one-instruction counted loop. It looks perfect. It is slow. We use it once, on purpose, so you'll recognize it in old code and avoid it in new code.
4. **[04 — Nested loops and array walks](04_nested_and_arrays.md)** — loops inside loops, plus the `[base + index*scale]` addressing mode that makes iterating over arrays trivial.

## How to build any example

Each file is a complete, standalone program. From inside `09_Loops/`:

```bash
as -o prog.o 01_counted_loops.s
ld -o prog prog.o
./prog
```

Same `as` + `ld` pipeline as [Part 01](../01_Hello_CPU/README.md) — no `libc`, no `main`, just `_start`.

## What's next

Once you can shape loops freely, the next move is **breaking a program into functions** — `call`, `ret`, and the calling convention that lets pieces of code talk without stepping on each other. → [Part 10 — Functions](../10_Functions/README.md)
