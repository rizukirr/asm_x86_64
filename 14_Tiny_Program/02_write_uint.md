# Topic 02 — `write_uint`: turning a number back into characters

## A story: dropping coins into a tube

**In plain words:** when your program holds the number 42 in a register, the screen has no idea what 42 means. The screen speaks only one language: bytes. To print `42`, we need to hand the kernel exactly two bytes — the character `'4'` followed by the character `'2'` — plus the newline `'\n'` so the shell prompt lands on a fresh line.

**The analogy.** Imagine a tall narrow tube standing on the ground. You feed coins in through the top, and they stack from the bottom up. If I hand you the digits of 42 in the order I can extract them — rightmost first, leftmost last — and you drop them in the tube, the tube ends up reading correctly *top to bottom*: `4`, then `2`. The reversal happens for free, because of the geometry of the tube.

The trick is that **when you divide a number by 10, the remainder is the rightmost digit**. 42 ÷ 10 is 4 remainder **2** (rightmost digit: 2). 4 ÷ 10 is 0 remainder **4** (rightmost remaining digit: 4). Then the quotient is zero, and we stop. We pulled the digits out in the order `2, 4` — backwards from how they should be printed.

**The technical layer.** That tube is a chunk of memory we write into **from the right**. We park a pointer at the far end of a buffer, then each loop iteration: divide by 10, take the remainder as the next digit character, *decrement* the pointer by one, store the character. By the time the quotient hits zero, the pointer is sitting on the first digit and the bytes to its right spell out the number correctly. One `write` syscall prints them all.

**Check yourself.** If your tube has slots 0–9 and you write 42 into it with this scheme, which slots end up holding which characters? (Answer: slot 8 holds `'4'`, slot 9 holds `'2'`. The pointer lands at slot 8, length is 2.)

## The code

See [`02_write_uint.s`](02_write_uint.s). The heart of it:

```asm
write_uint:
        mov     rax, rdi
        lea     rsi, [rip + outbuf + 32]        # one past end of buffer
        mov     byte ptr [rsi - 1], '\n'        # park '\n' at the last slot
        dec     rsi                              # rsi -> '\n'
        mov     rcx, 10
.wu_div:
        xor     rdx, rdx
        div     rcx                              # rax=q, rdx=r
        add     dl, '0'
        dec     rsi
        mov     [rsi], dl
        test    rax, rax
        jnz     .wu_div

        # write(1, rsi, end - rsi)
        lea     rdx, [rip + outbuf + 32]
        sub     rdx, rsi
        mov     rdi, 1
        mov     rax, 1
        syscall
        ret
```

## Build and run

```bash
as -o 02_write_uint.o 02_write_uint.s
ld -o 02_write_uint 02_write_uint.o
./02_write_uint
# => 12345
```

The driver hard-codes the value 12345 in `rdi` and calls `write_uint`. You can change that number and rebuild.

## Dissecting it

### `mov rax, rdi` — move the input into the dividend

**In plain words:** `div` always divides the value in `rax` (technically `rdx:rax`) by whatever you give it. So we move our input number into `rax` to set up the division.

**Gotcha.** This shuffle exists because `div` doesn't let you pick the dividend register — it's hard-wired to `rdx:rax`. You'll see registers being shuffled like this a lot when you use specific instructions that demand specific operands.

### `lea rsi, [rip + outbuf + 32]` — point one past the end

**In plain words:** `outbuf` is a 32-byte buffer. We aim `rsi` at the byte just past the last slot. (`outbuf + 0` is the first slot; `outbuf + 32` is one past the last.)

**The analogy.** Picture standing at the right edge of a 32-slot row, *facing left*. From here, "decrement and write" means take one step left, drop a coin in the slot under your feet. We don't write at this exact starting position — it's an out-of-bounds marker.

**The technical layer.** `lea` (load effective address) computes the address without dereferencing. `[rip + outbuf + 32]` is RIP-relative addressing — see [Part 06](../06_Addressing/README.md). We covered the basic idea in [Part 01](../01_Hello_CPU/README.md).

### `mov byte ptr [rsi - 1], '\n'` — park the newline first

**In plain words:** the very last slot of `outbuf` gets a newline character. We do this once, before the divide loop starts, so it's the rightmost byte we'll print.

### `dec rsi` — move our cursor to where '\n' lives

**In plain words:** after this, `rsi` points at the newline. Each loop iteration will further decrement before writing — so the first digit goes one slot to the *left* of the newline.

### `xor rdx, rdx` — clear the high half of the dividend

**In plain words:** zero out `rdx` before every `div`. This is mandatory.

**The technical layer.** The 64-bit `div` instruction treats the pair `(rdx, rax)` as a single 128-bit number — `rdx` is the high 64 bits, `rax` is the low 64 bits. If `rdx` is non-zero, you're telling `div` your dividend is some enormous number. Almost always you mean "just divide what's in `rax`," which requires `rdx` to be zero.

**Gotcha.** Forgetting `xor rdx, rdx` before `div` is one of the most common bugs in handwritten asm. If the previous loop iteration left junk in `rdx`, the divide will either return wildly wrong results or trip a `#DE` (divide error) exception and crash the program. There's also `cqo` (sign-extend `rax` into `rdx:rax`) for signed division — not relevant here, but you'll meet it later.

### `div rcx` — quotient in rax, remainder in rdx

**In plain words:** divide `rax` by 10. The quotient (how many tens are left to print) replaces the value in `rax`. The remainder (the next digit to print, 0–9) lands in `rdx`.

### `add dl, '0'` — digit value → digit character

**In plain words:** turn the number 7 into the character `'7'` by adding `'0'` (= 0x30).

**The technical layer.** `dl` is the lowest 8 bits of `rdx`. Since the remainder of `÷10` is always 0–9, it fits in a byte with room to spare. Adding `'0'` lands us between `'0'` (0x30) and `'9'` (0x39). This is the exact inverse of `sub rdx, '0'` from `parse_uint`.

### `dec rsi` ; `mov [rsi], dl` — drop the coin

**In plain words:** step the cursor one slot to the left, then store the character there.

The order matters: we decrement first, then write. This is why `rsi` started one slot *past* the actual last writable position.

### `test rax, rax` ; `jnz .wu_div` — loop until quotient is zero

**In plain words:** if `rax` (the quotient) is still non-zero, loop. Otherwise we've extracted every digit.

**The technical layer.** `test reg, reg` performs a bitwise AND of the register with itself, throws away the result, and updates flags. The only fact it produces is "was this register all zeros?" `jnz` ("jump if not zero") reads the flag and jumps. It's the standard "is this register zero?" idiom; it's encoded one byte shorter than `cmp rax, 0`.

### Computing the length and writing

```asm
        lea     rdx, [rip + outbuf + 32]
        sub     rdx, rsi
```

**In plain words:** "length = (one past end) - (where the first digit is)." `rdx` ends up holding the exact number of bytes to print, including the newline.

Then the syscall is the same form #1 we used in [Part 01](../01_Hello_CPU/README.md): `rax = 1` (write), `rdi = 1` (stdout), `rsi` = buffer pointer, `rdx` = length.

## Try it

1. **Print different numbers.** Edit `_start` to `mov rdi, 7` or `mov rdi, 1000000000` and rebuild. Verify each.
2. **Print 0.** Change `_start` to `mov rdi, 0`. What does it print? (Trace through: 0 ÷ 10 is 0 r 0, we write `'0'`, then quotient is 0 and we stop. Output: `"0\n"`. The loop correctly handles zero exactly *because* we test the quotient *after* writing one digit, not before.)
3. **Remove the `'\n'` parking line.** Rebuild. Run from a shell. Observe how the prompt now appears glued to the number.
4. **Make the buffer too small.** Change `outbuf: .skip 32` to `.skip 4` and try printing 1000000000 (10 digits). What happens? (We'll write before the buffer — into whatever lives there. A reminder that bounds are your responsibility.)

## What's next

We can read a number. We can print a number. The capstone — [Topic 03](03_double.md) — glues the two together with one extra instruction in the middle.
