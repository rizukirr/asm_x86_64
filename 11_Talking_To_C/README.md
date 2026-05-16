# Part 11 — Talking to C

So far our programs have been **shut-ins**. They started, did their thing, and exited, without ever phoning anyone in the outside world. Everything was hand-written in assembly, even the request to the operating system to exit.

Imagine you finally **call up a friend who already wrote a huge book of helpful subroutines** — printing text, reading input, allocating memory, opening files. That book is the **C standard library**, usually called *libc*. Once your program can dial libc and be dialed by C programs, you suddenly have the whole world. Network sockets, file I/O, math, threads — all of it lives behind a libc function or a function written in C.

You've been writing freestanding asm linked with `ld`. Real code lives next to C. Once you can call libc and be called from C, the rest of the world opens up — sockets, files, math, threading, anything libc or another C library wraps.

**Plain words:** Up to now, we glued our `.o` file directly with `ld` (the linker) and started at our own `_start` label. That meant no helpers — we did every syscall by hand. From now on, we will glue with `gcc` instead, and start at `main`. The `gcc` driver pulls in a tiny bit of startup code called *crt0* (C runtime, version zero), which sets up the program, parses `argc`/`argv`, and then calls our `main`. In exchange we get to call any libc function we like.

## Calling C from asm

The trick: link with `gcc` instead of `ld`, and define `main` instead of `_start`. `gcc` pulls in the C runtime (`crt0`), which provides `_start`, sets up argv/envp, and eventually calls your `main`.

```asm
# hello_libc.s
.intel_syntax noprefix
        .section .rodata
fmt:    .asciz  "Hello from asm, x = %d\n"

        .section .text
        .globl  main
        .extern printf

main:
        push    rbp                     # keep rsp 16-aligned across the call
        lea     rdi, [rip + fmt]        # arg 1: format string
        mov     rsi, 42                 # arg 2: x
        xor     eax, eax                # 0 vector registers passed (varargs)
        call    printf
        xor     eax, eax                # return 0
        pop     rbp
        ret
```

Build:

```bash
gcc -no-pie hello_libc.s -o hello_libc
./hello_libc
# => Hello from asm, x = 42
```

**What this actually does, in plain words:**

- `.section .rodata` says "the next bytes go in the read-only data shelf." `fmt:` is a label pointing at a string. `.asciz` writes the characters of the string into memory followed by a hidden zero byte that marks the end.
- `main:` is where the C runtime will phone us. We obey the same rules as any other function. `push rbp` does double duty: it saves the caller's `rbp` (the callee-saved promise) *and* keeps the stack aligned to a multiple of 16 before we call `printf`.
- `lea rdi, [rip + fmt]` puts the *address* of our format string into cup `rdi`. `lea` means "load effective address" — it computes a memory address without actually reading from memory. Argument 1 to `printf` is the format string, so it goes in `rdi`.
- `mov rsi, 42` puts the number we want to print into cup `rsi`. That is argument 2.
- `xor eax, eax` zeroes cup `eax`. (Explained below.)
- `call printf` rings up the printf specialist. They read from `rdi` and `rsi`, print to the screen, and return.
- `xor eax, eax` again — this time as our return value. We return `0` from `main`, meaning success.
- `pop rbp` and `ret` clean up and phone our caller (the C runtime) back, which then exits the program.

Three things to notice:

1. **`.asciz`** vs `.ascii`: `asciz` appends a NUL byte, which C string functions expect.

   **Plain words:** A C string is a row of bytes that ends with a single `0` byte. That zero byte is the "end-of-string mark." `.asciz` writes the text *and* the zero. `.ascii` writes only the text. If you use `.ascii` and pass the result to `printf`, it will keep reading past the end of your string into whatever junk is next, until it happens to find a zero — sometimes printing garbage, sometimes crashing.

2. **`xor eax, eax` before calling printf.** `printf` is a *variadic* function. SysV requires that **`al`** (well, `eax` to be safe) hold the number of `xmm` (vector) registers used to pass floating-point varargs. We pass none, so `eax = 0`. Forget this and `printf` may scan `xmm0..xmm7` and segfault.

   **Plain words:** `printf` is special because it takes a variable number of arguments. The ABI says: before calling a variadic function, set cup `al` to "the number of floating-point arguments I packed into the xmm cups." We have zero floating-point arguments, so we set it to zero. If you forget, `printf` looks at the xmm cups anyway and might read random garbage that happens to look like a giant float, leading to crashes.

3. **`push rbp` / `pop rbp` for alignment.** On entry `rsp ≡ 8 (mod 16)`. One push makes it `0 (mod 16)` — properly aligned for the `call`. No locals needed; we're just using the push as alignment.

   **Plain words:** When `main` started, the stack was 8-off from a multiple of 16 (because the `call` that got us here pushed a return address). Pushing one more 8-byte cup (`rbp`) puts us back at a multiple of 16, which is the alignment `printf` insists on. The fact that we are also fulfilling the callee-saved promise for `rbp` is a happy bonus.

## Calling asm from C

```c
// main.c
#include <stdio.h>

extern long sum3(long a, long b, long c);

int main(void) {
    printf("%ld\n", sum3(10, 20, 30));
    return 0;
}
```

```asm
# sum3.s
.intel_syntax noprefix
        .text
        .globl  sum3
sum3:
        mov     rax, rdi
        add     rax, rsi
        add     rax, rdx
        ret
```

```bash
gcc -no-pie main.c sum3.s -o demo
./demo
# => 60
```

The C compiler treats `sum3` as just another function. As long as your asm honors the SysV ABI — args in `rdi rsi rdx ...`, result in `rax`, callee-saved registers preserved, stack discipline — it's indistinguishable from a C function.

**What this actually does, in plain words:** The C code declares "somewhere out there is a function named `sum3` that takes three longs and returns a long." `extern` means "trust me, it exists, the linker will find it." When `main` calls `sum3(10, 20, 30)`, the C compiler dutifully follows the same convention: `10` into `rdi`, `20` into `rsi`, `30` into `rdx`, and then `call sum3`. Our hand-written assembly reads from exactly those cups, computes the sum, leaves the answer in `rax`, and returns. C sees a number come back in `rax`, hands it to `printf`, and prints `60`.

The headline: **once your asm follows the rulebook, no one can tell whether a function was written in C or assembly.** They are just labels and instructions.

## `-no-pie`: what and why

Default `gcc` builds today are **PIE** (position-independent executables) for ASLR. PIE code refers to globals through the **GOT** (Global Offset Table) and via `[rip + symbol]`. Most of what we write already uses `[rip + symbol]`, so it works either way — but calls to libc symbols like `printf` get rewritten to `call printf@PLT` and need extra care.

For simplicity in this part we pass `-no-pie`, which lets us link `call printf` directly. In a serious project, prefer PIE and learn the PLT/GOT dance (one extra indirection, that's it).

**Plain words:** Modern Linux likes to randomize where programs load into memory each time they run — a security trick called **ASLR** (Address Space Layout Randomization). For that to work, programs have to be **PIE** (position-independent), meaning none of their hard-coded addresses care where the program ended up. The cost is one extra layer of indirection when calling a library function: instead of `call printf` directly, the linker rewrites it as "look up the real `printf` address in a table called the PLT, then jump there."

To keep the early examples simple we pass `-no-pie` so we can just `call printf` directly. Real-world projects should use PIE; the indirection is small and the security benefit is real.

## Looking at what gcc emits

```bash
gcc -O2 -S -masm=intel sum3.c
cat sum3.s
```

(Where `sum3.c` is the C version of `sum3`.) You will see something very close to what we wrote by hand. This is one of the great pleasures of learning asm: you can compile any C you want and see the disassembly. It's the world's best textbook.

**Plain words:** `gcc -S` says "compile to assembly, but stop before turning it into a binary." `-masm=intel` says "write the assembly in Intel syntax, the dialect we use in this course." `-O2` says "optimize aggressively." The output is the *exact* assembly your compiler would have generated for that C program. Reading it is the fastest way to learn idioms — try a small C snippet, look at the asm, try another snippet, compare.

## A few useful libc functions

For experimenting, these are easy to call from asm:

| Function   | Args                               | Returns                |
| ---------- | ---------------------------------- | ---------------------- |
| `puts`     | `rdi` = NUL-terminated string      | `rax` = bytes written  |
| `printf`   | `rdi` = fmt, rest as in C; `al`=0  | `rax` = chars printed  |
| `scanf`    | `rdi` = fmt, then output pointers  | `rax` = items matched  |
| `malloc`   | `rdi` = bytes                      | `rax` = pointer        |
| `free`     | `rdi` = pointer                    | nothing                |
| `strlen`   | `rdi` = string                     | `rax` = length         |
| `exit`     | `rdi` = status                     | (never returns)        |

For `scanf("%ld", &x)`, you pass the format in `rdi` and the **address** of `x` in `rsi`. The function writes through the pointer.

**Plain words:** Each row is a phone number you can call. The middle column tells you which cups to fill in, the right column tells you which cup to look in for the answer. `scanf` is mildly tricky: it does not give you the value it read directly in `rax`. Instead, you hand it a pointer (an address) telling it *where to write the result*, and `scanf` stores the value at that location. So you have to set aside a memory slot first (usually a piece of the stack) and pass its address as the second argument.

## Try it

1. Write an asm `main` that reads an integer with `scanf`, doubles it, and prints it with `printf`. (You'll need a stack slot for the scanned value: `sub rsp, 16` for alignment + space, `lea rsi, [rsp]`, `call scanf`, then `mov rdx, [rsp]` to get the value.)
2. Write a C program that calls an asm `max(a, b)` function. Verify with `objdump -d -M intel` that your `max` does what you think.
3. Compile a small C function with `gcc -O0 -S -masm=intel` and `-O2 -S -masm=intel`. Diff the two. The `-O2` version will be dramatically tighter and uses tricks (`cmov`, `lea`-as-arithmetic) we've already covered.

## What's next

[Part 12](../12_Strings_Arrays/README.md) — manipulating strings and arrays, including the `rep` prefix and the dedicated string instructions.
