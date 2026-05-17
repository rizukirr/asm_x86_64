# 11.03 — The 16-byte stack alignment rule

## A story: the chef who insists on square platters

**In plain words:** before you call any libc function — `printf`, `malloc`, `scanf`, anything — the stack pointer `rsp` must be a multiple of 16. If it isn't, the function may crash in confusing ways the moment it touches floating-point or SSE instructions.

**The analogy.** Imagine a chef who refuses to plate food onto anything except square platters whose side length is a multiple of 16 cm. Most of the time, the dish (`printf`) doesn't actually need the alignment — it works fine on a 17-cm platter — but some dishes (the ones that use SSE/AVX vector instructions like `movaps`) absolutely require it, and if you slide a misaligned platter in front of those, they smash on the floor. Since you can't always tell ahead of time which dishes will care, the rule is simple: **every platter you hand to the chef must be 16-aligned, period.**

**The technical layer.** The System V AMD64 ABI requires `rsp` to be a multiple of 16 at the moment any `call` instruction is executed. Once `call` pushes the 8-byte return address, the callee starts life with `rsp ≡ 8 (mod 16)`. The callee is then responsible for getting `rsp` back to a multiple of 16 before *its* next `call`.

The reason: SSE instructions like `movaps` (move aligned packed singles) fault with `SIGSEGV` if their memory operand isn't 16-aligned. libc compiled with optimization will absolutely use these instructions on stack memory, and they need the frame to be aligned for that to be safe.

**Check yourself.** If `rsp ≡ 8 (mod 16)` on entry, how many 8-byte pushes do you need before the *next* `call`? (Answer: an odd number — 1, 3, 5, etc. Each push subtracts 8 from `rsp`, flipping its mod-16 state.)

## The rule, three ways to satisfy it

You have three common patterns. Pick whichever fits the function.

### Pattern A: leaf function — do nothing

If your function never calls anything else, alignment doesn't matter. `sum3` from [02_called_from_c](02_called_from_c.md) is a leaf — no prologue needed.

### Pattern B: one push, no locals

```asm
foo:
        push    rbp                     # rsp: 8 -> 0 (mod 16)
        call    printf
        pop     rbp
        ret
```

One push of an 8-byte value brings the misaligned stack back to alignment. Bonus: `rbp` is callee-saved, so we are simultaneously honoring that promise.

### Pattern C: explicit frame for locals

```asm
foo:
        push    rbp                     # rsp: 8 -> 0 (mod 16)
        sub     rsp, N                  # N must be a multiple of 16
        ...
        add     rsp, N
        pop     rbp
        ret
```

Round `N` up to the next multiple of 16, even if you only need 8 bytes. Need 8 bytes? Allocate 16. Need 24? Allocate 32. The extra padding is the price of staying aligned.

## The code

See [`03_stack_alignment.s`](03_stack_alignment.s) and the one-line C driver [`03_stack_alignment.c`](03_stack_alignment.c). The asm function `align_demo` parses an integer from a fixed string with `sscanf`, doubles it, and prints both the `sscanf` item count and the doubled value with `printf`. That's two consecutive libc calls, both requiring alignment.

The interesting part is the prologue/epilogue:

```asm
align_demo:
        push    rbp                     # rsp: 8 -> 0 (mod 16)
        sub     rsp, 16                 # 8 bytes for data + 8 bytes padding
        ...
        add     rsp, 16
        pop     rbp
        ret
```

We only need 8 bytes of stack memory (one `long`), but we allocate 16 to keep `rsp` aligned for the calls inside. The slot lives at `[rsp + 0]`; the upper 8 bytes hold the items count returned by `sscanf` (plus 4 bytes of slack).

## Build and run

```bash
gcc -no-pie 03_stack_alignment.s 03_stack_alignment.c -o /tmp/demo && /tmp/demo
# => sscanf returned 1 items, doubled = 42
```

## Dissecting it

### Why allocate 16 bytes when we only need 8?

**In plain words:** because allocating 8 would leave `rsp` at `8 (mod 16)`, which is the misaligned state. The next `call` to `sscanf` could then fault inside libc.

**The technical layer.** `sub rsp, 8` shifts the mod-16 state of `rsp` by 8. If you were at `0` before, you're at `8` after — misaligned. So we always pick a stack frame size whose mod-16 is `0`. The smallest valid sizes are 0, 16, 32, 48, and so on.

### Passing an address to `sscanf`

```asm
lea     rdx, [rsp]
```

**In plain words:** the third argument to `sscanf("21", "%ld", &slot)` is the address of where to store the parsed value. We hand it the address of our stack slot.

**The technical layer.** `sscanf` does not return the parsed integer in `rax`. Instead, you tell it where in memory to write the answer by passing a pointer. After the call, the parsed value is sitting at `[rsp]`, ready for us to read with `mov`.

### Reading the result back

```asm
mov     rdx, qword ptr [rsp]
shl     rdx, 1
```

**In plain words:** load the parsed value from our stack slot into `rdx` (the third printf argument), then shift it left by one bit — a fast way to multiply by 2.

### Stashing the item count on the stack

```asm
mov     dword ptr [rsp + 8], eax
```

**In plain words:** `sscanf`'s return value (the number of items matched) lives in `eax`. We need to keep it alive across the upcoming call to `printf`, but `eax` is *caller-saved* — `printf` is free to overwrite it. The safe move is to park it in our stack frame. We already allocated 16 bytes; the upper 8 bytes were going to be padding anyway, so we use the top 4 bytes of the frame as a tiny scratch slot.

Alternative: use a callee-saved register like `rbx` or `r12`. That works too, but then you must `push` and `pop` that register to honor the ABI. Stashing on our own already-aligned stack frame is one less moving part.

### The epilogue, exactly mirrored

```asm
add     rsp, 16
pop     rbp
ret
```

**In plain words:** undo the `sub`, undo the `push`, return to the caller.

**Gotcha.** The order matters: you must `add rsp, 16` *before* `pop rbp`, because `pop rbp` reads from whatever `rsp` currently points at. If `rsp` is still 16 bytes into the local frame when you pop, you'd pop random garbage into `rbp` instead of the saved value.

## Symptoms of a misaligned stack

If you accidentally leave the stack misaligned and call into libc, here is what it looks like:

- **Most likely:** `SIGSEGV` deep inside libc, typically on a `movaps` instruction. `gdb` will show a clean libc backtrace and a crash on what looks like an innocent move instruction.
- **Sometimes:** mysterious wrong output. Some libc functions silently produce garbage instead of crashing.
- **Occasionally:** the program works perfectly on your machine and crashes on your colleague's. Different libc builds use SSE differently.

When you see a crash inside `printf` or `malloc` on what looks like a normal instruction, **always check stack alignment first.**

## Check yourself

1. Change `sub rsp, 16` to `sub rsp, 8`. Rebuild and run. On many systems it will still appear to work — but try `gcc -O2` or run inside `valgrind` and the bug will surface. This is the trap: the misalignment is silent.
2. Remove the `push rbp` from the prologue and the matching `pop rbp` from the epilogue. Keep `sub rsp, 16` and `add rsp, 16`. Now alignment is wrong by 8. Run; observe the crash.
3. Replace the `sub rsp, 16` / `add rsp, 16` pair with `push rax` three times before the call (three pushes = 24 bytes, mod 16 = 8 — wrong) versus four times (32 bytes, mod 16 = 0 — right). Count carefully.

## Next

[04_pie_plt_got](04_pie_plt_got.md) — what `-no-pie` actually buys you, and what changes without it.
