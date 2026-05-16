# Part 14 — A Tiny Program

## The picture first: your first finished toy

For thirteen chapters we've been collecting parts — registers, instructions, addressing tricks, syscalls. Like a kid emptying a Lego box onto the floor, sorting bricks by shape and color, learning what each one does.

This chapter is the moment we glue them together into a finished toy that actually works. Small, but complete. Something you can show somebody.

The program:

1. Reads bytes from stdin (the keyboard, or whatever you piped in).
2. Parses them as a non-negative decimal integer — that is, looks at the characters `'2'`, `'1'` and figures out the number twenty-one.
3. Doubles it.
4. Prints the result followed by a newline.
5. Exits 0 (the "everything went fine" exit status).

No libc. Pure asm, two syscalls (`read`, `write`), two helper functions.

The full source is in [`double.s`](double.s). Build and run:

```bash
as -o double.o double.s && ld -o double double.o
echo 21 | ./double
# => 42
echo 1234567890 | ./double
# => 2469135780
```

What this actually does, in plain words: `as` is the assembler (it turns `double.s`, the human-readable assembly text, into `double.o`, a half-baked binary). `ld` is the linker (it stitches `double.o` into a finished, runnable program called `double`). Then `echo 21 | ./double` pipes the three characters `'2'`, `'1'`, `'\n'` into our program's stdin. The program reads them, parses 21, doubles it to 42, prints `"42\n"`, and exits.

## The shape of the program

The file has three "functions" (chunks of code with names):

- `parse_uint(buf, len) -> rax` — walks the buffer of characters, building a decimal value digit by digit. ("uint" = unsigned integer = a whole number, not negative.)
- `write_uint(value)` — fills a 32-byte buffer **from the right** with digits, then issues one `write` syscall to print the whole thing. (Why from the right? We'll see in a moment — it makes the digits come out in the right order.)
- `_start` — the entry point. The orchestrator. It calls `read`, then `parse_uint`, then doubles the result, then `write_uint`, then `exit`.

Each one exercises something we covered earlier. This is the cheat sheet of which chapter taught what:

- **Registers as parameters** ([Part 10](../10_Functions/README.md)): `rdi`/`rsi` carry inputs, `rax` carries the return.
- **`movzx`** ([Part 03](../03_Moving_Data/README.md)): zero-extending a byte from memory into a 64-bit register before comparing. (`movzx` = **mov**e with **z**ero e**x**tend. It copies a small thing into a big cup and pads the rest of the cup with zeros so no garbage from a previous value sneaks in.)
- **Indexed addressing** ([Part 06](../06_Addressing/README.md)): `[rdi + rcx]` to walk the input.
- **`imul`** by a constant ([Part 04](../04_Arithmetic/README.md)): `imul rax, rax, 10`. (`imul` = integer multiply.)
- **`div`** with `rdx:rax` setup ([Part 04](../04_Arithmetic/README.md)): the divide-by-10 loop in `write_uint`.
- **Loops and conditional jumps** ([Parts 08–09](../08_Control_Flow/README.md)): pretty much every line.
- **Stack alignment**: we don't allocate locals, and both helpers are leaf-ish, so no prologue/epilogue is needed for correctness here.
- **Syscalls** ([Part 13](../13_Syscalls/README.md)): `read`, `write`, `exit`.

The two reserved memory areas in the file are simple. `inbuf` is a row of 32 one-byte lockers we'll read input into. `outbuf` is a row of 32 one-byte lockers we'll write output into (from the right side, as you'll see).

## Dissecting `parse_uint`

The job: turn a row of digit characters (like `'2'`, `'1'`) sitting in memory into the actual number (21) sitting in a register.

The trick: walk one character at a time, left to right. Keep a running total in `rax`. Each new digit, multiply the running total by 10 (shift it one place to the left in our heads) and add the new digit's value.

```asm
parse_uint:
        xor     rax, rax                # acc = 0
        xor     rcx, rcx                # i = 0
.pu_loop:
        cmp     rcx, rsi
        jge     .pu_done
        movzx   rdx, byte ptr [rdi + rcx]
        cmp     rdx, '0'
        jl      .pu_done
        cmp     rdx, '9'
        jg      .pu_done
        sub     rdx, '0'
        imul    rax, rax, 10
        add     rax, rdx
        inc     rcx
        jmp     .pu_loop
.pu_done:
        ret
```

What this actually does, in plain words:

1. `rax` starts at 0 — this is our running total (the **accumulator**).
2. `rcx` starts at 0 — this is our index `i`, how far we've walked into the buffer.
3. Loop start: if `i` reached `len` (the number of bytes we were given), we're done.
4. Grab the byte at position `i` and stick it into `rdx` (using `movzx` so the upper bits stay zero — no leftover junk).
5. If that byte is below `'0'` or above `'9'`, it isn't a digit — stop. A newline `'\n'` will hit this case.
6. Subtract `'0'` to turn the character into its numeric value (the character `'2'` has byte value 0x32, and `'0'` has byte value 0x30, so subtracting gives 2).
7. Multiply the accumulator by 10 — this shifts the previous digits one place to the left in decimal.
8. Add the new digit.
9. Step the index forward and loop.

The first time you read this, trace one input — say, `"21\n"` — by hand:

| Step                          | `rax` | `rcx` | `rdx`            |
| ----------------------------- | ----- | ----- | ---------------- |
| start                         | 0     | 0     | —                |
| `movzx rdx, ['2']`            | 0     | 0     | `0x32` (`'2'`)   |
| `sub rdx, '0'`                | 0     | 0     | 2                |
| `imul rax, 10`                | 0     | 0     | 2                |
| `add rax, rdx`                | 2     | 0     | 2                |
| `inc rcx`                     | 2     | 1     | 2                |
| `movzx rdx, ['1']`            | 2     | 1     | 1                |
| `imul rax, 10` ; `add rdx`    | 21    | 1     | 1                |
| `inc rcx`                     | 21    | 2     | 1                |
| `movzx rdx, ['\n']`           | 21    | 2     | `0x0A`           |
| `cmp rdx, '0'` → less; exit   | 21    | 2     | …                |

We arrive at `rax = 21`. That mental trace is the point — once you can do it, you understand asm.

## Dissecting `write_uint`

The job: take a number sitting in a register (say, 42) and print the matching characters (`'4'`, `'2'`, `'\n'`) to stdout.

The trick: repeatedly divide by 10. The **remainder** each time is the next digit, starting from the rightmost. So we get them in reverse order. To turn that around, we **write the buffer from right to left** — fill in the rightmost slot first, then walk leftward as we generate more digits. When we're done, the digits read correctly left-to-right.

```asm
        mov     rcx, 10
.wu_div:
        xor     rdx, rdx
        div     rcx                     # rax = q, rdx = r
        add     dl, '0'
        dec     rsi
        mov     [rsi], dl
        test    rax, rax
        jnz     .wu_div
```

What this actually does, in plain words:

1. Put 10 in `rcx` (the divisor).
2. Before each `div`, zero out `rdx`. The `div` instruction divides the 128-bit number formed by `rdx:rax` by the divisor — if you leave junk in `rdx`, your division explodes.
3. `div rcx` produces the quotient in `rax` and the remainder in `rdx`. The remainder is between 0 and 9.
4. `add dl, '0'` turns that 0–9 number into the matching character. `dl` is the lowest byte of `rdx`.
5. `dec rsi` walks the destination pointer one step to the left.
6. `mov [rsi], dl` writes the digit character into the buffer at that position.
7. If `rax` is now zero, we've exhausted the number — stop. Otherwise, loop.

To convert 21 to `"21"`:

- 21 / 10 = 2 remainder **1** → write `'1'` at the rightmost slot, loop.
- 2 / 10 = 0 remainder **2** → write `'2'` one slot to the left, loop.
- `rax == 0`, exit.

```
outbuf:  [  ][  ][  ][  ][  ][  ][  ][  ][  ][  ]...[  ][ 2][ 1][\n]
                                                            ^
                                                            rsi points here
                                                            after the loop
```

After we're done, `rsi` points at the first digit, and we know the length of what to print is `(end_of_buffer - rsi)`. One `write` syscall and we're done.

The full version in `double.s` also stashes a `'\n'` at the very end of `outbuf` before the loop runs, so the final printout is `"42\n"` rather than just `"42"`. Without the newline your shell prompt would land right after the number.

## How `_start` glues it all together

Look at `double.s` and you'll see `_start` doing exactly five things in order:

1. `read(0, inbuf, 32)` — ask the kernel to fill `inbuf` from stdin, up to 32 bytes. The kernel returns the actual byte count in `rax`.
2. If that count is zero or negative, jump to `.err` and exit with status 1.
3. Call `parse_uint(inbuf, n)` to turn the characters into a number.
4. Double it with `shl rax, 1`. (`shl` = shift left. Shifting a binary number one bit to the left is the same as multiplying by 2 — same idea as how shifting a decimal number left multiplies by 10.)
5. Call `write_uint(doubled_value)`, then `exit(0)`.

That is the whole program.

## Stepping through in gdb

`gdb` is the GNU Debugger — a tool that lets you run your program one instruction at a time and peek at every register and memory location. There is no better way to cement how asm works than to watch a real program crawl forward step by step.

```bash
gdb ./double
(gdb) starti
(gdb) layout asm
(gdb) layout regs
(gdb) break parse_uint
(gdb) run <<< "42"
(gdb) ni       # next instruction (steps over calls)
(gdb) si       # step into
```

Run the program with input `"42\n"` and watch each register move. Doing this once cements the model better than reading 50 pages of notes.

## Try it

1. Make it accept signed integers. (Hint: in `parse_uint`, check for a leading `'-'`; remember a sign flag; negate at the end. In `write_uint`, if negative, write `'-'` after the loop.)
2. Add 64-bit overflow detection in `parse_uint` — refuse to process more than 19 decimal digits.
3. Print the result in hex instead of decimal. (Divide by 16 instead of 10, with `'0'..'9','a'..'f'` digits.)

## What's next

You can write asm, link it freestanding or with C, debug it, and dissect compiler output. [Part 15](../15_Where_Next/README.md) — pointers to the next steps: SIMD (`xmm`/`ymm`/`zmm`), floats, optimization, OS dev.
