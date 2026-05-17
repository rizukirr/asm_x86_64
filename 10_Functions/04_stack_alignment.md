# 10.4 — 16-byte stack alignment (and the red zone)

## The story: parking spaces must be on the 16-meter marks

**In plain words.** The System V ABI requires that at the *exact moment* you execute `call`, the stack pointer `rsp` must be at an address that is a multiple of 16. If you don't, modern CPUs may crash (or worse, silently corrupt data) when the called function uses a "wide" instruction that expects 16-aligned memory.

**The analogy.** Imagine a parking lot where the lines are painted every 16 meters. Most cars can park anywhere. But there is a specific kind of double-wide delivery truck that *can only park* if its left wheel is exactly on a 16-meter line. If you park your hatchback on a 12-meter line and then the delivery truck pulls in behind you, the truck cannot fit. So the parking lot rule says: **everyone parks on 16-meter lines, all the time, just in case the truck arrives.**

The "double-wide truck" is a **SIMD instruction** (Single Instruction Multiple Data — instructions like `movaps` that read or write 16 bytes at once). Some SIMD instructions *fault* on unaligned memory. Compilers love using SIMD inside libc functions like `memcpy` and `printf`. So even if your code does not use SIMD, the libc you call into does, and it expects a 16-aligned stack.

**The technical layer.** The rule is precise:

> Immediately before executing `call`, `rsp` must satisfy `rsp ≡ 0 (mod 16)`.

`call` itself pushes 8 bytes (the return address), so when the callee begins executing its first instruction, `rsp ≡ 8 (mod 16)`. That's the documented entry condition.

From there, the callee must restore alignment before any *inner* `call`. The two common patterns:

1. **Just `push rbp`** — adds 8 bytes, takes you from `8 mod 16` back to `0 mod 16`. Perfect for functions with no locals.
2. **Allocate a multiple of 16 for locals after the saved `rbp`** — e.g., `push rbp` then `sub rsp, 16` (or 32, 48, …). The `push rbp` brings you to aligned; the `sub` keeps you aligned.

**Gotcha.** This is the single most painful bug in hand-written assembly. Programs run fine for years, then crash mysteriously when someone updates glibc and a `printf` deep inside starts using SIMD. The crash usually says `SIGSEGV` and points at an instruction like `movaps` deep inside libc. The actual bug is in *your* function 10 frames up the call stack, which forgot to align `rsp` before a `call`.

**Check yourself.** If at program entry `rsp = 0x7fffffffe000` (the kernel gives us a 16-aligned `rsp`), and `_start` does `call wrapper`, what is `rsp` when `wrapper`'s first instruction runs? (Answer: `0x7fffffffdff8`, i.e., `8 mod 16`. The `call` pushed 8 bytes.)

## The bookkeeping cheat sheet

| Where you are                                | `rsp` mod 16 |
| -------------------------------------------- | ------------ |
| Program entry (`_start`'s first instruction) | 0            |
| Inside a function, right after entry         | 8            |
| After `push rbp`                             | 0            |
| After `push rbp` then `sub rsp, 16k`         | 0            |
| Just before an inner `call`                  | **must be 0**|
| Inside the inner callee, first instruction   | 8            |

The pattern: every function entry is "8 off." To call out, get back to 0. The `push rbp` + `sub rsp, multiple_of_16` shape does this automatically.

## The code

See [`04_stack_alignment.s`](04_stack_alignment.s):

```asm
seven:
        mov     rax, 7
        ret

wrapper:
        push    rbp             # rsp: 8 -> 0 (re-aligned)
        mov     rbp, rsp
        call    seven           # rsp is 0 mod 16 here — SIMD-safe
        mov     rsp, rbp
        pop     rbp
        ret

_start:
        # ... print banner ...
        call    wrapper
        mov     rdi, rax        # 7
        mov     rax, 60
        syscall
```

**In plain words.** `seven` is a tiny leaf that returns 7. `wrapper` is a non-leaf — it calls `seven`. Because `wrapper` calls something, it must be 16-aligned at the moment of that inner `call`. The single `push rbp` at the top of `wrapper` does double duty: (1) saves the caller's `rbp`, (2) re-aligns the stack from `8 mod 16` to `0 mod 16`. No `sub rsp, …` is needed because `wrapper` has no locals.

`_start` calls `wrapper`, gets 7 in `rax`, uses it as the exit code.

## Build and run

```bash
as -o /tmp/t.o 04_stack_alignment.s
ld -o /tmp/t /tmp/t.o
/tmp/t
# => aligned call returned 7
echo $?
# => 7
```

## The red zone (a small bonus rule)

**In plain words.** On Linux/SysV, the 128 bytes *below* `rsp` are reserved for the current function's use, and the kernel promises not to clobber them on signals. This means a **leaf function** can skip the `sub rsp, …` step and just use `[rsp - 8]`, `[rsp - 16]`, etc. directly. No bookkeeping. Faster.

**The analogy.** It's a 128-byte sandbox right below your feet. Nobody else is allowed to step on it as long as you're standing there. Use it for quick scratch, no setup required.

**The technical layer.** The rule:

> Functions may freely use the 128 bytes starting at `[rsp - 128]` without subtracting from `rsp`, **provided they do not call any other function**. (A `call` would push the return address into the red zone and clobber it.)

So:

```asm
# Legal in a leaf function only:
leaf:
        mov     [rsp - 8],  rdi         # scratch slot, no alloc
        mov     [rsp - 16], rsi
        # … work …
        ret
```

This is purely an optimization. You never *have* to use the red zone; you can always `sub rsp, …` like normal. Compilers use it heavily for leaf functions.

**Gotcha.** Two contexts where the red zone does **not** exist:

- **Kernel code.** The Linux kernel disables the red zone (signal/interrupt frames need to push there).
- **Windows.** Microsoft x64 has no red zone at all.

So this is a Linux-userspace-only freebie.

## Try it

1. **Break alignment, see what happens.** In `wrapper`, replace `push rbp` with `sub rsp, 8`. That still moves `rsp` by 8 bytes, but now the saved-rbp slot isn't there. More importantly, the alignment is the same as before (still 0 mod 16). Rebuild — it works, exit 7. Now change it to `sub rsp, 16` — alignment is now `8 mod 16` at the inner `call`. On a tiny program like this you may still get 7, because `seven` itself doesn't use SIMD. The bug is invisible — until the day you call a libc function. That invisibility is exactly why alignment bugs are dangerous.

2. **Use the red zone.** Rewrite `seven` as:

   ```asm
   seven:
           mov     [rsp - 8], rdi   # park rdi in the red zone, no sub rsp
           mov     rax, 7
           mov     rdi, [rsp - 8]   # get it back (silly, but demonstrates the slot)
           ret
   ```

   It still works because `seven` is a leaf — no inner `call` to clobber the red zone.

3. **Verify with gdb.** Set a breakpoint right before `call seven` inside `wrapper`, run under `gdb`, and `print $rsp % 16`. You should see `0`. Now break right after entry to `seven` and check again — `8`. The treaty in action.

## What's next

You now know everything you need to write functions that play nicely with the world: `call`/`ret`, the SysV register convention, stack frames, and alignment. Time to use that to call into real C code (and let C call you): [Part 11 — Talking to C](../11_Talking_To_C/README.md).
