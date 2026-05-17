# 07.04 — Stack Alignment: The 16-Byte Rule

## A story: the loading dock with a forklift

**In plain words:** the System V AMD64 ABI (the rulebook for how functions call each other on Linux x86_64) requires that **`rsp` is a multiple of 16 right before any `call` instruction**. Forget this and your program may crash deep inside `printf` for reasons that look like black magic.

**The analogy.** Imagine a shipping warehouse with a forklift that can only pick up pallets that sit on multiples of 16-inch floor markings. If a pallet is sitting at the 14-inch line, the forklift's prongs go in crooked and the whole load topples. The CPU's SSE/AVX instructions (the vector instructions libc uses heavily) are that forklift. They demand 16-byte alignment for some memory operands. When the alignment is wrong, the CPU raises a `#GP` (general protection fault) and your program dies with a `SIGSEGV`.

## The exact rule

**At the moment just before a `call` instruction executes, `rsp` must be `0 (mod 16)`.**

Because `call` itself pushes an 8-byte return address, **at the entry of any called function**, `rsp` will be `8 (mod 16)`.

That's the contract. Caller aligns to 16. Callee sees 8. If the callee wants to call something else, it has to fix `rsp` back to a multiple of 16 first.

## Why does this rule exist?

**In plain words:** because SSE instructions (the 128-bit-wide vector instructions like `movaps`, `movdqa`) require their memory operands to be 16-byte aligned. Without the rule, the compiler couldn't safely use SSE for anything sitting on the stack — like spilled function arguments, or local arrays of doubles. With the rule, it just works.

Modern AVX instructions raise the stakes (32-byte alignment for `vmovdqa`), but the ABI baseline is 16.

## How `call` and `ret` interact with `rsp`

A quick reminder of the mechanics:

```
call target     ≡   push (next instruction's address) ; jmp target
ret             ≡   pop  rip   (informally — pop into the instruction pointer)
```

So `call` lowers `rsp` by 8 (writes the return address). `ret` raises `rsp` by 8 (reads it back). Both touch `rsp` by 8 bytes — not 16. That's where the "callee sees 8 mod 16" comes from.

## Worked example: measure the rule directly

See [`04_alignment.s`](04_alignment.s):

```asm
.intel_syntax noprefix

        .section .text
        .globl  _start
_start:
        mov     rax, rsp
        and     rax, 15                 # rax = 0 (kernel aligns us to 16)
        shl     rax, 4                  # park it in the high nibble
        mov     r12, rax

        call    measure_inside          # call pushes 8 bytes

        or      rax, r12                # combine the two measurements

        mov     rdi, rax
        mov     rax, 60
        syscall

measure_inside:
        mov     rax, rsp
        and     rax, 15                 # 8 — `call` pushed 8 bytes
        ret
```

**In plain words.**

1. At `_start`, the kernel guarantees `rsp` is a multiple of 16. So `rsp & 15 == 0`. We shift that into the high nibble (top 4 bits) of a byte and stash it in `r12`.
2. We `call measure_inside`. The `call` instruction pushes an 8-byte return address onto the stack, lowering `rsp` by 8. So inside the callee, `rsp & 15 == 8`.
3. The callee returns that 8 in `rax`. We combine: `rax = (start_nibble << 4) | callee_nibble = (0 << 4) | 8 = 8`.
4. We exit with status 8.

## Build and run

```bash
as -o /tmp/04.o 04_alignment.s
ld -o /tmp/04    /tmp/04.o
/tmp/04 ; echo $?
```

Output:

```
8
```

That `8` is a direct measurement of the alignment rule. **Before the call: `rsp & 15 == 0`. After the call (inside the callee): `rsp & 15 == 8`.** Exactly as the ABI promises.

## The libc-aware function prologue

**In plain words:** if you write a function that will be called from C (or call into C), you need to re-align `rsp` to 16 before any nested `call`. Two common patterns:

**Pattern A — bump by 8:**

```asm
my_func:
        sub     rsp, 8                  # rsp was 8 mod 16; now 0 mod 16
        call    printf_or_whatever      # legal: rsp is 0 mod 16
        add     rsp, 8                  # restore
        ret
```

**Pattern B — allocate locals such that the total is `(multiple of 16) + 8`:**

```asm
my_func:
        push    rbp                     # 8 bytes — rsp was 8 mod 16; now 0 mod 16
        mov     rbp, rsp
        sub     rsp, 32                 # rsp still 0 mod 16
        call    something               # legal
        mov     rsp, rbp
        pop     rbp
        ret
```

**In plain words on Pattern B:** the `push rbp` and the `call` from the caller together consume 16 bytes (8 + 8). So if you add a multiple of 16 more (here, 32), you stay aligned. This is the standard "by-the-book" prologue.

## Gotcha — the silent crash

**In plain words:** the world's most confusing assembly bug is "my program calls `printf` and crashes for no reason." Nine times out of ten, the cause is misaligned `rsp`. The crash often happens *inside* libc, deep in some SSE instruction operating on a stack-spilled value, not in your code. The backtrace points at `printf`, you stare at `printf`, you find nothing wrong with `printf`. The bug is in *how you called* `printf`.

The fix: **before any `call` into libc, make sure `rsp & 15 == 0`.** Use one of the two patterns above.

## The kernel is friendlier

**In plain words:** the alignment rule is an ABI agreement between *user-space* functions. The kernel doesn't care — `syscall` (the instruction we used in topics 01–03) is not a `call`, doesn't push to the stack, and doesn't impose this alignment requirement. That's why our earlier programs worked fine even though they were sloppy about alignment.

But the moment you `call` into libc, you're in user-space-function land. The rule applies.

## Check yourself

1. **At entry to `measure_inside`, what is `rsp & 15`?**
   *Answer: 8. The `call` pushed an 8-byte return address.*

2. **You write a function that calls `printf`. You do `sub rsp, 32` at the top and never adjust again. Does it work?**
   *Answer: no. `rsp` was 8 mod 16 at entry; after `sub rsp, 32` it's still 8 mod 16 (because 32 is a multiple of 16). The `call printf` will land on a misaligned stack.*

3. **What's the simplest one-line fix?**
   *Answer: change `sub rsp, 32` to `sub rsp, 40` (or `24`, or `8`) — any value that flips the low nibble from 8 to 0.*

4. **Why doesn't the rule apply to `syscall`?**
   *Answer: `syscall` is a CPU instruction that traps into the kernel. It is not a function call in the ABI sense. The kernel's calling convention is separate and doesn't require 16-byte stack alignment.*

## Summary of this chapter

You've now seen:

- The stack is a downward-growing memory region; `rsp` points at the top. (Topic 01.)
- `push` and `pop` are sugar for `sub rsp, 8 ; mov [rsp], ...` and its reverse. (Topic 02.)
- A function carves a **stack frame** for its locals using `rbp` as an anchor. (Topic 03.)
- `rsp` must be `0 (mod 16)` immediately before any `call`. (This topic.)

## Next

[`../08_Control_Flow/README.md`](../08_Control_Flow/README.md) — `cmp`, `test`, conditional jumps, and the foundation of `if` and `while`.
