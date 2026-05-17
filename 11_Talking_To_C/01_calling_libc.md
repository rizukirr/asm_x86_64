# 11.01 — Calling libc from assembly

## A story: dialing a friend who has every tool

**In plain words:** until now your assembly programs have been hermits. They started, ran a couple of syscalls by hand, and exited. From here on, you get to phone a friend — the C standard library — who has already written thousands of useful routines: `printf`, `scanf`, `malloc`, `strlen`, and the rest.

**The analogy.** Imagine you've been living in that apartment building from Part 01, only ever sliding forms under the manager's door (syscalls). Today, somebody hands you a phone book. Every name in it is a specialist who already wrote the code for something useful. You want text on the screen? Dial `printf`. You want memory? Dial `malloc`. You don't have to fill out the manager's strict little form anymore — you just dial the number and speak normally.

**The technical layer.** The phone book is **libc** — the C standard library — a giant pre-compiled blob of C code shipped with every Linux system. To dial it, two things change about how we build:

1. We let **`gcc`** glue our program together instead of **`ld`** directly. `gcc` quietly drops in a small piece of startup code called **crt0** ("C runtime, version zero"). crt0 provides `_start`, sets up `argc`/`argv`/`envp`, calls our `main`, and on return passes our exit status to the kernel.
2. Functions we define in assembly now follow the **System V AMD64 ABI**: args in `rdi`, `rsi`, `rdx`, `rcx`, `r8`, `r9`; return in `rax`; stack 16-byte aligned at every `call`.

For this first demo we keep `main` itself in a tiny C file (so `gcc` has something to attach crt0 to), and put the libc-calling routine in assembly under the name `asm_main`. The C `main` is a one-liner that just calls `asm_main`.

**Check yourself.** Why don't we just make `main` itself the assembly label? (Answer: we could — and people do — but separating the two keeps each file focused on one job. The C file owns "be the entry point"; the asm file owns "call printf the right way." Either approach works.)

## The code

[`01_calling_libc.c`](01_calling_libc.c) is the one-line C driver:

```c
extern void asm_main(void);

int main(void) {
    asm_main();
    return 0;
}
```

And [`01_calling_libc.s`](01_calling_libc.s) is where the libc call actually happens:

```asm
.intel_syntax noprefix

        .section .rodata
fmt:    .asciz  "Hello from asm, x = %d\n"

        .section .text
        .globl  asm_main
        .extern printf

asm_main:
        push    rbp                     # save caller's rbp; also realigns rsp to 16
        lea     rdi, [rip + fmt]        # arg 1: format string
        mov     rsi, 42                 # arg 2: x
        xor     eax, eax                # 0 vector regs used for varargs
        call    printf
        pop     rbp
        ret
```

## Build and run

```bash
gcc -no-pie 01_calling_libc.s 01_calling_libc.c -o /tmp/demo && /tmp/demo
# => Hello from asm, x = 42
```

**In plain words:** `gcc` is doing three jobs at once here — calling the assembler on our `.s`, calling the linker on the result, and pulling in crt0 plus libc along the way. We pass `-no-pie` so the call to `printf` can be linked as a plain direct call. (Position-independent code uses an extra layer of indirection called the PLT; we cover that in [04_pie_plt_got](04_pie_plt_got.md).)

## Dissecting it

### `.section .rodata` and `.asciz`

**In plain words:** put the format string in the read-only data shelf, with a hidden zero byte at the end.

**The technical layer.** `.rodata` is the read-only data section — perfect for string literals nobody should be allowed to modify. `.asciz` writes the characters of the string into memory **followed by a NUL terminator** (`0x00`). The zero byte is the end-of-string marker every C string function looks for.

**Gotcha.** If you write `.ascii` instead of `.asciz`, there is no terminating zero. `printf` will then keep reading past the end of your string into whatever bytes happen to live next in memory — printing garbage, or crashing once it runs into unmapped memory. The single letter `z` is the difference between "works" and "intermittent segfaults."

### `.globl asm_main` and `.extern printf`

**In plain words:** `.globl asm_main` says "make `asm_main` visible to the linker so the C side can find us." `.extern printf` says "trust me, there's a function called `printf` somewhere else — the linker will glue it in."

**The technical layer.** `.extern` is technically optional with GNU `as` (any unresolved symbol is treated as external automatically), but writing it documents intent. The linker pairs every unresolved symbol with a definition from one of the object files or libraries it was given.

### Arguments: rdi, rsi, rdx, rcx, r8, r9

**In plain words:** the System V AMD64 ABI says the first six integer/pointer arguments go in these specific registers, in this order.

**The analogy / table.** Six labelled cups on the desk, in a fixed order:

| Argument | Register |
| -------- | -------- |
| 1st      | `rdi`    |
| 2nd      | `rsi`    |
| 3rd      | `rdx`    |
| 4th      | `rcx`    |
| 5th      | `r8`     |
| 6th      | `r9`     |

A 7th argument and beyond gets pushed on the stack in reverse order. The return value comes back in `rax`.

`printf("Hello from asm, x = %d\n", 42)` has two arguments, so we put the format string's address in `rdi` and the integer `42` in `rsi`. That's it.

### `xor eax, eax` before a variadic call

**In plain words:** `printf` is special — it takes a variable number of arguments. The ABI says you have to tell it, in `al`, how many of those variadic arguments are floating-point values you stuffed into the `xmm` (vector) registers. We pass zero floats, so `al = 0`.

**The technical layer.** Setting `eax` to 0 (which also zeros `al`, the low byte of `eax`) satisfies the ABI cheaply. `xor eax, eax` is the shortest possible way to encode "set this register to 0."

**Gotcha.** If you forget this, `printf` may decide to fish floating-point arguments out of `xmm0`..`xmm7` even though you never put any there. Whatever garbage is in those registers will get formatted as a giant float. Sometimes you get nonsense, sometimes a segfault.

### `push rbp` for alignment

**In plain words:** before `call printf`, the stack pointer must be aligned to a multiple of 16. On entry to `asm_main`, it isn't — it's off by 8. One `push` fixes it.

**The technical layer.** The SysV ABI requires `rsp ≡ 0 (mod 16)` at the moment any `call` instruction is executed. The `call` itself pushes an 8-byte return address, so on entry to a callee, `rsp ≡ 8 (mod 16)`. Pushing one more 8-byte value (here `rbp`) brings us back to `0 (mod 16)`. The matching `pop rbp` before `ret` undoes it.

This is covered in depth in [03_stack_alignment](03_stack_alignment.md). For now, the rule of thumb: **odd number of pushes before a `call` to libc.**

### Return value

**In plain words:** `asm_main` returns `void`, so we don't bother setting `rax`. The C `main` returns 0 normally, and crt0 hands that 0 to the kernel as our exit status.

## Check yourself

1. Change `42` to your favorite number. Rebuild. Run. The new value should print.
2. Delete the `xor eax, eax` line just before `call printf` (leave the one for the return value). Rebuild. Most systems will still print correctly because `eax` happened to be zero on entry, but this is fragile — on a different platform or build, it can segfault. Now add `mov eax, 7` before the call and rerun. It probably still works, but on a stricter libc build (or with floating-point format specifiers) it would crash.
3. Use `strace -e trace=write ./demo` to see the underlying `write` syscall `printf` ultimately makes. The `printf` we called is itself implemented on top of the same syscalls we used in Part 01.

## Next

[02_called_from_c](02_called_from_c.md) — flip the direction: write a function in assembly that a C program calls.
