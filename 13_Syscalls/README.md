# Part 13 — Syscalls

## The picture first: asking the building manager

Imagine you live in a giant apartment building. Inside your apartment you can do almost anything — rearrange furniture, cook, sleep, paint the walls. But some things you cannot do from your apartment, no matter how clever you are:

- You cannot unlock the mailroom door.
- You cannot turn on the heat for the whole building.
- You cannot open the front gate to let a delivery in.

For those, you call the **building manager**. They have keys you don't. They have permissions you don't. You phone them, say what you want, hand over any details they need, and wait.

That building manager is the **kernel** — the heart of the operating system. Your apartment is your program. The phone call is the `syscall` instruction.

A **syscall** ("system call") is how a program asks the kernel to do something the program isn't allowed to do directly: read from the keyboard, write to the screen, open a file, ask for more memory, exit. The kernel runs at higher privilege than you do; `syscall` is the doorbell that hands control over to the kernel's pre-arranged front desk, which looks at your registers to decide what you want.

In this chapter we learn how to fill out the kernel's paperwork, the four bread-and-butter syscalls every Linux program uses, and how to verify what's happening with `strace`.

## Topics

This chapter is split into four short reads, each with a runnable program:

1. **[13.1 — The Syscall Calling Convention](01_calling_convention.md)** — what goes in which register, the `r10` quirk, the errno trick.
   Code: [`01_calling_convention.s`](01_calling_convention.s)

2. **[13.2 — Writing: stdout and stderr](02_write_stdout.md)** — the `write` syscall, file descriptors 1 and 2, why errors go on a separate channel.
   Code: [`02_write_stdout.s`](02_write_stdout.s)

3. **[13.3 — Reading from stdin](03_read_stdin.md)** — the `read` syscall, EOF, short reads, and how not to hang forever waiting for input.
   Code: [`03_read_stdin.s`](03_read_stdin.s)

4. **[13.4 — Files: open, close, lseek](04_open_close.md)** — turning filenames into file descriptors, moving the cursor, and giving the ticket back.
   Code: [`04_open_close.s`](04_open_close.s)

## How to build any example

Every `.s` file in this chapter builds and runs the same way:

```bash
as -o prog.o NN_topic.s
ld -o prog prog.o
./prog
```

No `libc`, no `main`, no startup code — just an assembler, a linker, and the kernel.

A useful one-liner that builds and runs every example in this directory:

```bash
for f in *.s; do
    as -o /tmp/_t.o "$f" && ld -o /tmp/_t /tmp/_t.o && /tmp/_t </dev/null
    echo "[$f] exit=$?"
done
```

The `</dev/null` is important for the `read` example — it makes stdin instantly EOF so the program doesn't block waiting for keyboard input.

## A debugging tool you should know now

`strace` records every syscall a program makes, with arguments and return values. It is the X-ray machine for "what did this binary actually ask the kernel to do?"

```bash
strace ./prog
```

Whenever a program isn't behaving the way you expect, `strace` is the fastest way to find out which syscall it really made — and what the kernel really said back. Every topic file ends with a "Try it yourself" section that uses `strace` to peek behind the curtain.

## syscall vs libc — when to pick which

A reminder from earlier chapters: **libc** is a helpful coworker in your apartment who already knows the building manager and will translate friendly requests like `printf("hello\n")` into the gritty syscall the manager actually expects.

| Use syscall directly when…                       | Use libc when…                                              |
| ------------------------------------------------ | ----------------------------------------------------------- |
| Writing freestanding code (no libc).             | Doing anything that benefits from buffering or formatting.  |
| Implementing the lowest layer of a runtime.      | Calling anything stdio-shaped: `printf`, `fopen`, `fread`.  |
| Sandboxed/seccomp setup, perf experiments.       | You need portability across Unixes.                         |
| You truly need the precise kernel behavior.      | You want correctness for free.                              |

Beware mixing `printf` and direct `write` in one program — libc buffers `printf` output, so the lines will appear out of order. Pick one lane.

## Next

Now that you can speak directly to the kernel, it's time to put everything together. [Part 14 — Tiny Program](../14_Tiny_Program/README.md) builds a complete asm program: read a number from stdin, double it, print the result. No libc.
