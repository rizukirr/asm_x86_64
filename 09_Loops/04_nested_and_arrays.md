# 09.4 — Nested Loops and Array Walks

## A story: rows and columns of seats in a theater

**In plain words:** a nested loop is just a loop *inside* a loop. The outer one says "this row," the inner one says "every seat in this row."

**The analogy.** An usher checks every seat in a theater. They walk down the **rows** from front to back. For each row, they walk across the **seats** from left to right. The seat-walk is the inner loop. The row-walk is the outer loop. If there are 3 rows and 3 seats per row, the usher checks `3 × 3 = 9` seats total.

**The technical layer.** Two counters. Two `jcc` branches. The inner loop must **reset its counter** at the start of every outer iteration — that's the only thing easy to forget.

```text
outer counter = 3
.outer:
        inner counter = 3
.inner:
        ; one seat
        dec inner counter
        jnz .inner
        dec outer counter
        jnz .outer
```

**Check yourself.** If the outer loop runs 3 times and the inner runs 4 times, how many times does the inner body execute total? (Answer: 12.)

## Walking an array

**In plain words:** an array is just a block of memory holding values of the same size, back-to-back. To visit them you need a **base address** (where the array starts) and an **index** (which element you're on).

**The analogy.** Mailboxes in a small apartment building, all the same width. To find mailbox number 7, you start at mailbox number 0 and walk seven steps forward. The starting address is the base; "seven" is the index; "the width of one mailbox" is called the **stride**.

**The technical layer.** x86_64 has a single addressing mode that does this in one instruction:

```asm
[base + index*scale + disp]
```

- `base` and `index` are registers.
- `scale` is 1, 2, 4, or 8 (the stride — matching byte/word/dword/qword).
- `disp` is an optional constant offset.

So `mov rax, [r14 + rcx*8]` reads as "fetch the 8-byte value at address `r14 + rcx*8`" — i.e., element `rcx` of an array of 8-byte values whose base is in `r14`. The CPU does the multiply for free as part of the address calculation. We covered this in [Part 06](../06_Addressing/README.md); loops are where it really pays off.

**Gotcha.** Only 1/2/4/8 are valid scales. You cannot say `[r14 + rcx*3]`. For odd strides you must compute the offset yourself with a separate `imul` or by carrying a pointer instead of an index.

## The program

Two demos in one program:

1. Print a 3×3 grid of `*` characters with a nested loop.
2. Sum a 6-element array of 8-byte integers (`1 + 2 + 3 + 4 + 5 + 6 = 21`) and print `sum=21`.

See [`04_nested_and_arrays.s`](04_nested_and_arrays.s):

```asm
        # ---- nested loop: 3 rows of 3 stars ----
        mov     r12, 3                  # outer counter
.row:
        mov     r13, 3                  # inner counter (reset each row!)
.col:
        mov     rax, 1                  # write(1, &star, 1)
        mov     rdi, 1
        lea     rsi, [rip + star]
        mov     rdx, 1
        syscall
        dec     r13
        jnz     .col

        mov     rax, 1                  # write a newline
        mov     rdi, 1
        lea     rsi, [rip + nl]
        mov     rdx, 1
        syscall

        dec     r12
        jnz     .row
```

```asm
        # ---- array sum ----
        xor     rax, rax                # running sum
        xor     rcx, rcx                # i = 0
        lea     r14, [rip + arr]        # base pointer
.sum:
        cmp     rcx, arrlen
        jge     .sum_done
        add     rax, [r14 + rcx*8]      # sum += arr[i]
        inc     rcx
        jmp     .sum
.sum_done:
```

## Build and run

```bash
as -o 04.o 04_nested_and_arrays.s
ld -o 04 04.o
./04
# =>
# ***
# ***
# ***
# sum=21
```

## Dissecting it

### Why `r12` and `r13` for the counters?

**In plain words:** both loops contain `syscall`s, which would wipe `rcx`/`r11`. The callee-saved registers `r12`–`r15` survive across syscalls and function calls, so we use those.

**The technical layer.** The x86_64 System V ABI splits the 16 general registers into two groups:

| Group        | Registers                                | Survives a `call`/`syscall`? |
| ------------ | ---------------------------------------- | ---------------------------- |
| Caller-saved | `rax`, `rcx`, `rdx`, `rsi`, `rdi`, `r8`–`r11` | No — you must save them yourself |
| Callee-saved | `rbx`, `rbp`, `r12`–`r15`, `rsp`          | Yes — the callee restores them   |

For loop counters around a function call or syscall, callee-saved is the lazy-and-correct default. We meet the full ABI in [Part 10](../10_Functions/README.md).

### Reset the inner counter every outer iteration

**In plain words:** if you forget to put `mov r13, 3` *inside* `.row:`, the inner loop runs three times the first row and zero times every other row.

**Gotcha.** This is one of the most common nested-loop bugs. Always re-initialize loop state at the top of the outer body, not above it.

### The array sum, line by line

```asm
        xor     rax, rax                # running sum
        xor     rcx, rcx                # i = 0
        lea     r14, [rip + arr]        # base pointer to arr[0]
.sum:
        cmp     rcx, arrlen             # i vs length
        jge     .sum_done               # exit when i >= length
        add     rax, [r14 + rcx*8]      # sum += arr[i]
        inc     rcx                     # i++
        jmp     .sum
.sum_done:
```

**In plain words:**

1. `rax` is the running total. Start at 0.
2. `rcx` is the index `i`. Start at 0.
3. `r14` points at `arr[0]`.
4. Each lap: check if we're done. If `i >= length`, exit. Otherwise add `arr[i]` to the total and bump `i`.

The line `add rax, [r14 + rcx*8]` is the star of the show: in one instruction, the CPU computes the address `r14 + rcx*8`, loads 8 bytes from there, and adds them to `rax`.

**Where does `arrlen` come from?** From `.equ arrlen, (. - arr) / 8` in the data section: "the byte distance from `arr` to here, divided by 8 bytes per element." Same compile-time-arithmetic trick as `msglen` back in [Part 01](../01_Hello_CPU/README.md), now used to avoid hardcoding "6."

### `cmp rcx, arrlen ; jge .done` — signed compare

**In plain words:** "exit when `i` is greater than or equal to the length." Use `jge` (signed) because our counters are normal integers.

**The technical layer.** For an array of `n` elements, valid indices are `0..n-1`. The natural exit condition is `i >= n`, written `jge` (signed) or `jae` (unsigned). For small positive `n` they behave the same. As discussed in [09.2](02_while_dowhile.md), pick one and stick with it.

## A common nested-loop trap: clobbering the outer counter

**In plain words:** if the inner loop calls a helper function (or a syscall), that helper might overwrite the outer counter. Suddenly your outer loop runs the wrong number of times.

**The technical layer.** The fix is to use callee-saved registers for outer-loop state, *or* to push/pop the counter across the call.

```asm
.outer:
        push    rcx                     # save outer counter
        call    helper
        pop     rcx                     # restore
        ; ...
        dec     rcx
        jnz     .outer
```

We use `r12`/`r13` in the demo, which avoids the push/pop dance entirely.

## Try it

1. Change the grid to 5 rows of 7 stars. Make sure the inner counter resets correctly.
2. Add a third element type to the array (`.quad 100`) and check the sum updates to 121 without you touching `arrlen`.
3. Rewrite the sum loop to walk a pointer instead of an index: keep `r14` as the current pointer, `add r14, 8` each step, and stop when `r14 == arr + arrlen*8`.

## What's next

That wraps up loops. You can now express any iteration pattern — counted, conditional, nested, array-walking — using nothing but `cmp`/`test` and a handful of `jcc` variants.

The next chapter introduces **functions**: how to break a program into reusable pieces with `call` and `ret`, and the calling convention that makes those pieces play nicely with each other. → [Part 10 — Functions](../10_Functions/README.md)
