# Part 11 — Talking to C

So far your programs have been **shut-ins**. They start, slide a couple of forms under the kernel's door, and exit. No friends, no library calls, no help.

This chapter opens the door to **libc** — the C standard library — and to every program written in C. Once your assembly can call C functions and *be* called from C, the entire ecosystem is available to you: file I/O, networking, math, threading, anything libc (or any C library) wraps.

The chapter splits into four topics, each with a runnable example:

1. **[Calling libc from assembly](01_calling_libc.md)** — build with `gcc` instead of `ld`, define `main` instead of `_start`, dial `printf`.
2. **[Being called from C](02_called_from_c.md)** — write an asm function that obeys the SysV AMD64 ABI; C can call it like any other.
3. **[The 16-byte stack alignment rule](03_stack_alignment.md)** — the one rule that bites everyone exactly once, and how to get it right every time.
4. **[PIE, PLT, and GOT](04_pie_plt_got.md)** — what `-no-pie` actually buys you, and what the position-independent dance looks like.

Each topic file is self-contained, has its own build command, and ends with exercises.

## Next

[Part 12 — Strings and Arrays](../12_Strings_Arrays/README.md): the `rep` prefix and the dedicated string instructions.
