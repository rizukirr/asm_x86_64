# 11.02 — Being called from C

## A story: the indistinguishable specialist

**In plain words:** in the last topic we phoned `printf`. Now we flip the call: a C program is going to phone *us*. As long as our assembly follows the calling convention, the C compiler can't tell — and doesn't care — that the function on the other end of the call wasn't written in C.

**The analogy.** Imagine the phone book again. Some of the specialists in it are humans, some are robots, some are written in different languages, some are even hand-carved in stone. To the caller, none of that matters. You dial the number, speak in the agreed protocol ("first detail goes here, second detail goes there, hold for the answer"), and get back a result. The implementation is a black box. We are about to be one of those black boxes.

**The technical layer.** The agreed protocol is the **System V AMD64 ABI**. It pins down:

- Where the first six integer/pointer arguments live (`rdi`, `rsi`, `rdx`, `rcx`, `r8`, `r9`).
- Where the return value goes (`rax`).
- Which registers the callee is allowed to clobber (`rax`, `rcx`, `rdx`, `rsi`, `rdi`, `r8`–`r11` — "caller-saved").
- Which registers the callee must preserve if it uses them (`rbx`, `rbp`, `r12`–`r15` — "callee-saved").
- That `rsp` must be 16-byte aligned at the moment of every `call`.

Honor those rules and you are indistinguishable from a C function.

**Check yourself.** If our asm `sum3` clobbers `rbx` without saving it, what would go wrong? (Answer: the C caller likely had a value stashed in `rbx` across our call. When control returns, `rbx` has been silently corrupted. The bug shows up *somewhere else* — the worst kind.)

## The code

See [`02_called_from_c.c`](02_called_from_c.c):

```c
#include <stdio.h>

extern long sum3(long a, long b, long c);

int main(void) {
    long r = sum3(10, 20, 30);
    printf("%ld\n", r);
    return r == 60 ? 0 : 1;
}
```

And [`02_called_from_c.s`](02_called_from_c.s):

```asm
.intel_syntax noprefix

        .section .text
        .globl  sum3

# long sum3(long a, long b, long c);
# args:   rdi = a, rsi = b, rdx = c
# return: rax = a + b + c
sum3:
        mov     rax, rdi
        add     rax, rsi
        add     rax, rdx
        ret
```

## Build and run

```bash
gcc -no-pie 02_called_from_c.s 02_called_from_c.c -o /tmp/demo && /tmp/demo
# => 60
```

**In plain words:** `gcc` assembles our `.s` to an object file, compiles the `.c` to another object file, then links them together along with crt0 and libc. The linker matches the C side's reference to `sum3` with our assembly's `sum3:` label, and the program runs.

## Dissecting it

### The C side

**In plain words:** `extern long sum3(long, long, long);` is a promise to the C compiler. It says "somewhere out there is a function with this signature; trust me, the linker will find it."

**The technical layer.** Without the `extern` declaration the C compiler would have no idea how to call `sum3` — it wouldn't know how many arguments, what types, or what comes back. With the declaration, the compiler emits a perfectly normal call: load `10` into `rdi`, `20` into `rsi`, `30` into `rdx`, then `call sum3`. The fact that the body is hand-written assembly is irrelevant.

**Gotcha.** The types in the `extern` declaration must match what your assembly actually expects. If you declare `extern int sum3(...)` but your asm reads full 64-bit registers, the upper 32 bits of each argument are *not* guaranteed to be zero. Mismatched signatures are a classic source of "works on my machine" bugs.

### The asm side, line by line

```asm
.globl  sum3
```

**In plain words:** make the `sum3` label visible to the linker. Without `.globl`, the symbol is private to this object file and the linker complains about an undefined reference.

```asm
sum3:
        mov     rax, rdi        # rax = a
        add     rax, rsi        # rax = a + b
        add     rax, rdx        # rax = a + b + c
        ret
```

**In plain words:** copy the first argument into `rax`, add the second, add the third, return.

**The technical layer.** We touched only `rax`, which is caller-saved — the C caller already assumes its previous value is gone. We didn't touch any callee-saved register (`rbx`, `rbp`, `r12`–`r15`), so we don't need to push anything. We didn't `call` any other function, so the 16-byte alignment requirement is trivially satisfied (we never invoke a `call` instruction). We don't even need a stack frame.

**Gotcha — the no-call shortcut.** This function is a **leaf function** (it never calls anything else), so we can skip the `push rbp` / `pop rbp` prologue entirely. The moment you add a `call` to a libc function from inside `sum3`, you must restore the alignment dance from [01_calling_libc](01_calling_libc.md).

### What the C compiler emits at the call site

If you compile a tiny C wrapper with `gcc -O2 -S -masm=intel -c`, you'll see the caller side does literally this:

```asm
mov     edx, 30
mov     esi, 20
mov     edi, 10
call    sum3
```

(Notice `edx`/`esi`/`edi` instead of the full 64-bit names — for small positive constants, writing to the 32-bit half automatically zeros the upper 32 bits. Same trick we saw in Part 01.) Our asm reads `rdx`/`rsi`/`rdi` and gets the correct 64-bit values for free.

## Check yourself

1. Change `sum3` to compute `a * b + c` (try `imul rax, rsi` then `add rax, rdx`). Rebuild. Verify `10 * 20 + 30 = 230`.
2. Add a deliberate ABI violation: insert `mov rbx, 0xdeadbeef` at the top of `sum3` (without saving `rbx` first). Build with `gcc -O0` so the caller likely uses `rbx`. You may not see a bug immediately — that's the point. Add `-O2` and call `sum3` inside a loop that uses `rbx`. Now things break in subtle ways.
3. Write a second asm function `imul3` that returns `a * b * c`. Call both from the same C `main`. You'll see how trivial it is to grow an asm-side library.

## Next

[03_stack_alignment](03_stack_alignment.md) — the 16-byte rule that bites everyone exactly once.
