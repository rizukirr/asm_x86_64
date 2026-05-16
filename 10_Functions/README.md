# Part 10 — Functions & the System V ABI

Think about **phoning a specialist**. You have a problem ("what is 10 + 20 + 30?"), you ring up someone who is good at that, you tell them the inputs, they do the work, and they call you back with the answer. While they are working, you do not need to know how — you just know *what numbers to give them* and *which cup to look in for the answer*.

A *function* in assembly is exactly that phone call. There is a chunk of code somewhere with a name on it (the specialist). You jump to it after writing down where you came from, it does its job, and when it is done it jumps back to right where you left off.

A *function* is just a block of code you can `call` and `ret` from. Two instructions do all the work:

```
call target     ≡   push <address of next instruction> ; jmp target
ret             ≡   pop rip
```

`call` saves where to come back to (on the stack) and jumps. `ret` reads that saved address and jumps back. The CPU has no idea what a "function" is; that's the convention you build on top.

**What this actually does, in plain words:**

- `call target` does two things in one go: (1) write a sticky note on top of the stack of plates saying "when you are done, come back to *this exact spot*," and (2) jump to wherever `target` lives. The sticky note is called the **return address**.
- `ret` does the reverse: (1) take the top sticky note off the stack, (2) move the bookmark (`rip`) to the address written on it. The CPU is now back where it was, like nothing happened.

That is the whole machinery. There is no special "function" thing in the chip; it is just a clever pair of instructions that move the bookmark and remember where to come back to.

The **stack** is our LIFO ("last in, first out") pile of plates. We `push` (put a plate on top) and `pop` (take the top plate off). `rsp` is the cup that always holds the address of the topmost plate. Every `call` puts one plate (the return address) on; every `ret` takes one plate off.

## The System V AMD64 ABI

A *calling convention* is an agreement between caller and callee about who puts what where. Linux, macOS, BSDs all use **System V AMD64**. (Windows uses a different one — Microsoft x64 — with different argument registers. We'll only cover SysV.)

**Plain words:** Suppose every specialist used a different rule for "which cup do I put the first argument in?" Chaos. So everyone agrees, ahead of time, on a fixed set of rules. That agreement is the *calling convention*, also called an **ABI** (Application Binary Interface). It is the etiquette of phone calls: who speaks first, which cup the answer goes in, who tidies up after.

Linux uses the **System V AMD64** rulebook. Windows uses a different one. We will only learn Linux's.

### Argument passing

The first six integer/pointer arguments go in:

| Position | Register |
| -------- | -------- |
| 1st      | `rdi`    |
| 2nd      | `rsi`    |
| 3rd      | `rdx`    |
| 4th      | `rcx`    |
| 5th      | `r8`     |
| 6th      | `r9`     |

Remember "**D**estination, **S**ource, **D**ata, **C**ounter, 8, 9". A 7th argument and beyond go on the stack, pushed right-to-left, with the first stack arg at `[rsp + 8]` on entry (just past the return address).

**Plain words:** Before you `call` a specialist, drop the first input in cup `rdi`, the second in cup `rsi`, the third in cup `rdx`, and so on. If you have more than six inputs, put the extras on the stack of plates. The mnemonic "Destination, Source, Data, Counter, 8, 9" is a memory trick to remember the order — it spells out the original 1970s names of these registers.

### Return values

`rax` — and if you return a 128-bit thing, `rdx:rax`. Floating-point returns use `xmm0`/`xmm1`.

**Plain words:** When the specialist is done, they put the answer in cup `rax`. Always. If the answer is bigger than fits in one cup, they split it across `rdx` and `rax`. For decimal numbers (floating-point), they use a different family of cups called `xmm0`, `xmm1`, etc.

### Caller-saved vs callee-saved

Some registers the caller must save before the call, others the callee must preserve.

| Caller-saved (scratch — call may clobber) | Callee-saved (call preserves) |
| ----------------------------------------- | ----------------------------- |
| `rax rcx rdx rsi rdi r8 r9 r10 r11`        | `rbx rbp r12 r13 r14 r15`     |

Plus `rsp` is always preserved (functions must leave it where they found it, modulo the return address being popped).

**Plain words:** Cups come in two flavors.

- **Caller-saved** cups are "scratch paper." If you are about to phone someone and you have a number in cup `rdi` that you want to keep, *you* must write it down before the call, because the specialist is free to dump out cup `rdi` and use it for their own work.
- **Callee-saved** cups are "promised cups." If a specialist uses cup `rbx`, they must put back whatever was in it before they return, exactly the way they found it. That way the caller can leave a value in `rbx`, make a phone call, and trust that `rbx` still has the same number afterwards.

This is a peace treaty: every cup is either "yours to wreck" or "promised to be restored." Both sides obey the same list.

**Rule of thumb:** if you're writing a function, you can use any register freely, but if you touch one of `rbx`/`rbp`/`r12`–`r15`, you must `push` it at entry and `pop` it at exit. If you're calling a function and you need to keep a value across the call, either keep it in a callee-saved register or `push`/`pop` it yourself.

### Stack alignment

`rsp` must be 16-byte-aligned **at the moment of `call`**. After `call` pushes 8 bytes (the return address), `rsp ≡ 8 (mod 16)` at function entry. Your function either:

- Doesn't call anything (a "leaf") — no alignment work needed.
- Calls something — adjust `rsp` by 8 more (alone, or by allocating a multiple of 16 for locals) before the inner `call` so it's back to 16-aligned.

**Plain words:** There is an extra rule about the stack of plates: at the moment you `call` someone, the top of the stack must be at an address divisible by 16. Why 16? Modern CPUs have special "wide" instructions that read sixteen bytes at once, and those instructions are picky about where they read from. The peace treaty just enforces "always be 16-aligned at call time" so any function can use them safely.

The `call` itself pushes 8 bytes (the return address), so when *your* function starts running, `rsp` is 8-off from a multiple of 16. To call somebody else, you need to push another 8 bytes (or some multiple of 16 plus 8) to get back to a multiple of 16. The simplest fix is a single `push rbp` at the top of your function — it both saves `rbp` (a callee-saved cup) and bumps the stack back to alignment.

If you forget this, your program might run fine for years and then crash when libc decides to use a SIMD instruction on your stack frame. It is a famously sneaky bug.

## A simple function

```asm
.intel_syntax noprefix
        .text
        .globl  _start

# int sum3(int a, int b, int c) { return a + b + c; }
sum3:
        mov     rax, rdi                # a
        add     rax, rsi                # + b
        add     rax, rdx                # + c
        ret

_start:
        mov     rdi, 10                 # a
        mov     rsi, 20                 # b
        mov     rdx, 30                 # c
        call    sum3

        mov     rdi, rax
        mov     rax, 60
        syscall
```

```bash
as -o sum3.o sum3.s && ld -o sum3 sum3.o
./sum3 ; echo $?
# => 60
```

**What this actually does, in plain words:**

- `sum3` is the specialist. By the convention, it expects its three inputs in cups `rdi`, `rsi`, `rdx`. It copies the first one into `rax`, then adds the other two on top. The final sum is in `rax`. It calls `ret` to phone its caller back.
- `_start` is the caller. It loads `10`, `20`, `30` into the three argument cups, then `call`s `sum3`. After the call returns, the answer (`60`) is sitting in `rax`. We move that answer into `rdi` (where the `exit` system call wants the exit code), put `60` (the syscall number for `exit`) into `rax`, and trigger the syscall.

The program exits with status `60`, which is what `echo $?` prints.

`sum3` is a *leaf function* — it doesn't call anything — so it doesn't need a prologue/epilogue.

**Plain words:** A "leaf" function is one that does not phone anyone else. It only uses scratch cups and never touches the promised ones, so it does not need to set up bookkeeping. Just compute and `ret`.

## A function with locals

```asm
# int square_plus(int x, int y) {
#     int sq = x * x;
#     return sq + y;
# }
square_plus:
        push    rbp
        mov     rbp, rsp
        sub     rsp, 16                 # 16 bytes of locals (8 used, 8 padding for align)

        mov     rax, rdi
        imul    rax, rdi                # rax = x*x
        mov     [rbp - 8], rax          # sq = rax

        mov     rax, [rbp - 8]
        add     rax, rsi                # + y

        mov     rsp, rbp
        pop     rbp
        ret
```

**What this actually does, in plain words:** This is the "long-form" function shape, called a *prologue and epilogue*.

Prologue (at the top):
- `push rbp` saves the caller's `rbp` cup onto the stack of plates (promised cup rule).
- `mov rbp, rsp` makes `rbp` point at our current stack top. From here on, `rbp` is a stable anchor; everything in our local "frame" is at a known offset from it.
- `sub rsp, 16` reserves 16 bytes of room on the stack for local variables. (We only need 8 for `sq`, but we round up to 16 to keep alignment.)

Body:
- Compute `x * x` in `rax`, then store it into the slot `[rbp - 8]` — that is our local variable `sq`, sitting on the stack.
- Read `sq` back out and add `y` to it. Result is in `rax`.

Epilogue (at the bottom):
- `mov rsp, rbp` throws away the local frame.
- `pop rbp` restores the caller's `rbp`.
- `ret` jumps back.

The frame looks like this in the stack-of-plates picture:

```
   higher addresses
   +----------------+
   | return address |  <- pushed by `call`
   +----------------+
   | saved rbp      |  <- pushed by our prologue
   +----------------+  <- rbp points here
   | sq (8 bytes)   |  <- [rbp - 8]
   +----------------+
   | padding        |
   +----------------+  <- rsp points here
   lower addresses
```

Compare to what `gcc -O0` would emit for the C version — it'll be nearly identical. At `-O2`, the compiler skips the frame entirely and emits something close to:

```asm
square_plus:
        mov     rax, rdi
        imul    rax, rax
        add     rax, rsi
        ret
```

…because there's no real need for a local.

**Plain words:** With optimizations on, the compiler notices that `sq` is just a temporary number — it never escapes the function, no one else needs to see it, so why bother putting it on the stack? Keep it in a cup the whole time. That is why `-O2` code looks so much shorter than `-O0` code.

## `call`ing through the stack

After `call sum3`, `rsp` points to the return address. `sum3` reads its args from registers, computes, and `ret`s. The stack discipline is symmetric: the callee must leave `rsp` exactly where it was when it entered (the return address still on top), and `ret` pops it.

If a function returns without `ret`-ing, or `ret`s with the wrong value on top of the stack, control transfers to garbage and the program crashes. This is the basis of stack-buffer-overflow attacks: overwrite the saved return address, point it at attacker-controlled code.

**Plain words:** `ret` blindly trusts whatever sticky note is on top of the stack of plates. If a sloppy function leaves an extra plate on top, `ret` will read the wrong sticky note and jump to a random place — and the program crashes (or worse, runs attacker-supplied code). This is how a "buffer overflow exploit" works: a hacker writes too much data into a stack variable, the extra data spills over and overwrites the return address sticky note, and when the function returns it jumps to the hacker's address instead. Stack discipline is therefore a *security* concern as much as a correctness one.

## Try it

1. Implement an asm `factorial(n)` function using recursion. Watch the stack grow in gdb (`x/16gx $rsp`).
2. Add a 7th argument to `sum3` so you have to pass it on the stack. Adjust `_start` to push it. Read it in the callee as `[rsp + 8]` (after entry; before any other stack moves).
3. Write a function that clobbers `rbx` without saving it, call it from a `_start` that relies on `rbx` after the call. Observe corruption. Now fix it with `push rbx`/`pop rbx`.

## What's next

You now know how a function *works*. Time to call into real software: [Part 11](../11_Talking_To_C/README.md) — calling `printf` from asm, and calling asm from C.
