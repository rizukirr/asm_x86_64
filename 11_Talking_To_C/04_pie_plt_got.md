# 11.04 — PIE, PLT, and GOT (the indirection tax)

## A story: the receptionist with a sticky note

**In plain words:** when your program calls `printf`, it doesn't usually jump straight to `printf`'s code. It jumps to a tiny stub inside your own binary called the **PLT entry**, which looks up `printf`'s real address in a table called the **GOT**, and then jumps there. This indirection is what makes modern Linux binaries position-independent (which makes ASLR — address randomization — possible).

**The analogy.** Imagine the libc library has moved offices every time the program starts. You can't put libc's address directly into your code, because tomorrow it'll be somewhere else. Instead, you call a local **receptionist** (the PLT) who keeps a sticky note (the GOT entry) with libc's *current* address. Every time you want `printf`, you ask the receptionist, the receptionist peeks at the sticky note, and forwards your call. The receptionist itself lives at a fixed offset inside *your* binary, so you always know where to find them.

**The technical layer.** Two tables make this work:

- **PLT** — Procedure Linkage Table. A row of small code stubs, one per external function. Each stub does: "look up my GOT entry; jump there."
- **GOT** — Global Offset Table. A row of memory slots, one per external symbol. Each slot eventually holds the runtime address of the actual function. The slots start out pointing at *resolver* code that fills them in lazily on first use.

The first time you call `printf`, the GOT slot points back to a resolver, which figures out where libc loaded `printf` *today*, patches the GOT, and jumps to it. The second time, the GOT slot points directly at `printf`, no resolver needed. This is called **lazy binding**.

**Check yourself.** What's the point of all this machinery instead of just patching the call instruction itself with `printf`'s address? (Answer: patching code at runtime would require the `.text` section to be writable, which is a security disaster. The GOT is data — writable, patchable, and cheap to update.)

## PIE vs. non-PIE in one paragraph

A **PIE** (Position-Independent Executable) can be loaded at any address. Every reference to a global symbol — including calls to libc — goes through the PLT/GOT. The kernel takes advantage of this to randomize the program's load address each run (**ASLR**), making certain classes of exploit much harder.

A **non-PIE** executable is hardcoded to a fixed load address. Calls to libc can be linked as direct calls (the linker resolves them to a single fixed PLT stub). Simpler, slightly faster on the first call, but no ASLR for the program itself.

When you pass `-no-pie` to `gcc`, you're saying "I want the non-PIE flavor." That's why our earlier `call printf` worked without any `@PLT` annotation. The linker quietly did the right thing for us.

## What changes in your assembly?

**Almost nothing.** The good news: the assembly source we've been writing is *already* PIE-friendly. The two things to know:

1. **Use `[rip + symbol]`, not absolute addresses.** RIP-relative addressing computes `symbol`'s address as a delta from the current instruction. Move the program to any load address you like; the delta is unchanged. We've used `lea rdi, [rip + fmt]` since Part 01 — it's been PIE-friendly the whole time.

2. **Calls to external functions are auto-rewritten.** When you write `call puts`, the assembler emits a relocation that says "the linker should fill in the right target for me." If the binary is PIE, the linker resolves it to `puts@PLT` (the local stub). If the binary is non-PIE, the linker resolves it to the same stub but the call can be a direct address. Either way, **the source is `call puts`.**

You will sometimes see assembly written explicitly as `call puts@PLT`. That's a hint to the assembler: "I know this is going through the PLT, encode the relocation accordingly." On most modern toolchains, plain `call puts` and `call puts@PLT` produce the same object code; the linker decides what's actually emitted in the final binary.

## The code

See [`04_pie_plt_got.s`](04_pie_plt_got.s):

```asm
.intel_syntax noprefix

        .section .rodata
greeting:
        .asciz  "Hello via PLT"

        .section .text
        .globl  say_hello
        .extern puts

say_hello:
        push    rbp                     # 16-align rsp for the call
        lea     rdi, [rip + greeting]   # RIP-relative is PIE-friendly
        call    puts                    # linker decides PLT vs. direct
        pop     rbp
        ret
```

And [`04_pie_plt_got.c`](04_pie_plt_got.c):

```c
#include <stdio.h>

extern void say_hello(void);

int main(void) {
    say_hello();
    return 0;
}
```

## Build and run

The same source builds two ways. Both work; both produce `Hello via PLT`.

```bash
# Non-PIE: direct call, fixed load address
gcc -no-pie 04_pie_plt_got.s 04_pie_plt_got.c -o /tmp/demo && /tmp/demo
# => Hello via PLT
```

For the PIE flavor (not used by the verification loop, but try it manually):

```bash
gcc -fPIE -pie 04_pie_plt_got.s 04_pie_plt_got.c -o /tmp/demo_pie && /tmp/demo_pie
# => Hello via PLT
```

## Look at the difference

Disassemble both binaries and compare the call site:

```bash
objdump -d -M intel /tmp/demo     | grep -A1 'call.*puts'
objdump -d -M intel /tmp/demo_pie | grep -A1 'call.*puts'
```

In the non-PIE binary you'll typically see something like:

```
call    401030 <puts@plt>
```

In the PIE binary the same call goes to a PLT stub too, but the surrounding code uses RIP-relative loads through the GOT to fetch the function pointer. Either way, the call goes through one extra hop compared to a "pure" direct call.

## The cost of the PLT hop

**In plain words:** one extra jump per external function call, plus a one-time resolver cost on the very first call. Once the GOT is patched, the steady-state cost is negligible — the CPU's indirect branch predictor handles it well.

**Gotcha.** Don't try to "optimize" by reading a libc function's address once and storing it. The address might change across calls if the dynamic linker does something interesting; even when it doesn't, you'd be reinventing the GOT, badly.

## When you'll write `call foo@PLT` explicitly

In hand-written shared library code (a `.so` file), you may need to be explicit about PLT calls and GOT loads, because shared libraries are always position-independent. For ordinary application code linked with `gcc`, the plain `call foo` form is sufficient.

For globals (variables, not functions) in PIE code, the canonical pattern is:

```asm
mov     rax, [rip + my_global@GOTPCREL]   # load address from GOT
mov     rax, [rax]                        # then dereference
```

The `@GOTPCREL` modifier tells the linker "load this through the GOT, RIP-relative." For function calls you almost never need this — `call foo` is enough.

## Check yourself

1. Build the demo both ways (`-no-pie` and `-fPIE -pie`). Run each twice in a row using `/usr/bin/cat /proc/self/maps` or `ldd /tmp/demo_pie` to peek at load addresses. The non-PIE binary's `.text` lives at the same address every time; the PIE binary's moves.
2. `objdump -d -M intel /tmp/demo | less` and find the `puts@plt` stub. It's a tiny 3-instruction sequence that jumps through a GOT slot.
3. Use `readelf -r /tmp/demo` to list relocations. You'll see entries pointing the GOT at `puts`. These are the patches the dynamic linker applies before `main` runs (or lazily on first call, depending on flags).

## Next

Back to the [chapter index](README.md) — or onward to [Part 12: Strings and Arrays](../12_Strings_Arrays/README.md).
