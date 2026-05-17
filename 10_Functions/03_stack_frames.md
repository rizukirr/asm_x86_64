# 10.3 — Stack frames: prologue, locals, epilogue

## The story: setting up a desk before you start working

**In plain words.** When a function has more state than fits in registers — local variables, saved registers, scratch space — it carves out a chunk of the stack and uses that chunk as its own private desk. That chunk is called a **stack frame**.

**The analogy.** Imagine you walk into a shared workshop. Before you start your project, you grab an empty workbench (push some stack), tape a sign onto it with your name (set `rbp` as your anchor), and lay out your tools. When you're done, you clear the tools off, pull the sign down, and walk out — leaving the bench exactly as you found it. The person who walks in after you can't tell you were ever there.

**The technical layer.** A stack frame has a fixed shape that every function follows:

```
   higher addresses
   +-------------------+
   | caller's stack    |
   +-------------------+
   | 7th arg, 8th arg… |   <- if any args spilled past r9
   +-------------------+
   | return address    |   <- pushed by `call`
   +-------------------+
   | saved rbp         |   <- pushed by your prologue
   +-------------------+   <- rbp points here
   | local var 1       |   <- [rbp - 8]
   | local var 2       |   <- [rbp - 16]
   | …                 |
   +-------------------+   <- rsp points here
   lower addresses
```

Three jobs happen at the top of the function (the **prologue**) and three undo them at the bottom (the **epilogue**).

**Gotcha.** You only need a frame if you have locals to keep, or you call into another function, or you touch a callee-saved register. Tiny leaf functions like the ones in chapters 10.1 and 10.2 don't need a frame at all. The frame is overhead — useful when you need it, wasteful when you don't. Compilers with `-O2` happily skip the frame whenever they can.

## The prologue

```asm
        push    rbp
        mov     rbp, rsp
        sub     rsp, N          # N = bytes of locals (multiple of 16)
```

**In plain words, step by step:**

1. `push rbp` — save the caller's `rbp` value. `rbp` is a callee-saved register (one of the "promised" cups), so we owe the caller its original value back. We pay that debt now, by parking it on the stack.
2. `mov rbp, rsp` — copy the current stack pointer into `rbp`. From this point until the epilogue, `rbp` is **frozen**. It is our stable anchor. Local variable 1 will always be at `[rbp - 8]`, local 2 at `[rbp - 16]`, and so on, no matter how `rsp` moves during the function.
3. `sub rsp, N` — reserve `N` bytes of room below the anchor. The stack grows down, so `sub` moves `rsp` down. `N` is chosen so the total stack movement (saved rbp + N) keeps things aligned (more on alignment in [`04_stack_alignment.md`](04_stack_alignment.md)).

**The analogy.** `push rbp` is "set the old sign aside." `mov rbp, rsp` is "tape my new sign to the workbench." `sub rsp, 16` is "spread out 16 bytes' worth of tools to the side."

**Why two pointers (`rbp` and `rsp`)?** Because `rsp` keeps moving — every `push`, `pop`, or nested `call` shifts it. If you addressed your locals as `[rsp + offset]`, the offset would change constantly. `rbp` never moves during your function, so `[rbp - 8]` always means the same byte. It is a stable bookmark; `rsp` is the temporary scratch pointer.

(Compilers with optimization on often skip `rbp` entirely and just track offsets from `rsp` themselves. That's fine when the compiler is doing the bookkeeping. For hand-written assembly, `rbp` is easier to read.)

## The epilogue

```asm
        mov     rsp, rbp
        pop     rbp
        ret
```

**In plain words:**

1. `mov rsp, rbp` — move `rsp` back to where `rbp` is. This instantly throws away every local variable. It is exactly the reverse of `sub rsp, N`, without needing to know what `N` was.
2. `pop rbp` — restore the caller's `rbp` (the value we saved in the prologue). Promise kept.
3. `ret` — pop the return address into `rip`. Off we go.

After all three, the stack looks exactly like it did before the function was called. Symmetric. Clean.

## The code

See [`03_stack_frames.s`](03_stack_frames.s):

```asm
# long square_plus(long x, long y) {
#     long sq = x * x;
#     return sq + y;
# }
square_plus:
        push    rbp
        mov     rbp, rsp
        sub     rsp, 16

        mov     rax, rdi
        imul    rax, rdi                # rax = x * x
        mov     [rbp - 8], rax          # store local sq

        mov     rax, [rbp - 8]
        add     rax, rsi                # + y

        mov     rsp, rbp
        pop     rbp
        ret
```

**In plain words.** We compute `x * x` (using `imul`, integer multiply) and stash it in a real stack slot at `[rbp - 8]` — that slot is the local variable `sq`. Then we read it back out and add `y`. Result in `rax`, epilogue, return.

For `x = 6`, `y = 6`: `sq = 36`, return `36 + 6 = 42`.

(Of course, no human would store `sq` on the stack just to read it back two instructions later — we'd keep it in `rax`. The whole point of writing it this way is to *show* the frame mechanics. With `-O2`, gcc would compile this C source down to a frame-less three-instruction leaf function. With `-O0`, gcc would produce something near-identical to the assembly above.)

## Build and run

```bash
as -o /tmp/t.o 03_stack_frames.s
ld -o /tmp/t /tmp/t.o
/tmp/t
# => square_plus(6, 6) = 42
echo $?
# => 42
```

## The frame in motion

Just before `_start` calls `square_plus`:

```
+----------+
| ...      |  <- rsp (16-aligned)
+----------+
```

After `call square_plus` pushes the return address:

```
+----------+
| ret addr |  <- rsp (now 8 mod 16)
+----------+
```

After `push rbp` in the prologue:

```
+----------+
| ret addr |
+----------+
| old rbp  |  <- rsp == rbp (16-aligned again)
+----------+
```

After `sub rsp, 16`:

```
+----------+
| ret addr |
+----------+
| old rbp  |  <- rbp
+----------+
| sq       |  <- [rbp - 8]
+----------+
| padding  |  <- rsp
+----------+
```

The epilogue undoes those three steps in reverse: `mov rsp, rbp` collapses the locals and padding, `pop rbp` restores the old rbp pointer (and `rsp` moves up 8), `ret` pops the return address (and `rsp` moves up another 8). We're back where we started.

## Try it

1. **Add another local.** Make `square_plus` also compute `long doubled_y = y + y;` and return `sq + doubled_y` instead. You'll need a second slot — store it at `[rbp - 16]`. The 16-byte reservation already has room. Rebuild; for `x=6, y=6` you should get `36 + 12 = 48`.

2. **Watch a missing epilogue.** Comment out `mov rsp, rbp` and `pop rbp`. Rebuild and run. The remaining `ret` will pop the wrong value (the still-on-stack `sq`) as a return address and crash. Lesson: every prologue needs its matching epilogue, in reverse order.

3. **Drop the frame entirely.** Rewrite `square_plus` with no `push rbp`, no `sub rsp, ...`, no `[rbp - 8]` — just compute everything in `rax`:

   ```asm
   square_plus:
           mov     rax, rdi
           imul    rax, rax
           add     rax, rsi
           ret
   ```

   Same exit code (42), three instructions instead of nine. That's what `-O2` would produce. The frame was overhead we didn't need.

## What's next

Every frame we've written has been a multiple of 16 bytes for a reason. The reason is the **stack alignment rule** — see [`04_stack_alignment.md`](04_stack_alignment.md).
