# Topic 01 — `parse_uint`: turning characters into a number

## A story: a row of postcards spelling out a number

**In plain words:** when you type `21` and press Enter, the program does *not* receive the number twenty-one. It receives three postcards: one with the character `'2'` painted on it, one with the character `'1'`, and one with the invisible character `'\n'` (newline). Your job — and the job of every input routine in every language you've ever used — is to look at those postcards in order and rebuild the actual number in your head.

**The analogy.** Picture a mail carrier sliding postcards through a slot, left to right. You stand on the other side with a tiny chalkboard. Each time a digit-postcard comes in, you erase the current chalkboard value, multiply it by ten in your head, add the new digit, and write the new total down. When a non-digit postcard arrives — a newline, a letter, anything else — you stop. Whatever number is on the chalkboard is your answer.

**The technical layer.** That chalkboard is a 64-bit register called the **accumulator** (here `rax`). The mail slot is a **buffer** in memory (here `inbuf`). The "multiply by ten and add" is a single hardware instruction (`imul`) followed by another (`add`). The whole thing is a tight loop that we will write in twenty lines of assembly.

**Check yourself.** If you fed the characters `'4'`, `'2'`, `'\n'` into the loop, what does the chalkboard say at the end? (Answer: 42. Step 1: chalkboard 0, multiply by 10 → 0, add 4 → 4. Step 2: chalkboard 4, multiply by 10 → 40, add 2 → 42. Step 3: newline arrives, we stop.)

## The code

See [`01_parse_uint.s`](01_parse_uint.s). The interesting half:

```asm
parse_uint:
        xor     rax, rax                # acc = 0
        xor     rcx, rcx                # i   = 0
.pu_loop:
        cmp     rcx, rsi
        jge     .pu_done
        movzx   rdx, byte ptr [rdi + rcx]
        cmp     rdx, '0'
        jl      .pu_done
        cmp     rdx, '9'
        jg      .pu_done
        sub     rdx, '0'                # digit value 0..9
        imul    rax, rax, 10
        add     rax, rdx
        inc     rcx
        jmp     .pu_loop
.pu_done:
        ret
```

**In plain words.** Two cups start at zero: `rax` (the accumulator, our chalkboard) and `rcx` (the index, "which postcard am I on"). On each pass: if we've walked past the end of the buffer, stop. Otherwise grab the next byte. If it isn't between `'0'` and `'9'`, stop. Otherwise turn it into a digit (0–9) by subtracting `'0'`, multiply the chalkboard by 10, add the digit, step the index forward, loop.

## Build and run

```bash
as -o 01_parse_uint.o 01_parse_uint.s
ld -o 01_parse_uint 01_parse_uint.o
echo 21 | ./01_parse_uint
# => 21
./01_parse_uint </dev/null
# => 0
```

The program reads stdin, parses it, and prints the parsed value back. It is a stripped-down echo for non-negative integers. (For the printing half — `write_uint` — see [Topic 02](02_write_uint.md). Right now we just trust that it works.)

## Dissecting it

### `xor rax, rax` — initializing the accumulator

**In plain words:** "set `rax` to zero." We saw this trick in Part 01 — XOR'ing a register with itself is the standard shorthand for zeroing.

**Gotcha.** We need this to be exactly zero, not "whatever the last function left here." Assembly does *not* automatically zero locals for you; that is a luxury of higher-level languages.

### `cmp rcx, rsi` — have we walked off the end?

**In plain words:** compare our index to the length. If the index is greater than or equal to the length, jump out of the loop.

**The technical layer.** `cmp a, b` performs `a - b` and updates the CPU's flag register *without storing the result anywhere*. The next conditional jump (`jge` here — "jump if greater or equal") reads those flags and decides whether to jump.

`rsi` was set by the caller to the number of bytes available in the buffer. That's the calling convention: input 1 in `rdi`, input 2 in `rsi`, output in `rax`. (See [Part 10 — Functions](../10_Functions/README.md) if that feels new.)

### `movzx rdx, byte ptr [rdi + rcx]` — fetching one byte

**In plain words:** grab one byte from the buffer at position `i`, and put it in `rdx` with the upper 56 bits forced to zero.

**The analogy.** Imagine you reach into a row of one-byte lockers and pull out a single envelope. The envelope is small — eight bits. But the cup you put it in (`rdx`) is large — sixty-four bits. `movzx` ("mov with zero-extend") guarantees that the unused space in the cup is filled with zeros, not with leftover trash from whatever was in `rdx` before.

**The technical layer.**

- `[rdi + rcx]` is **indexed addressing**: "the memory at address `rdi + rcx`." We covered this in [Part 06](../06_Addressing/README.md). Here `rdi` is the start of the buffer and `rcx` is our index, so this is "the `rcx`-th byte of the buffer."
- `byte ptr` tells the assembler "the thing at that address is one byte wide" (otherwise it might guess 8 bytes and read past the end).
- `movzx` is short for **mov**e with **z**ero e**x**tend. Plain `mov` into the bottom byte (`mov dl, ...`) would leave the upper bytes of `rdx` alone, holding whatever junk happened to be there. We don't want that — we're about to compare `rdx` to `'0'` as a 64-bit value, so the high bits matter.

**Gotcha.** A common bug is using `mov dl, [...]` instead of `movzx rdx, byte ptr [...]`. The compare would then see a random 64-bit number and your loop would behave wildly differently from one run to the next. `movzx` is cheap insurance.

### `cmp rdx, '0'` / `cmp rdx, '9'` — is this a digit?

**In plain words:** if the byte's numeric value is below `'0'` (which is 0x30 = 48) or above `'9'` (which is 0x39 = 57), it isn't a digit character; stop.

**The technical layer.** Even though we wrote `'0'` in the source — that's a character literal — the assembler turns it into the byte value 0x30 at build time. The comparison is purely numeric. A newline byte (0x0A) is below 0x30, so it gracefully terminates the loop.

**Check yourself.** What happens if a user types `12abc`? (Answer: we read `'1'`, `'2'`, then `'a'`. `'a'` is byte 0x61, which is above `'9'`. We stop. `rax` holds 12.)

### `sub rdx, '0'` — character → digit

**In plain words:** turn the character `'7'` into the number 7.

**The technical layer.** ASCII puts the ten digit characters consecutively: `'0'` is 0x30, `'1'` is 0x31, … `'9'` is 0x39. Subtracting 0x30 from any of them gives the numeric value 0..9. This is one of the oldest tricks in programming; you'll see it in C, Python source, every language. The assembly version just makes the trick explicit.

### `imul rax, rax, 10` — shift the chalkboard left

**In plain words:** multiply the running total by ten.

**The technical layer.** `imul` is **integer multiply**. The three-operand form `imul dst, src, immediate` says "multiply `src` by the immediate constant, store the result in `dst`." Here destination and source are both `rax`, so the running total grows by a factor of ten each iteration. This is the assembly version of `acc = acc * 10 + digit`.

**Gotcha.** `imul` *can* overflow — if the value grows past about 9.2 × 10^18 (the max of a signed 64-bit int), the upper bits silently go missing. For inputs up to 19 decimal digits, we're safe.

### `add rax, rdx` ; `inc rcx` ; `jmp .pu_loop` — finish the round

**In plain words:** add the new digit to the chalkboard. Step the index by one. Go back to the top.

`inc rcx` is the same as `add rcx, 1`, just shorter to encode.

### `ret` — return to the caller

**In plain words:** pop the return address off the stack and jump back to whoever called us. The final value lives in `rax`, which is the standard register for function returns.

**The technical layer.** When `_start` did `call parse_uint`, the CPU pushed the address of the *next* instruction onto the stack. `ret` pops it and jumps there. The whole stack ballet is one of the inventions [Part 10](../10_Functions/README.md) covers.

## Try it

1. **Trace `"100\n"` by hand.** Build a table of `rax`, `rcx`, `rdx` at each step. You should arrive at `rax = 100`.
2. **Feed it garbage.** `echo "42xyz" | ./01_parse_uint` — what do you get back? Why?
3. **Empty input.** `./01_parse_uint </dev/null` — the program prints `0`. Find the lines in `_start` that make that happen.
4. **Single space.** `echo " " | ./01_parse_uint` — predict the answer, then check. (Hint: space is byte 0x20, below `'0'`.)

## What's next

We can read a number. Next we need to *print* a number — the inverse trick, with one twist that catches everyone the first time. [Topic 02 — `write_uint`](02_write_uint.md).
