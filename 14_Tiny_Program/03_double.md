# Topic 03 — Capstone: `double`

## A story: the toy that finally works

**In plain words:** for thirteen chapters we've been collecting Lego pieces — registers, instructions, addressing modes, syscalls. This is the moment we click them together into a finished toy. It is small, but it works, and you can show it to somebody.

The program: read an integer from stdin, double it, print the result, exit cleanly.

**The analogy.** Think of it as a hand-built calculator with three lines of code on the screen: a reader, a doubler, a printer. The reader is `parse_uint` from [Topic 01](01_parse_uint.md). The printer is `write_uint` from [Topic 02](02_write_uint.md). The doubler is a single instruction. The whole thing fits on a page.

**The technical layer.** No libc. Two helper functions. One orchestrating `_start`. Three syscalls: `read`, `write`, `exit`.

## The code

See [`03_double.s`](03_double.s). The orchestrator:

```asm
_start:
        # n = read(0, inbuf, 32)
        xor     rax, rax
        xor     rdi, rdi
        lea     rsi, [rip + inbuf]
        mov     rdx, 32
        syscall

        # No input? Exit 0 silently.
        test    rax, rax
        jle     .done

        # value = parse_uint(inbuf, n)
        mov     rsi, rax
        lea     rdi, [rip + inbuf]
        call    parse_uint

        # write_uint(value * 2)
        shl     rax, 1
        mov     rdi, rax
        call    write_uint

.done:
        xor     rdi, rdi
        mov     rax, 60
        syscall
```

## Build and run

```bash
as -o 03_double.o 03_double.s
ld -o 03_double 03_double.o

echo 21 | ./03_double
# => 42

echo 1234567890 | ./03_double
# => 2469135780

./03_double </dev/null
# (no output, exits 0)
```

## Dissecting `_start`

### The read syscall

```asm
xor     rax, rax        # syscall number 0 = read
xor     rdi, rdi        # fd 0 = stdin
lea     rsi, [rip + inbuf]
mov     rdx, 32
syscall
```

**In plain words.** Form #0, "read." First detail: which file to read from (0 = standard input). Second detail: where to put the bytes (`inbuf`). Third detail: how many bytes max (32). The kernel fills our buffer and writes the actual byte count into `rax`.

**The technical layer.** `xor rax, rax` and `xor rdi, rdi` are both "zero this register" idioms — see [Part 01](../01_Hello_CPU/README.md). Read is syscall 0; stdin is file descriptor 0. The pleasing coincidence (both happen to be zero) is *why* `read` was chosen as syscall 0 in the Linux ABI.

**Gotcha.** `read` does not promise to fill the entire buffer. It returns whatever was available — could be 1 byte, could be 32, could be 0 if the input was closed. Real programs loop on `read` until they have enough or hit end of file. Our toy program just trusts the first read.

### Handling empty input

```asm
test    rax, rax
jle     .done
```

**In plain words.** If `read` returned zero (clean end of file) or a negative number (an error), just jump to the exit block. No crash, no output.

**The technical layer.** `test rax, rax` updates the flags based on `rax`'s bits. `jle` ("jump if less than or equal") jumps if the signed value was 0 or negative. We're being a polite Unix citizen: if there's nothing to do, do nothing and exit cleanly.

### Calling `parse_uint`

```asm
mov     rsi, rax        # len = the byte count read returned
lea     rdi, [rip + inbuf]
call    parse_uint
```

**In plain words.** Pack the arguments the way `parse_uint` expects: buffer address in `rdi`, length in `rsi`. Call. The result comes back in `rax`.

**The technical layer.** This is the calling convention — [Part 10](../10_Functions/README.md) covers it in detail. Note that `rax`, freshly out of the `read` syscall, *already holds the byte count* — so we move it into `rsi` before overwriting `rax` with anything else. Tiny choices like that are what makes assembly feel like a puzzle.

### Doubling: `shl rax, 1`

**In plain words.** Shift `rax` left by one bit — which, for a binary number, is the same as multiplying by 2.

**The analogy.** Just as shifting a decimal number left by one place (12 → 120) multiplies by 10, shifting a binary number left by one bit (`...0110` = 6 → `...1100` = 12) multiplies by 2. The CPU runs this instruction in essentially zero time; it is faster and shorter to encode than `imul rax, 2`.

**Gotcha.** Shifting *too* far left will lose bits off the top. For our purposes — doubling a value the user just typed in — overflow is a theoretical worry, not a real one.

### Calling `write_uint`

```asm
mov     rdi, rax
call    write_uint
```

**In plain words.** `write_uint` expects its input in `rdi` (first-argument register). We move our doubled value there, call, done.

### The exit syscall

```asm
.done:
        xor     rdi, rdi
        mov     rax, 60
        syscall
```

**In plain words.** Form #60, "exit." Status 0 ("everything fine"). Slide the form. The kernel cleans us up.

## Walking through `echo 21 | ./03_double` step by step

1. The shell starts `./03_double` and pipes `"21\n"` into its stdin.
2. `_start` issues `read` → kernel writes `'2'`, `'1'`, `'\n'` into `inbuf`, returns 3 in `rax`.
3. `test`/`jle` — `rax = 3` is positive, fall through.
4. Set up arguments: `rdi = &inbuf`, `rsi = 3`. `call parse_uint`.
5. Inside `parse_uint`: accumulator builds up `0 → 2 → 21`. On the third iteration, `'\n'` (0x0A) is below `'0'`, so loop ends. `rax = 21`. `ret`.
6. Back in `_start`: `shl rax, 1` → `rax = 42`.
7. `mov rdi, rax; call write_uint`.
8. Inside `write_uint`: 42 ÷ 10 = 4 r 2 → write `'2'`. 4 ÷ 10 = 0 r 4 → write `'4'`. Quotient is zero, stop. Issue `write(1, ptr, 3)` — prints `"42\n"`. `ret`.
9. Back in `_start`: jump to `.done`, exit 0.

The whole dance, end to end, executes faster than a single keystroke.

## Stepping through in gdb

`gdb` is the GNU Debugger — a tool that lets you run your program one instruction at a time and peek at every register and memory location. Doing this once cements the model better than reading fifty pages of notes.

```bash
gdb ./03_double
(gdb) starti               # start, stop at first instruction
(gdb) layout asm           # show assembly view
(gdb) layout regs          # show registers
(gdb) break parse_uint
(gdb) run <<< "42"
(gdb) ni                   # next instruction (steps over `call`)
(gdb) si                   # step into `call`
```

Watch `rax` change as the loop runs. Watch `rsi` walk leftward through `outbuf` in `write_uint`. There is no better teacher than your own eyes on a live register pane.

## Try it

1. **Make it signed.** In `parse_uint`, check for a leading `'-'`; remember a sign flag; negate `rax` at the end. In `write_uint`, if the value is negative, emit `'-'` after the digit loop.
2. **Overflow detection.** Refuse more than 19 decimal digits in `parse_uint` (the max that always fits in a signed 64-bit integer).
3. **Print in hex.** Divide by 16 instead of 10. Digits 0–9 stay as is; digits 10–15 become `'a'`..`'f'`. (Hint: after `add dl, '0'`, if `dl > '9'` then `add dl, 'a' - '0' - 10`.)
4. **Triple instead of double.** Replace `shl rax, 1` with `imul rax, rax, 3`. Predict the output for `echo 7 | ./03_double` before running.

## What's next

You can read assembly. You can write assembly. You can link freestanding programs and debug them. The remaining ground — SIMD, floats, optimization, OS development — is signposted in [Part 15](../15_Where_Next/README.md).
