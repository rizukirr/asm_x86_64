# 10.1 — `call` and `ret`: the bookmark trick

## The story: leaving a sticky note before you walk away

**In plain words.** A function is a chunk of code you can jump to and come back from. The trick is "coming back" — the CPU has no built-in concept of a function, so it needs a *sticky note* telling it where to return. `call` writes the note; `ret` reads it.

**The analogy.** You're reading a long book. The phone rings — someone needs you to look up a recipe in a different book on a different shelf. Before you walk over, you slap a **bookmark** into your current page. When you're done with the recipe, you walk back to your chair, glance at the bookmark, and pick up reading exactly where you left off.

That bookmark is the **return address**. The bookshelf where you stack bookmarks (oldest on the bottom, newest on top) is the **stack**.

**The technical layer.** Two instructions do the entire job:

```
call target     ≡   push <address of next instruction> ; jmp target
ret             ≡   pop rip
```

- `call` pushes the address of the instruction *immediately after* the `call` onto the stack, then jumps to `target`. Two micro-actions, one instruction.
- `ret` pops 8 bytes off the top of the stack and writes them into `rip` (the instruction pointer — the bookmark of where the CPU is reading right now). So the CPU resumes at the address that was just popped.

That's it. The CPU has no "function table," no "frame magic," no "call depth counter." It just pushes a number and jumps; later it pops a number and jumps. Functions are a *convention* built on top of those two tiny primitives.

**Gotcha.** `ret` blindly trusts whatever 8 bytes are sitting on top of the stack. If somewhere along the way you `push`ed something and forgot to `pop` it, `ret` will read that thing as an address and jump to it. The program crashes (or worse — if an attacker chose those bytes, jumps into attacker-controlled code). This is the foundation of stack-buffer-overflow exploits.

**Check yourself.** If `call` is "push then jump," what would happen if you wrote `push next_addr` and `jmp target` by hand instead of `call`? (Answer: exactly the same thing. `call` is just a shorthand for those two steps fused into one instruction.)

## The stack, briefly

The stack is a region of memory that grows *downward* (toward lower addresses). One register, `rsp` (the **stack pointer**), always holds the address of the topmost item. Two operations move it:

- `push X` — subtract 8 from `rsp`, then store `X` at `[rsp]`.
- `pop X` — load `X` from `[rsp]`, then add 8 to `rsp`.

You can think of `rsp` as a finger pointing at the top plate of a stack of dinner plates. `push` adds a plate; `pop` removes one. `call` pushes a plate (the return address). `ret` pops one.

## The code

See [`01_call_and_ret.s`](01_call_and_ret.s):

```asm
.intel_syntax noprefix

        .section .data
msg:    .ascii  "double(21) = 42\n"
        .equ    msglen, . - msg

        .section .text
        .globl  _start

double:
        mov     rax, rdi        # copy input into rax
        add     rax, rax        # rax = 2 * input
        ret

_start:
        mov     rax, 1          # write
        mov     rdi, 1
        lea     rsi, [rip + msg]
        mov     rdx, msglen
        syscall

        mov     rdi, 21
        call    double

        mov     rdi, rax        # exit status = return value
        mov     rax, 60
        syscall
```

**In plain words.** We print a friendly banner so you can see the program ran, then `call double` with the number 21 sitting in `rdi`. `double` doubles it and returns 42 in `rax`. We hand that 42 to the `exit` syscall as our exit code.

## Build and run

```bash
as -o /tmp/t.o 01_call_and_ret.s
ld -o /tmp/t /tmp/t.o
/tmp/t
# => double(21) = 42
echo $?
# => 42
```

## What happens during `call double`, plate by plate

Just before `call double`:

```
   higher addr
   +----------------+
   |  ... older    |
   +----------------+  <- rsp (pointing at whatever was there)
   lower addr
```

`call double` runs. It writes the address of the *next* instruction (the `mov rdi, rax` after the call) onto the top of the stack, and bumps `rip` to `double`:

```
   +----------------+
   |  ... older    |
   +----------------+
   | ret addr       |   <- rsp
   +----------------+
```

`double` runs three instructions. It does not touch `rsp` (it's a *leaf* — no nested call, no locals). Then `ret` pops the top plate into `rip`. The CPU is suddenly executing the instruction right after `call`, and the stack looks exactly like it did before the call:

```
   +----------------+
   |  ... older    |
   +----------------+  <- rsp
```

That symmetry — stack same before and after — is the contract every well-behaved function obeys. Break it and the next `ret` reads the wrong note.

## Try it

1. **Write `call` by hand.** Replace `call double` with the two-instruction sequence it stands for:

   ```asm
           lea     rax, [rip + after_call]
           push    rax
           jmp     double
   after_call:
   ```

   Rebuild and run. Same exit code (42). You just open-coded the `call` instruction.

2. **Forget to `ret`.** Delete the `ret` in `double`. Rebuild and run. The CPU will keep walking forward into `_start`'s code (because `double` is above `_start` in the file — execution just spills into the next bytes). You'll see strange behavior, or possibly the right answer for the wrong reason. Lesson: there is no automatic return; only `ret` returns.

3. **Mess up the stack.** Add `push rax` at the start of `double` and *don't* match it with a `pop`. Rebuild and run. `ret` will pop the wrong 8 bytes and jump to garbage. The kernel will kill the program with a segfault. Now add the missing `pop rax` — works again.

## What's next

You can call. You can return. But how does the callee know *which* register holds the first argument, and where to leave the answer? That's a convention — the **System V AMD64 ABI**. See [`02_calling_convention.md`](02_calling_convention.md).
