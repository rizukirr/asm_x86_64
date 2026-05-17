# 10.2 — The System V AMD64 calling convention

## The story: a peace treaty between strangers

**In plain words.** Two programmers who have never met must agree on a rule, ahead of time, about *which register holds the first argument*. Otherwise neither could ever call the other's functions. That rule — plus a dozen related ones — is called a **calling convention**, or an **ABI** (Application Binary Interface).

**The analogy.** Picture a giant office of specialists who occasionally phone each other. If every specialist invented their own rule for "which cup do I drop the first number into?" — Alice puts it in the red cup, Bob expects the blue cup — every phone call would be chaos. So the entire office signs a single rulebook: *first argument always in the red cup, answer always in the green cup, and these specific cups are promised to be returned unchanged*. Once everyone signs, anyone can phone anyone.

**The technical layer.** On Linux, macOS, and BSDs running on x86_64, the rulebook is **System V AMD64**. Windows uses a different rulebook (Microsoft x64), with different argument registers — we won't cover it here. Every function compiled by `gcc`, `clang`, `rustc`, or any other Linux toolchain follows SysV. If your hand-written assembly follows it too, your code can call libc, and libc (and Rust, and Go, and …) can call yours.

**Gotcha.** "ABI" sounds intimidating — it isn't. It's just four rules: where args go, where the return value goes, which registers survive a call, and how the stack is aligned. This chapter covers the first three; alignment gets its own chapter.

## Rule 1: argument registers

The first six integer or pointer arguments go in these registers, in this order:

| Position | Register | Mnemonic         |
| -------- | -------- | ---------------- |
| 1st      | `rdi`    | **D**estination  |
| 2nd      | `rsi`    | **S**ource       |
| 3rd      | `rdx`    | **D**ata         |
| 4th      | `rcx`    | **C**ounter      |
| 5th      | `r8`     | (just "8")       |
| 6th      | `r9`     | (just "9")       |

A 7th argument and beyond go on the **stack**, pushed right-to-left, with the first stack arg at `[rsp + 8]` on entry (just past the return address that `call` pushed).

**In plain words.** "Destination, Source, Data, Counter, 8, 9." Memorize it. It is the single sentence that unlocks every function call in Linux assembly.

**Why these specific registers?** Historical accident. `rdi`/`rsi` originally meant "destination index" and "source index" for string-copy instructions. `rdx` was "data," `rcx` was "counter." The names made sense in 1978; on modern code they're just six general registers with arbitrary letters glued to them. The mnemonic is purely a memory aid.

## Rule 2: the return value

Integer or pointer return → `rax`. That's it.

128-bit return (rare) → `rdx:rax` (high half in `rdx`, low half in `rax`).
Floating-point return → `xmm0` (and possibly `xmm1`).

**In plain words.** The specialist always leaves the answer in cup `rax`. Always. The caller looks in `rax` after the call. No surprises.

## Rule 3: caller-saved vs callee-saved

This is the rule most beginners get bitten by. Each general-purpose register is in one of two categories:

| Caller-saved (scratch — call MAY clobber) | Callee-saved (call WILL preserve)         |
| ----------------------------------------- | ----------------------------------------- |
| `rax rcx rdx rsi rdi r8 r9 r10 r11`       | `rbx rbp r12 r13 r14 r15` (and `rsp`)     |

**In plain words.**

- **Caller-saved** registers are scratch paper. If you call somebody, expect them to dump whatever was in `rax`, `rdi`, `rsi`, `rdx`, `rcx`, `r8`, `r9`, `r10`, `r11`. If you wanted to keep a value, *you* must save it first (typically by pushing to the stack, or copying to a callee-saved register).
- **Callee-saved** registers are promised cups. If a function wants to use `rbx`, `rbp`, or `r12`–`r15`, it must first save the old contents (usually by `push`ing) and then restore them before returning. The caller can leave a value in `rbx`, make any number of function calls, and trust that `rbx` is unchanged afterwards.

**The analogy.** Caller-saved is "borrow at your own risk — I make no promises." Callee-saved is "if I borrow it, I'll return it exactly as I found it." Both sides obey the same list; that's why it works.

**Gotcha.** This is asymmetric. If you write a function and you touch `rax` (a caller-saved cup), you owe nothing — the caller already knows `rax` might change. But if you touch `rbx`, you owe a `push rbx` at the top and a `pop rbx` at the bottom. Forget the save/restore and the caller's code silently sees corrupted state — one of the nastiest bugs to debug.

**Rule of thumb.**

- **Writing a function?** Use any caller-saved register freely. If you touch a callee-saved one, push at entry, pop at exit.
- **Calling a function?** Anything you want to survive the call must be in a callee-saved register, or pushed/popped around the call.

## The code

See [`02_calling_convention.s`](02_calling_convention.s):

```asm
sum6:
        mov     rax, rdi        # rax = a
        add     rax, rsi        # + b
        add     rax, rdx        # + c
        add     rax, rcx        # + d
        add     rax, r8         # + e
        add     rax, r9         # + f
        ret

_start:
        mov     rdi, 1          # 1st arg
        mov     rsi, 2          # 2nd
        mov     rdx, 3          # 3rd
        mov     rcx, 4          # 4th
        mov     r8,  5          # 5th
        mov     r9,  6          # 6th
        call    sum6            # rax <- 21
        mov     rdi, rax
        mov     rax, 60
        syscall
```

**In plain words.** `sum6` is a six-argument specialist. By the convention, the inputs are sitting in `rdi`, `rsi`, `rdx`, `rcx`, `r8`, `r9` when it's called. It starts by copying the first input into `rax`, then folds the rest in with `add`. The total (1+2+3+4+5+6 = 21) ends up in `rax`. `ret`. The caller reads `rax`, hands it to `exit`.

Notice `sum6` is still a **leaf** function. It uses only caller-saved registers (`rax` is caller-saved; the six argument registers are caller-saved too). It saves nothing, restores nothing. Just compute and return.

## Build and run

```bash
as -o /tmp/t.o 02_calling_convention.s
ld -o /tmp/t /tmp/t.o
/tmp/t
# => sum6(1,2,3,4,5,6) = 21
echo $?
# => 21
```

## What about arguments 7, 8, …?

Past the sixth argument, the caller pushes them onto the stack in reverse order (right-to-left) before `call`. On entry to the callee, the first stack arg lives at `[rsp + 8]` (the `+ 8` skips over the return address that `call` just pushed).

**Sketch only — not in this program:**

```asm
        # Calling f(a,b,c,d,e,f, g)  — g is the 7th arg.
        push    qword ptr [g_value]   # 7th arg on the stack
        mov     rdi, ...              # args 1..6 in registers as usual
        ...
        call    f
        add     rsp, 8                # clean up the pushed arg
```

We won't write a 7-arg example here; you'll see one in [Try it](#try-it).

## Try it

1. **Wrong register, watch it break.** In `sum6`, change the third `add` to use `r10` instead of `rdx`. Rebuild and run. The exit code will be wrong (and unpredictable — `r10` is caller-saved scratch holding whatever junk happened to be there). Lesson: the convention is not a suggestion.

2. **A 7-argument function.** Write `sum7` that takes a 7th argument on the stack at `[rsp + 8]`. In `_start`, `push` a value before `call sum7`, and don't forget to clean it up with `add rsp, 8` after the call.

3. **Clobber a callee-saved register.** Write a function `bad` that does `mov rbx, 999` and returns. In `_start`, do `mov rbx, 7`, then `call bad`, then `mov rdi, rbx`, then exit. You'll see exit code 231 (999 mod 256), not 7. Now fix `bad` by adding `push rbx` at entry and `pop rbx` before `ret`. You'll get 7. That `push`/`pop` pair is the entire weight of the "callee-saved" promise.

## What's next

For leaf functions, registers are enough. For functions with local variables (or that call other functions), you need a structured way to use the stack. That's the **stack frame** — see [`03_stack_frames.md`](03_stack_frames.md).
