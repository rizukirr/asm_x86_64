# Part 07 — The Stack

## What this chapter is about

The **stack** is a region of memory the CPU uses as scratch space — for saving register values across noisy work, for holding local variables inside functions, and (later) for tracking "where to come back to" when one function calls another. It's last-in-first-out: the most recent value placed on the stack is the first one taken back off.

Think of it as the spring-loaded tray dispenser at a cafeteria: cooks press fresh trays on top, students pull the top tray off, and nobody ever digs into the middle.

On x86_64 Linux, the stack grows **downward** in memory. A special register, `rsp`, always points at the current top. Two instructions, `push` and `pop`, do almost everything you need.

This chapter splits the topic into four short, focused pieces. Each `NN_topic.md` has a working `NN_topic.s` you can build with `as`+`ld` and run.

## Topics

1. **[`01_stack_basics.md`](01_stack_basics.md)** — what the stack is, what `rsp` points at, why it grows downward, and how to print its actual value at program start.
2. **[`02_push_pop.md`](02_push_pop.md)** — the exact mechanics of `push` and `pop`, proven with a LIFO reversal example whose exit status is the *last* value pushed.
3. **[`03_stack_frames.md`](03_stack_frames.md)** — the classic prologue/epilogue pattern with `rbp` as a frame anchor; addressing local variables at `[rbp - 8]`, `[rbp - 16]`, etc.
4. **[`04_alignment.md`](04_alignment.md)** — the 16-byte alignment rule that the ABI demands at every `call` boundary, measured directly by the example program.

## Build everything

```bash
cd 07_The_Stack
for f in *.s; do
  as -o /tmp/_t.o "$f" && ld -o /tmp/_t /tmp/_t.o && /tmp/_t
  echo "[$f] exit=$?"
done
```

Expected output (the `rsp` address will differ every run due to ASLR):

```
rsp = 0x...
[01_stack_basics.s] exit=0
[02_push_pop.s] exit=3
[03_stack_frames.s] exit=10
[04_alignment.s] exit=8
```

Each non-zero exit code is a measurement: `3` proves LIFO, `10` proves the four local slots got summed correctly, `8` proves that `call` puts the callee on an 8-mod-16 stack.

## What you'll be able to do after this chapter

- Predict how `rsp` moves through any sequence of `push`/`pop`.
- Write a function prologue and epilogue that carve out and release scratch room safely.
- Diagnose the "my call into libc crashes for no reason" bug by reasoning about 16-byte alignment.
- Read `objdump` output of a real C function and identify its frame.

## Next

[`../08_Control_Flow/README.md`](../08_Control_Flow/README.md) — `cmp`, `test`, and conditional jumps: the foundation of every `if`, `while`, and `for` you've ever written.
