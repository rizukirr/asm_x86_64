# 12.1 — Strings and their length

## The picture first: a row of single-letter lockers

**In plain words:** a string is just a row of bytes, sitting next to each other in memory, where each byte happens to be the numeric code for one letter.

**The analogy.** Picture a row of mailboxes in an apartment lobby. Each box is the same size — one byte. Each box holds a single letter. The word `"Ada"` is three lockers in a row holding the bytes `'A'`, `'d'`, `'a'`. That row of lockers, taken together, is what we call a string.

There are two popular ways to mark where the row *ends*:

1. **Carry the length around separately.** You say "the string starts here, and it is 3 bytes long." Nothing in memory marks the end; the length is a number you remember.
2. **Put a stop sign at the end.** You add one extra locker on the end holding the special byte `0x00` (numeric zero, not the letter `'0'`). This stop sign is called the **NUL byte** (one L — different from the word "null" you may know from other languages). When something walks down the row looking at lockers, it knows to stop the moment it sees this `0`.

Both styles show up constantly. The first is how the Linux `write` syscall wants its arguments. The second — the NUL-terminated style — is the one C uses, which is why it's everywhere.

## How we lay a string into memory

**In plain words:** the assembler gives us two directives that drop a string into the data section, differing only in whether they tack on the NUL byte.

```asm
greet:  .ascii  "Hello, strings!\n"
name:   .asciz  "Ada"
```

- `.ascii` emits **only** the bytes of the string. No stop sign. If you want the program to know where it ends, you have to remember the length yourself.
- `.asciz` (the `z` is for **z**ero) emits the bytes **plus one extra `0x00`** at the end. That's the C-style string.

So `greet` is 16 bytes long (15 visible characters plus the `\n`), and `name` is 4 bytes long (`'A'`, `'d'`, `'a'`, `0`).

**Check yourself.** If you wrote `msg: .asciz "hi"`, how many bytes did you just put in memory? (Answer: 3 — `'h'`, `'i'`, `0`. The NUL counts.)

## Two ways to learn the length

**In plain words:** either let the assembler count for you while it's building the program, or write code that counts at runtime by walking down the row until it hits the NUL.

### Way 1: let the assembler count (compile-time)

This is the trick we already used back in Part 01:

```asm
greet:  .ascii  "Hello, strings!\n"
        .equ    greetlen, . - greet
```

**The technical layer.** The dot `.` means "the current address" — wherever the assembler is in the file right at this moment. So `. - greet` is "the address right after the string, minus the address where the string started," which is exactly the byte count. `.equ` then bakes that number into the symbol `greetlen`. By the time your program runs, `greetlen` is just the fixed integer 16. No memory is allocated, no instruction is emitted. It's a labelling trick that happens entirely while the assembler is reading your file.

This is the cheapest way to know a length, and you should reach for it whenever the string is a fixed literal you wrote into the source.

### Way 2: walk the row until the stop sign (runtime)

If you don't know the length ahead of time — say, somebody else hands you a pointer to a C string and you need to figure out how long it is — you have to actually look at each byte. That's what `strlen` does.

```asm
        lea     rsi, [rip + name]       # rsi = pointer to first byte
        xor     rcx, rcx                # rcx = count, starts at 0
.scan:
        mov     al, [rsi + rcx]         # peek the byte at offset rcx
        test    al, al                  # is it zero?
        jz      .done                   # yes — stop
        inc     rcx                     # no — count it and keep looking
        jmp     .scan
.done:
```

**In plain words, step by step:**

1. Load the address of the first letter into `rsi`. (Source index — the standard register for "I'm reading from here.")
2. Set the counter `rcx` to zero. This is going to be our answer.
3. Peek at the byte at `[rsi + rcx]` — that's the array-indexing addressing mode from Part 06. `rsi` is the base, `rcx` is the index, each element is one byte wide so there's no `*scale` needed.
4. `test al, al` is a sneaky way to ask "is `al` zero?" — it ANDs `al` with itself and sets the zero flag based on the result, without changing anything. (Same answer as `cmp al, 0`, but encoded shorter.)
5. If it was zero, we've found the stop sign — jump to `.done`. Otherwise, add one to the counter and loop.

**Gotcha.** Notice we never *advance* `rsi`. We keep `rsi` pinned to the start and let `rcx` walk outward. That's deliberate: at the end, `rcx` is both the length **and** the offset of the NUL byte. Two birds, one register.

**Aside: the official x86 way.** There is a one-instruction-plus-prefix version of this loop using `repne scasb` that the textbook chapter shows. We're sticking with the manual scan here because every line is something you've seen before. We'll meet the `rep`-family in topic 3.

## The full program

[`01_strings_and_length.s`](01_strings_and_length.s) puts both ideas to work. It prints a fixed greeting (using a compile-time length), then walks `name` to find its length at runtime, then prints `length of "Ada" is 3` by jamming the single digit into a scratch buffer.

```asm
.intel_syntax noprefix

        .section .data
greet:  .ascii  "Hello, strings!\n"
        .equ    greetlen, . - greet

name:   .asciz  "Ada"

prefix: .ascii  "length of \"Ada\" is "
        .equ    prefixlen, . - prefix

        .section .bss
digit:  .skip   2

        .section .text
        .globl  _start
_start:
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + greet]
        mov     rdx, greetlen
        syscall

        lea     rsi, [rip + name]
        xor     rcx, rcx
.scan:
        mov     al, [rsi + rcx]
        test    al, al
        jz      .done
        inc     rcx
        jmp     .scan
.done:
        add     rcx, '0'
        mov     [rip + digit], cl
        mov     byte ptr [rip + digit + 1], '\n'

        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + prefix]
        mov     rdx, prefixlen
        syscall

        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + digit]
        mov     rdx, 2
        syscall

        mov     rax, 60
        xor     rdi, rdi
        syscall
```

**The technical layer.** Two details worth pausing on:

- `add rcx, '0'`. The character `'0'` is just the byte value `0x30` (48). The ASCII digits run `'0'..'9'` from 48 to 57 in order. So if `rcx` is the number 3, then `rcx + '0'` is 51, which is the byte that prints as the character `'3'`. That's the cheap way to turn a single-digit number into a printable character.
- `byte ptr [rip + digit + 1]`. `byte ptr` tells the assembler "the thing at this address is one byte wide" — needed because otherwise it can't tell whether you meant to write one byte, two, four, or eight at that spot. We use it when the destination is a memory location and the source is a small immediate.

## Build and run

```bash
as -o /tmp/_t.o 01_strings_and_length.s
ld -o /tmp/_t /tmp/_t.o
/tmp/_t
```

Expected output (verbatim):

```
Hello, strings!
length of "Ada" is 3
```

**Check yourself.** What happens if you change `name: .asciz "Ada"` to `name: .ascii "Ada"` (no NUL)? (Answer: your scan loop walks off the end of `name` into whatever bytes happen to come next in `.data`, counting them too, until it eventually finds a zero somewhere — possibly never. That's the whole danger of NUL-terminated strings: they only work if the NUL is actually there.)

## Try it

1. Change the string to `"Augusta"` (and keep the rest of the program alone). The scan still works — but the digit-printing only fits a single digit, so the displayed answer is wrong. Either teach the program to print two digits, or shorten the string back.
2. Replace the manual scan with `test byte ptr [rsi + rcx], 0` and `jne` — same idea, slightly different encoding. Did it still produce the right answer?
3. Add a second runtime string and reuse the scan as a labeled block you can fall into. (Spoiler: once you're doing that twice, you're ready for topic 10's functions.)

## Next

Strings are arrays of bytes. Topic 2 is about arrays of bigger things — 8-byte integers — and the `[base + index*scale]` trick that lets the CPU multiply the index by the element size for free.
