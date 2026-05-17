# Part 10 — Functions & the System V ABI

## The story: phoning a specialist

**In plain words.** A *function* is a chunk of code you can jump to, run, and come back from. The CPU has no built-in notion of "function" — it only knows how to jump. Everything we call a function is built out of a tiny pair of instructions (`call`/`ret`) plus a community agreement (the **calling convention**) about which registers hold what.

**The analogy.** Picture a giant office of specialists who phone each other. To make a call, you (1) leave a sticky note saying where to come back to, (2) drop the inputs into agreed-upon cups, (3) ring the bell. The specialist works, drops the answer into a fixed cup, and rings back. You read the answer and carry on. That's a function call.

This chapter unpacks that picture in four beats. Each beat has its own short file and its own working program — build it, run it, watch the exit code, change it, break it, fix it.

## Topics

1. **[`01_call_and_ret.md`](01_call_and_ret.md)** — `call` and `ret`: the bookmark trick. How the CPU saves a return address on the stack and pops it back later. The whole "function" mechanism in two instructions. Run: `01_call_and_ret.s`.

2. **[`02_calling_convention.md`](02_calling_convention.md)** — The System V AMD64 ABI: which six registers carry the first six arguments (`rdi rsi rdx rcx r8 r9`), where the return value lives (`rax`), and the difference between caller-saved and callee-saved registers. Run: `02_calling_convention.s`.

3. **[`03_stack_frames.md`](03_stack_frames.md)** — Prologue and epilogue: how `push rbp` / `mov rbp, rsp` / `sub rsp, N` sets up a private workbench on the stack for locals and bookkeeping, and how the matching epilogue tears it down. Run: `03_stack_frames.s`.

4. **[`04_stack_alignment.md`](04_stack_alignment.md)** — The 16-byte alignment rule (the single sneakiest bug in hand-written assembly), and the 128-byte red zone bonus for leaf functions on Linux. Run: `04_stack_alignment.s`.

## How to build each example

```bash
as -o /tmp/t.o NN_topic.s
ld -o /tmp/t /tmp/t.o
/tmp/t
echo $?
```

Each example prints a short banner so you can *see* it ran, and exits with a status byte chosen to be the answer to that program's question (so `echo $?` reveals the computed value).

## What's next

You now know how to write a function that other code can call, and how to call into other code from yours. Time to actually do that with real-world software: [Part 11 — Talking to C](../11_Talking_To_C/README.md).
