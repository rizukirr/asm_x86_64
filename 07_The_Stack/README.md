# Part 07 — The Stack

## A story first

Imagine a tall stack of cafeteria plates by a counter. When you bring a new plate, you put it **on top**. When someone needs a plate, they grab the **top** one. You can't pull a plate out from the middle — only the top.

That's exactly how the CPU's **stack** works. It's a special spot in the warehouse (memory) where the worker temporarily piles up values to remember later. The most recent thing piled on is the first thing taken back off. This is called **LIFO** — Last In, First Out.

Why bother? Because the CPU only has a small number of cups (registers) on its desk. When the worker has to step away to do another job, it can't carry every cup with it. So before stepping away, it stacks up the cup contents on the plate stack, does the other job, and pulls them back off when it returns. That's the most common use of the stack.

The stack is also where function calls live — when one function calls another, the CPU writes down "come back to this address when you're done" onto the stack, like leaving a sticky note. We'll explore that more in Part 10.

Vocabulary check:

- **Stack** = the pile of plates. A region of memory used LIFO.
- **`rsp`** = a special register (a cup on the desk) that always points to the top plate. "Stack Pointer."
- **`push`** = add a new plate on top.
- **`pop`** = take the top plate off.
- **Calling convention** = the agreed rules about which cups belong to whom and how the stack is used during function calls.

## What the kernel gives you

When Linux loads your program, it picks a large block of memory (typically 8 megabytes), sets `rsp` to point near the **top** of that block, and lets the stack grow **downward** as more things are pushed. That sounds weird — most piles grow up, not down — but on x86_64 Linux that's the deal.

So when you "push something on the stack," `rsp` actually *decreases* (it now points at a lower-numbered shelf). The next push will land at an even lower shelf number.

```
high addresses
    +---------------+   <- where rsp started
    |   argc/argv   |       (program arguments, set up by the kernel)
    |   env vars    |
    |     ...       |
    +---------------+   <- rsp right now (current "top")
    |  free space   |       (anything below rsp is undefined / future room)
    |               |
    +---------------+
low addresses
```

This direction (downward) is just convention. A stack could grow upward. The OS could put it anywhere. But on x86_64 Linux, the kernel sets it up this way and you just go with it.

## `push` and `pop`

```
push  src       ≡   sub rsp, 8 ; mov [rsp], src
pop   dst       ≡   mov dst, [rsp] ; add rsp, 8
```

What this actually does, in plain words:

`push src` is a shortcut for two steps:
1. Subtract 8 from `rsp` (make room for one 8-byte value lower in memory).
2. Store the value from `src` into the shelf at `[rsp]`.

`pop dst` is the reverse:
1. Load the value from `[rsp]` into `dst`.
2. Add 8 to `rsp` (the slot is now considered free again).

Both move `rsp` by 8 because we're in 64-bit mode — values are 8 bytes wide. (In 32-bit mode they moved by 4.)

Example:

```asm
mov     rax, 1
mov     rbx, 2
push    rax             # rsp -= 8; [rsp] = 1
push    rbx             # rsp -= 8; [rsp] = 2
pop     rcx             # rcx = 2; rsp += 8
pop     rdx             # rdx = 1; rsp += 8
```

What this actually does, in plain words:

1. Put `1` in `rax` and `2` in `rbx`.
2. Push `rax`: lower `rsp` by 8, write `1` to the new top. The plate "1" is now on the stack.
3. Push `rbx`: lower `rsp` by 8 again, write `2`. Now the stack has "2" on top of "1."
4. Pop into `rcx`: take the top plate (`2`) and put it in `rcx`. Raise `rsp` by 8.
5. Pop into `rdx`: take the new top plate (`1`) and put it in `rdx`. Raise `rsp` by 8.

So `rcx = 2` and `rdx = 1` — they came out in **reverse** order of how they went in. That's LIFO.

ASCII view of the plate stack at each step:

```
After push rax:   After push rbx:   After pop rcx:    After pop rdx:
[ ... ]           [ ... ]           [ ... ]           [ ... ]
[  1  ] <- rsp    [  1  ]           [  1  ] <- rsp    [     ] <- rsp
                  [  2  ] <- rsp
```

## Why the stack exists: saving values

Suppose you're in the middle of a calculation and you need `rax` for something else briefly:

```asm
push    rax                     # save rax
mov     rax, 60                 # use rax for something
... do stuff ...
pop     rax                     # restore rax
```

What this actually does, in plain words: stash `rax`'s value on a plate so you can use the cup for something else, do the other work, then take the plate back and pour the saved value into `rax`. The original value is unchanged from `rax`'s point of view.

That's the most basic use. The next, more important use comes in [Part 10](../10_Functions/README.md): when one function calls another, the **return address** (where to come back to) is automatically written on the stack by the `call` instruction. Local variables and saved registers also live there.

## Stack frames (preview)

A typical C function compiled to assembly looks like this:

```asm
my_func:
        push    rbp                     # save caller's frame pointer
        mov     rbp, rsp                # establish our frame pointer
        sub     rsp, 32                 # carve 32 bytes for locals

        ... body, using [rbp - 8], [rbp - 16], etc. ...

        mov     rsp, rbp                # discard locals
        pop     rbp                     # restore caller's frame pointer
        ret
```

What this actually does, in plain words:

The three lines at the top are called the **prologue**. They:
1. Save the caller's `rbp` so we can restore it later.
2. Set our own `rbp` to point at this function's frame anchor.
3. Carve out 32 bytes of stack room for our local variables.

Now local variables live at fixed offsets like `[rbp - 8]` (first local), `[rbp - 16]` (second local), and so on. Since `rbp` doesn't move during the function, those offsets stay constant — handy for the compiler.

The three lines at the bottom are the **epilogue** — they undo the prologue in reverse. Then `ret` jumps back to wherever the caller was.

Modern compilers often **skip the frame pointer** (with the option `-fomit-frame-pointer`, default at optimization level `-O1` or higher) and instead reference everything off `rsp`. That frees `rbp` to be used as a regular register. Debuggers prefer the frame-pointer version because it makes stack traces easy.

## Alignment: the silent killer

The System V AMD64 ABI (the rulebook for how functions call each other on Linux x86_64) requires that **`rsp` is a multiple of 16 right before any `call` instruction**. Since `call` itself pushes an 8-byte return address, this means that *at the entry of any function*, `rsp` will be 8 less than a multiple of 16 (i.e., `rsp ≡ 8 (mod 16)`).

If you forget this and call a libc function that uses SSE instructions (which need 16-byte alignment for some operands), you'll get a `SIGSEGV` (segmentation fault) deep inside `printf` for no apparent reason. The standard fix on entry to a hand-written function that calls libc:

```asm
sub     rsp, 8                  # re-align after the call's 8-byte push
... call some_libc_function ...
add     rsp, 8
```

Or, if you're going to allocate locals anyway, just allocate a multiple of 16 bytes (with the extra 8 from the return address in mind).

## A worked example: reverse three numbers via the stack

```asm
.intel_syntax noprefix
        .globl  _start
_start:
        mov     rax, 1
        mov     rbx, 2
        mov     rcx, 3

        push    rax
        push    rbx
        push    rcx

        pop     rax             # rax = 3 (last pushed)
        pop     rbx             # rbx = 2
        pop     rcx             # rcx = 1

        mov     rdi, rax        # exit(3)
        mov     rax, 60
        syscall
```

What this actually does, in plain words:

1. Put `1`, `2`, `3` into `rax`, `rbx`, `rcx`.
2. Push them onto the stack in that order — so the stack from bottom to top is `1, 2, 3`.
3. Pop them off. Top first: `3` lands in `rax`, then `2` in `rbx`, then `1` in `rcx`. The values are reversed compared to the registers they came from.
4. Exit with `rax = 3`.

```bash
as -o rev.o rev.s && ld -o rev rev.o
./rev ; echo $?
# => 3
```

## Try it (gdb)

```bash
as -o rev.o rev.s && ld -o rev rev.o
gdb ./rev
(gdb) starti
(gdb) display/4gx $rsp          # show 4 qwords starting at rsp
(gdb) si                        # step through; watch rsp & memory change
```

Watch `rsp` decrease by 8 on each `push` and the value appear at the new top of the stack.

## Try it

1. Push five values, then pop them. What order do they come out in? (You should get them in reverse — the last one pushed is the first one popped.)
2. Try `pop`-ing more times than you've pushed. The program won't crash immediately, but `rsp` is now pointing into the env/argv area (the stuff the kernel set up above the stack). Corrupting it usually crashes the program a moment later. **The CPU does not check stack bounds.** Keeping the stack sane is *your* problem.
3. Replace the three `push`/`pop` pairs with a single `sub rsp, 24` plus `mov [rsp], rax`, `mov [rsp+8], rbx`, `mov [rsp+16], rcx`. Convince yourself this stores the same three values in the same shelves. This is how compilers really write function prologues — one big subtraction instead of many pushes.

## What's next

We've stored data on the stack and changed `rsp`. We have not yet changed `rip` (the worker's "what to do next" pointer) based on a *condition*. [Part 08](../08_Control_Flow/README.md) introduces `cmp`, `test`, and conditional jumps — the foundation of `if`, `while`, and every branching construct.
