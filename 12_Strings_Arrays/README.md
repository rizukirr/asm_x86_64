# Part 12 — Strings & Arrays

## The picture first: a row of mailboxes

Imagine the wall of mailboxes in an apartment building lobby. Each box is the same size. They sit right next to each other. They are numbered 0, 1, 2, 3, and so on.

That is an **array**: a row of identical-size lockers, sitting next to each other in memory, numbered starting at 0. Nothing fancier than that.

A **string** is the same idea, but each locker holds exactly one letter. The word `"hello"` is five lockers in a row holding `h`, `e`, `l`, `l`, `o`. C marks the end of a string by adding one extra locker holding the special "I'm done" byte `0x00` — the **NUL byte** (one L — different from the word "null"). So a C string is "an array of bytes ending in `\0`." Whole secret.

Walking down those rows — copying, searching, counting, summing — is something programs do constantly. Modern x86 has a whole family of instructions and a one-word repeater (`rep`) wired specifically for that job. This part is a tour, split across three topics so each one can fit in your head.

## Topics

1. **[Strings and their length](01_strings_and_length.md)** — `.ascii` vs `.asciz`, computing length at assemble time with `. - label`, and walking a NUL-terminated string at runtime to find the NUL. Worked example: print `"Hello, strings!"`, then print the runtime-computed length of `"Ada"`.
2. **[Arrays and `[base + index*scale]`](02_arrays_and_indexing.md)** — laying integer arrays into `.data` vs reserving blank space in `.bss`, the `[base + index*scale]` addressing trick that does the index-times-element-size multiplication for free, and a complete loop that sums an array. Worked example: total `{10, 20, 30, 7, 8}` and print `sum = 75`.
3. **[`rep movsb` and `rep stosb`](03_rep_movsb_stosb.md)** — the tireless-robot instructions: `rep movsb` is a one-line `memcpy`, `rep stosb` is a one-line `memset`. Plus the supporting cast: `rsi`/`rdi`/`rcx`, the direction flag, and the `repe`/`repne` cousins for search and compare. Worked example: copy a string into a `.bss` buffer and print it, then paint seven `'*'` bytes with `stosb`.

## Build and run any topic's example

```bash
as -o /tmp/_t.o NN_topic.s
ld -o /tmp/_t /tmp/_t.o
/tmp/_t
```

Running all three together:

```bash
for f in *.s; do as -o /tmp/_t.o "$f" && ld -o /tmp/_t /tmp/_t.o && /tmp/_t; done
```

prints:

```
Hello, strings!
length of "Ada" is 3
sum = 75
copied with rep movsb
*******
```

## Next

We've been calling `syscall` since Part 01 without dwelling on it. [Part 13 — Syscalls](../13_Syscalls/README.md) takes a proper look at how Linux syscalls work, the full table, the return-value convention, and when to bypass libc.
