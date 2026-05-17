# Part 06 — Addressing Modes & `lea`

## A story: the warehouse calculator

Imagine a gigantic warehouse with billions of numbered shelves stretching off into the distance. Every shelf has a number — shelf 0, shelf 1, shelf 2, all the way up to ridiculous numbers. The warehouse is called **memory** (or **RAM** — random access memory, meaning the worker can jump straight to any shelf without walking past the others). Each shelf can hold one byte.

To touch a shelf, the worker needs its number — its **address**. But nobody wants to think in raw shelf numbers like `140737488355328`. So x86 ships with a tiny built-in **address calculator**: hand it a few register values and constants, and it works out which shelf you mean. The whole of x86 memory addressing collapses into one short formula and a handful of conventions.

This chapter teaches that formula, the special "from-here" flavor used for safety (RIP-relative), the math-instruction-in-disguise built on top of it (`lea`), and how to spell out byte widths when the operands don't tell their own size.

Vocabulary check:

- **Memory / RAM** — the warehouse of numbered shelves. Slower than registers.
- **Address** — the shelf number.
- **Load** — read from a shelf into a register.
- **Store** — write from a register into a shelf.
- **Effective address** — the actual shelf number the CPU works out from the formula.

## Topics in this chapter

1. **[01 — The One Formula: `[base + index*scale + disp]`](01_the_one_formula.md).** Every legal `[...]` is a specialization of one short formula. Walk an array of `int`s with a single instruction. Example: [`01_the_one_formula.s`](01_the_one_formula.s).

2. **[02 — RIP-Relative Addressing](02_rip_relative.md).** Modern Linux randomizes load addresses; `[rip + label]` is the safe, position-independent way to point at named data. Example: [`02_rip_relative.s`](02_rip_relative.s).

3. **[03 — `lea`: the Math Instruction in Disguise](03_lea_as_math.md).** `lea` runs the address formula but doesn't touch memory. So it's a fast 3-operand adder and small-constant multiplier. Example: [`03_lea_as_math.s`](03_lea_as_math.s).

4. **[04 — Size Suffixes: `BYTE PTR`, `WORD PTR`, `DWORD PTR`, `QWORD PTR`](04_size_suffixes.md).** When the operands don't tell the assembler how big a memory access is, you spell it out. Example: [`04_size_suffixes.s`](04_size_suffixes.s).

## Build any of the examples

Each `.s` file is a standalone Linux program. Build with `as` + `ld`:

```bash
as -o ex.o 01_the_one_formula.s
ld -o ex ex.o
./ex ; echo $?
```

The exit code is how each example reports its result.

## What's next

Memory addressing covers any byte at any address. But programs need a tiny, automatically-managed slice of memory for function calls and locals — the **stack**. That's [Part 07](../07_The_Stack/README.md).
