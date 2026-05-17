# 12.2 — Arrays and `[base + index*scale]`

## The picture first: a row of equal-size shelves

**In plain words:** an array is a row of identical-size shelves sitting next to each other in memory. To get from one shelf to the next, you walk forward by exactly the size of one shelf.

**The analogy.** A string was a row of one-byte lockers. An array of 64-bit integers is the same idea, but every shelf is **eight bytes wide** — wide enough to hold one 64-bit number. So:

```
arr:   [  a0  ][  a1  ][  a2  ][  a3  ][  a4  ]
index:    0       1       2       3       4
byte:     0       8      16      24      32
```

The byte address of element `i` is "the start of the array, plus `i * 8`." That little multiplication — index times element size — is so common that the CPU has a special addressing mode that does it for free.

## Reserving space in `.data` vs `.bss`

**In plain words:** if you know the values up front, put them in `.data`. If you just want a blank slate to fill in later, put them in `.bss`. The difference is whether the values travel inside the program file.

```asm
        .section .data
nums:   .quad   10, 20, 30, 7, 8        # five 8-byte integers, pre-filled

        .section .bss
out:    .skip   2                        # two blank bytes, zeroed at load
```

- `.quad` emits a **q**uadword — eight bytes — per number. Friends in the family: `.byte` (1), `.word` (2), `.long` (4), `.quad` (8). Pick the one that matches the size of element you want.
- `.skip N` reserves `N` bytes of room. In `.bss`, those bytes don't get stored inside the program file at all — the operating system just hands you a block of zeros when the program starts. That's why `.bss` is "free" no matter how big it gets: a 10 MiB `.bss` adds zero bytes to your executable on disk.

**Gotcha.** Don't put `.quad` declarations in `.bss`. The whole point of `.bss` is "no initial value" — only `.skip` (or the related `.zero`/`.lcomm`) belongs there. Conversely, you *can* `.skip` inside `.data`, but it wastes file space (the zeros end up in the on-disk binary).

## Counting elements at assemble time

**In plain words:** the same `. - label` trick from strings tells you how many bytes an array takes up. Divide by the element size to get the number of elements.

```asm
nums:   .quad   10, 20, 30, 7, 8
        .equ    nums_count, (. - nums) / 8
```

That sets `nums_count = 5`. If you add or remove a number from the list, the count updates automatically the next time you assemble. No hand-counting, no off-by-one. The assembler does the arithmetic before your program ever runs.

## The address calculation: `[base + index*scale]`

**In plain words:** the CPU lets you write the address of "the i-th element of an array whose element size is N" as one tiny expression inside square brackets, and it does the multiplication for free.

```asm
        mov     rax, [rdi + rcx*8]      # rax = arr[i], where arr is in rdi and i is in rcx
```

That single instruction reads "go to the address `rdi + rcx*8`, fetch eight bytes from there, put them in `rax`." The CPU evaluates `rcx*8` as part of figuring out the address — there is no separate multiply instruction.

**The technical layer.** This is the famous **SIB byte** addressing form (Scale-Index-Base) we met in Part 06. The `scale` is restricted to one of four values: 1, 2, 4, or 8 — which conveniently match the four element sizes byte / word / dword / qword. So:

| Element type      | Size | Indexing                  |
| ----------------- | ---- | ------------------------- |
| `.byte`           | 1    | `[base + index*1]` or just `[base + index]` |
| `.word`           | 2    | `[base + index*2]`        |
| `.long` (int32)   | 4    | `[base + index*4]`        |
| `.quad` (int64)   | 8    | `[base + index*8]`        |

**Check yourself.** If `nums` started at byte address 0x4000 and you executed `mov rax, [rip + nums + 3*8]`, where does the CPU read from? (Answer: 0x4000 + 24 = 0x4018 — the fourth element, value 7 in our table.)

**Gotcha.** That `*8` is *not* a runtime multiplication you wrote out. It's part of the instruction encoding. You can't put `*3` or `*5` there — those aren't legal scales, and the assembler will reject them. If your element size isn't 1/2/4/8 (a struct, say), you have to compute the offset by hand with a separate `imul`.

## The worked program: sum an array

[`02_arrays_and_indexing.s`](02_arrays_and_indexing.s) walks the five-element array and totals it.

```asm
.intel_syntax noprefix

        .section .data
nums:   .quad   10, 20, 30, 7, 8
        .equ    nums_count, (. - nums) / 8

label:  .ascii  "sum = "
        .equ    labellen, . - label

        .section .bss
out:    .skip   2

        .section .text
        .globl  _start
_start:
        xor     rax, rax                # total = 0
        xor     rcx, rcx                # i     = 0
.loop:
        cmp     rcx, nums_count
        jge     .done
        lea     rdx, [rip + nums]
        add     rax, [rdx + rcx*8]      # total += nums[i]
        inc     rcx
        jmp     .loop
.done:
        # ... convert rax to two ASCII digits and print ...
```

**In plain words, step by step:**

1. Zero out two registers: `rax` (which will hold the running total) and `rcx` (which is our loop index `i`).
2. Top of the loop: is `rcx` still less than `nums_count`? If not, we're done.
3. Load the base address of `nums` into `rdx`. (We can't write `[rip + nums + rcx*8]` directly in one instruction — RIP-relative addressing doesn't combine with an index register. So we first put the base in a regular register, then index off that.)
4. Add the i-th element to the running total. The `[rdx + rcx*8]` does the address arithmetic.
5. Bump the index, loop back.

When the loop ends, `rax` holds `10 + 20 + 30 + 7 + 8 = 75`.

**The technical layer.** Turning a small integer into two printable digits uses unsigned division by 10:

```asm
        mov     rbx, rax                # save original total (unused later, but tidy)
        xor     rdx, rdx
        mov     rcx, 10
        div     rcx                     # rax = total/10  (the tens digit)
                                        # rdx = total%10  (the ones digit)
        add     al, '0'
        mov     [rip + out], al
        add     dl, '0'
        mov     [rip + out + 1], dl
```

`div` is the unsigned division instruction. It takes its dividend from the register pair `rdx:rax` (treating them together as one 128-bit number — so we zero `rdx` first to mean "the dividend is just rax"), divides by whatever register we name, and writes the **quotient back into `rax`** and the **remainder into `rdx`**. So one `div` gives us both digits at once. Add the ASCII offset `'0'` to each, drop them in the buffer, print.

**Gotcha.** This trick only handles totals from 0 to 99. Any bigger and we'd need a real loop that peels off digits one at a time. We'll write a proper number-printing routine when we get to Part 14.

## Build and run

```bash
as -o /tmp/_t.o 02_arrays_and_indexing.s
ld -o /tmp/_t /tmp/_t.o
/tmp/_t
```

Expected output (verbatim):

```
sum = 75
```

## Try it

1. Add `100` to the array. `nums_count` updates automatically (that's the point of `. - nums / 8`). The total becomes 175 — which doesn't fit in two digits anymore. You'll see the math go off the rails. Fix it by widening the output to three digits.
2. Replace `.quad` with `.long` (32-bit elements). Now you need `[rdx + rcx*4]` and a 32-bit read like `mov eax, [rdx + rcx*4]`. Get it working and notice how the only thing that changes is the scale.
3. Reserve a 10-element array in `.bss` instead of `.data`. Fill it in `_start` with a small loop, then sum it. You've just built dynamic initialization without any C runtime help.

## Next

We've been writing the address arithmetic by hand. Topic 3 hands the work over to the CPU's built-in string-and-array instructions: `rep movsb` (copy a whole block), `rep stosb` (paint a whole block with one value), and friends.
