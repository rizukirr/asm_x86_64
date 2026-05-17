# Part 14 — A Tiny Program

## The picture first: a finished toy, in three pieces

For thirteen chapters we have been collecting parts — registers, instructions, addressing tricks, syscalls. Like a kid emptying a Lego box onto the floor, sorting bricks by shape and color, learning what each one does.

This chapter glues them together into a finished toy: a program that reads a non-negative integer from stdin, doubles it, prints the result, and exits.

We will not look at it as one big blob. We split it into three topics — read, write, glue — each with its own runnable assembly file. By the end of the chapter you will have built three small programs, and the third one *is* the toy.

## Topics

1. **[Topic 01 — `parse_uint`](01_parse_uint.md)**: turning a row of digit characters into a 64-bit integer.
   Runnable: [`01_parse_uint.s`](01_parse_uint.s) — reads a number from stdin and echoes it back.

2. **[Topic 02 — `write_uint`](02_write_uint.md)**: turning a 64-bit integer back into characters using the "fill the buffer from the right" trick.
   Runnable: [`02_write_uint.s`](02_write_uint.s) — prints a hard-coded number.

3. **[Topic 03 — Capstone: `double`](03_double.md)**: the final program. `parse_uint` + `shl` + `write_uint` + the syscall dance.
   Runnable: [`03_double.s`](03_double.s) — reads, doubles, prints.

## Build any of them

```bash
as -o <name>.o <name>.s
ld -o <name>   <name>.o
./<name>
```

For example:

```bash
as -o 03_double.o 03_double.s
ld -o 03_double   03_double.o
echo 21 | ./03_double
# => 42
```

What this actually does, in plain words: `as` is the assembler — it turns the human-readable `.s` file into a half-baked binary `.o`. `ld` is the linker — it stitches the `.o` into a finished, runnable program. The pipe (`|`) hands the characters `'2'`, `'1'`, `'\n'` to the program's stdin.

## What you should walk away with

- The shape of a freestanding Linux program: a `_start`, a couple of syscalls, no libc.
- A working mental model of the calling convention: `rdi`, `rsi`, `rdx` for args; `rax` for return.
- Two reusable patterns — building an integer left-to-right from digit characters, and laying digits right-to-left into a buffer to print.
- Comfort calling functions from your own `_start`, and recognizing what each helper does in isolation.

## What's next

Where to head once these three programs feel obvious: [Part 15 — Where Next](../15_Where_Next/README.md). SIMD (`xmm`/`ymm`/`zmm`), floats, optimization, OS dev — the rest of the iceberg.
