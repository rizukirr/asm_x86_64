# 07.02 — `push` and `pop`

## A story: the plate stack again

**In plain words:** `push` and `pop` are the two basic moves on the stack. `push` adds a value to the top. `pop` removes the top value and hands it to a register.

**The analogy.** Back to the cafeteria tray dispenser. `push rax` says "take whatever is in cup `rax`, slide a fresh tray under the pile by lowering the spring 8 inches, then write the value onto that new top tray." `pop rcx` says "lift the top tray off, read its value into cup `rcx`, and let the spring relax 8 inches."

The spring lowering / relaxing **is** the change to `rsp`. The writing or reading **is** the memory access through `[rsp]`.

## The technical layer

The two instructions are **shorthand** for two micro-operations each:

```
push  src       ≡   sub rsp, 8 ;  mov [rsp], src
pop   dst       ≡   mov dst, [rsp] ;  add rsp, 8
```

Read those carefully:

- **`push src`**
  1. Lower `rsp` by 8 (make room for one 8-byte value lower in memory).
  2. Store `src`'s value at the memory address `[rsp]` — which is now the new top.

- **`pop dst`**
  1. Load the value at `[rsp]` (the current top) into `dst`.
  2. Raise `rsp` by 8 (the slot is now considered free again).

**Gotcha — why 8?** On x86_64 the natural word size is 64 bits = 8 bytes. `push` and `pop` always move `rsp` by exactly 8 bytes, regardless of how much of the register you actually care about. (In old 32-bit mode, they moved by 4.)

**Gotcha — `pop` does NOT erase the old slot.** After `pop`, the byte values in memory are still there — `rsp` simply moved past them. They'll be quietly overwritten by the next `push`. **Never assume "popped memory is zeroed."** It isn't.

## Worked example: prove LIFO

See [`02_push_pop.s`](02_push_pop.s):

```asm
.intel_syntax noprefix

        .section .text
        .globl  _start
_start:
        mov     rax, 1
        mov     rbx, 2
        mov     rcx, 3

        push    rax                     # rsp -= 8; [rsp] = 1
        push    rbx                     # rsp -= 8; [rsp] = 2
        push    rcx                     # rsp -= 8; [rsp] = 3

        pop     r10                     # r10 = 3 (last pushed comes off first)
        pop     r11                     # r11 = 2
        pop     r12                     # r12 = 1

        mov     rdi, r10                # exit status = 3
        mov     rax, 60
        syscall
```

**In plain words.** Put `1`, `2`, `3` into three registers. Push them in that order: `1` first, then `2`, then `3`. Then pop into three other registers. The values come out **reversed** — `3, 2, 1`. We exit with the first pop (`3`) as the status code, so the shell's `$?` will read `3`.

## Build and run

```bash
as -o /tmp/02.o 02_push_pop.s
ld -o /tmp/02    /tmp/02.o
/tmp/02 ; echo $?
```

You should see:

```
3
```

That `3` is hard proof of LIFO. The last value pushed (`3`) was the first popped.

## ASCII view, step by step

```
Initial:            push rax(1):        push rbx(2):        push rcx(3):
                    [   1  ] <- rsp     [   1  ]            [   1  ]
                                        [   2  ] <- rsp     [   2  ]
                                                            [   3  ] <- rsp

pop r10 -> 3:       pop r11 -> 2:       pop r12 -> 1:
[   1  ]            [   1  ] <- rsp     [      ] <- rsp
[   2  ] <- rsp
```

(Remember, the picture is **upside down** in memory — the "top" of the picture has the *lowest* address. The newest plate sits at the lowest address.)

## A practical use: borrow a register

**In plain words:** sometimes a calculation needs `rax`, but you also need to call a syscall (which clobbers `rax`). The standard trick:

```asm
push    rax                     # stash rax's value on the stack
mov     rax, 1                  # use rax for the write syscall
mov     rdi, 1
lea     rsi, [rip + msg]
mov     rdx, msg_len
syscall                         # rax is now the syscall's return value
pop     rax                     # restore the original value
```

You "borrowed" `rax` for a moment by saving it on the stack, did your other business, and pulled it back. From `rax`'s point of view, nothing happened.

**The analogy.** You needed your coffee cup for a quick errand. You put the half-finished coffee on a tray (`push`), used the empty cup, then later poured the saved coffee back in (`pop`).

## Gotcha — pushes and pops must balance

The single most common assembly bug for beginners: somewhere in a function, you `push` something and forget to `pop` it. Or you `pop` something you never pushed. The function "works" — until it tries to return, at which point `ret` reads a totally bogus return address off the stack and the program crashes (`SIGSEGV`) or jumps to a random instruction (`SIGILL`).

**Discipline:** every `push` in a function must have a matching `pop` (or be undone by some other adjustment to `rsp`) before the function returns.

## Check yourself

1. **You execute `push rax` when `rsp = 0x7fff0040`. What is `rsp` afterward?**
   *Answer: `0x7fff0038` (subtract 8).*

2. **You push four values and pop five. What's in the fifth register?**
   *Answer: whatever happened to be sitting one slot above your first push — almost certainly garbage from the kernel's argv/env setup. The CPU never warned you.*

3. **What's the difference between `pop rax` and `mov rax, [rsp] ; add rsp, 8`?**
   *Answer: none — `pop` is exactly that pair of operations, fused into one shorter instruction.*

4. **You push `rax` and never pop it, then execute `ret`. What happens?**
   *Answer: `ret` reads `[rsp]` expecting a return address, but it reads the saved `rax` instead. Control jumps to whatever number that was. Almost always: crash.*

## Try it (gdb)

```bash
as -o /tmp/02.o 02_push_pop.s && ld -o /tmp/02 /tmp/02.o
gdb /tmp/02
(gdb) starti
(gdb) display/4gx $rsp          # show 4 quadwords at the top of the stack
(gdb) si                        # step one instruction at a time
```

Step through each `push` and `pop` and watch `rsp` change by 8 and the values appear/disappear at the top.

## Next

[`03_stack_frames.md`](03_stack_frames.md) — using `rsp` as scratch room for local variables, the prologue/epilogue pattern, and `rbp` as a frame anchor.
