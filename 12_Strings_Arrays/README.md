# Part 12 — Strings & Arrays

## The picture first: a row of mailboxes

Imagine the wall of mailboxes in an apartment building lobby. Each box is the same size. They sit right next to each other. They are numbered 0, 1, 2, 3, and so on.

That is an **array**. It is a row of identical-size lockers, sitting next to each other in memory, numbered starting at 0. Nothing fancier than that.

A **string** is the same idea, but each locker holds exactly one letter. The word `"hello"` is five lockers in a row holding `h`, `e`, `l`, `l`, `o`. To know where the word ends, C puts one extra locker on the end holding the special "I'm done" marker called `\0` (a single byte with value zero). That marker is called the **NUL byte** (one L — different from the word "null").

So when somebody says "a C string is an array of bytes ending in `\0`," that is the whole secret. A row of one-letter lockers, with a stop sign at the end.

## Why x86 has special tools for this

Walking down a row of mailboxes — copy from this row into that row, search a row for a specific letter, compare two rows letter-by-letter — is something programs do constantly. So the CPU designers added a handful of instructions that are wired specifically for that job, plus a one-word repeater (`rep`) that turns any of them into a tireless robot. We will use the robot analogy a lot:

> `rep movsb` is a tireless robot that copies one byte from one shelf to another, then takes one step forward on both shelves, then does it again, over and over, until the counter runs out.

That is the whole idea. Everything below is the small print on how to wind the robot up before letting it go.

## The implicit-operand instructions

"Implicit operand" is jargon for "the instruction already knows which register to read and which to write — you don't tell it, it has favorites baked in."

These instructions follow a fixed pattern:

- `rsi` is the **source pointer**. Think: "the shelf I'm reading from." (`S` for source.)
- `rdi` is the **destination pointer**. Think: "the shelf I'm writing to." (`D` for destination.)
- `rcx` is the **counter**, when used with `rep`. Think: "how many more times do I repeat?"
- The **direction flag** (`DF`) is a one-bit switch in the CPU that says which way the robot walks. `DF=0` means forward (locker 0, 1, 2, …). `DF=1` means backward.

| Mnemonic        | What it does                                            | Step          |
| --------------- | ------------------------------------------------------- | ------------- |
| `movsb`         | `[rdi] = [rsi]`; `rsi±1`; `rdi±1`                       | 1 byte        |
| `movsw/d/q`     | same, 2 / 4 / 8 bytes                                   | 2/4/8         |
| `stosb`         | `[rdi] = al`; `rdi±1`                                   | 1 byte        |
| `stosw/d/q`     | `[rdi] = ax/eax/rax`; `rdi±N`                           | 2/4/8         |
| `lodsb`         | `al = [rsi]`; `rsi±1`                                   | 1 byte        |
| `scasb`         | compare `al` with `[rdi]`; `rdi±1`                      | 1 byte        |
| `cmpsb`         | compare `[rsi]` with `[rdi]`; both `±1`                 | 1 byte        |

Translating the cryptic names:

- `movs` = **mov**e **s**tring (copy one shelf to another)
- `stos` = **sto**re into **s**tring (write the value in `al`/`ax`/etc into the destination)
- `lods` = **lo**a**d** from **s**tring (read the destination into `al`/`ax`/etc)
- `scas` = **sca**n **s**tring (search the destination for whatever is in `al`)
- `cmps` = **c**o**mp**are **s**tring (compare both shelves byte-by-byte)
- The trailing letter is the size: `b`=1 byte, `w`=2 bytes, `d`=4 bytes, `q`=8 bytes.

Set the direction flag with `cld` (**cl**ear **d**irection → forward) and `std` (**s**e**t d**irection → backward). After a `cld` you can forget about it. The System V calling convention requires `DF=0` whenever you call a function, so it's almost always already zero.

## The `rep` prefix — the tireless robot

Stick `rep` in front of any of those instructions and it becomes a counted loop. The CPU keeps running that one instruction over and over, decrementing `rcx` each time, until `rcx` hits zero.

```asm
        mov     rcx, n
        rep     movsb                   # while (rcx--) { *rdi++ = *rsi++; }
```

What this actually does, in plain words: "Put the number of bytes I want to copy in `rcx`. Then say `rep movsb`. The CPU copies one byte from the source shelf to the destination shelf, steps both pointers forward, subtracts one from `rcx`, and keeps going until `rcx` runs out."

That is a full `memcpy` (copy-this-block-of-memory function) in essentially three instructions: load source pointer, load destination pointer, load count, `rep movsb`. On modern CPUs the microcode (built-in firmware) for `rep movsb` is heavily optimized — for medium-to-large copies it competes with hand-tuned vector code. For tiny fixed sizes, the compiler usually unrolls into a few plain `mov`s.

Three flavors of the prefix:

| Prefix    | Repeat while…                          | Used with        |
| --------- | -------------------------------------- | ---------------- |
| `rep`     | `rcx > 0`                              | `movs/stos/lods` |
| `repe`    | `rcx > 0` **and** `ZF = 1`             | `cmps`, `scas`   |
| `repne`   | `rcx > 0` **and** `ZF = 0`             | `cmps`, `scas`   |

`ZF` is the **zero flag** — a tiny one-bit memory in the CPU that gets set to 1 whenever the last comparison or subtraction came out equal/zero. So `repe` means "keep going while still equal," and `repne` means "keep going while not yet equal." Those are exactly what you want for searching and comparing.

`repne scasb` is the classic asm `strlen`: scan one byte at a time looking for a NUL, and stop the moment you find one.

## A worked example: asm strlen

`strlen` is short for "string length." You hand it a pointer to the first letter of a string, and it tells you how many letters there are before the `\0` stop sign.

```asm
.intel_syntax noprefix
        .text
        .globl  my_strlen

# size_t my_strlen(const char *s);   // s in rdi
my_strlen:
        mov     rcx, -1                 # rcx = max iterations (~infinity)
        xor     al, al                  # search for 0
        cld
        repne   scasb                   # advance rdi until *rdi == 0
        # rcx counted down. Length = (-1 - rcx) - 1 = ~rcx - 1.
        not     rcx                     # rcx = -rcx - 1 = bytes scanned
        dec     rcx                     # subtract the NUL we stopped on
        mov     rax, rcx
        ret
```

What this actually does, in plain words:

1. Set `rcx` to `-1`, which when treated as unsigned is the biggest possible number. We never plan to run out — we plan to stop when we find the NUL.
2. Put `0` into `al`, because that is the byte we are hunting for.
3. `cld` makes sure we are walking forward.
4. `repne scasb`: "Compare `al` to whatever is at `rdi`. Step `rdi` forward. Subtract one from `rcx`. If we found a match (the NUL byte), stop. Otherwise, repeat."
5. After it stops, do a tiny bit of arithmetic to figure out how far we walked. `not rcx` flips every bit, which on a number that started at `-1` gives us the count of steps taken. We subtract one more because the NUL itself doesn't count as a letter.
6. Return that length in `rax`.

Drive it from C to test:

```c
#include <stdio.h>
extern unsigned long my_strlen(const char*);
int main(void){ printf("%lu\n", my_strlen("hello, world")); return 0; }
```

```bash
gcc -no-pie main.c my_strlen.s -o slen
./slen
# => 12
```

## A worked example: asm memcpy

`memcpy` is the function that copies a chunk of memory from one place to another. "Memory copy."

```asm
# void *my_memcpy(void *dst, const void *src, size_t n);
# rdi = dst, rsi = src, rdx = n
my_memcpy:
        mov     rax, rdi                # save dst for the return value
        mov     rcx, rdx
        cld
        rep     movsb                   # *dst++ = *src++ for n bytes
        ret
```

What this actually does, in plain words: "Remember the destination pointer in `rax` so we can return it. Copy the count out of `rdx` into `rcx` (because `rep` reads its counter from `rcx`). Make sure we walk forward. Then let the robot run."

Real-world `memcpy` implementations do exactly this for some size ranges, and switch to wider vector copies for others. But the three-line version is correct and surprisingly fast on modern hardware.

## Manual loops (when string instructions are too rigid)

The string instructions are great if your job is exactly "copy" or "compare" or "search." When you need to do something they can't — multiply each item, filter it, transform it — you write a plain indexed loop.

Picture this: a row of lockers, each one big enough to hold an 8-byte number. You want to multiply every number in the row by some constant `k`.

```asm
# void scale(int64_t *arr, size_t n, int64_t k);
scale:
        xor     rax, rax                # i = 0
.loop:
        cmp     rax, rsi                # i < n ?
        jge     .done
        mov     rcx, [rdi + rax*8]
        imul    rcx, rdx                # rcx *= k
        mov     [rdi + rax*8], rcx
        inc     rax
        jmp     .loop
.done:
        ret
```

What this actually does, in plain words: "Start with index `i = 0`. While `i` is less than `n`, fetch locker number `i` from the row (each locker is 8 bytes wide, so the byte address is the start of the row plus `i*8`), multiply it by `k`, write it back into the same locker, add one to `i`, and repeat."

`[rdi + rax*8]` is the indexing trick from [Part 06](../06_Addressing/README.md): one instruction is the array access *plus* the index scaling. The CPU does the multiply-by-8 for free as part of figuring out the address.

```
arr:   [ a0 ][ a1 ][ a2 ][ a3 ][ a4 ] ...
index:   0     1     2     3     4
byte:    0     8    16    24    32      <- rax*8
```

## Try it

1. Implement `my_strcmp(const char *a, const char *b)`. Hint: a loop, two `mov`s, a `cmp`. Or learn `repe cmpsb` and do it in five instructions.
2. Implement `reverse_array(int64_t *arr, size_t n)` using two indices that move toward each other.
3. Benchmark `rep movsb` vs a hand-rolled 8-byte `mov` loop for 1 KiB, 1 MiB, and 1 GiB copies. Modern CPUs surprise you.

## What's next

We've been calling `syscall` since Part 01 without dwelling on it. [Part 13](../13_Syscalls/README.md) takes a proper look at how Linux syscalls work, the table, and when to bypass libc.
