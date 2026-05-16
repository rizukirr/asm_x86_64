# Part 06 — Addressing Modes & `lea`

## A story first

Imagine a gigantic warehouse with millions of numbered shelves stretching off into the distance. Every shelf has a number painted on it — shelf 0, shelf 1, shelf 2, all the way up to ridiculous numbers. The warehouse is called **memory** (or **RAM** — random access memory, meaning the worker can jump straight to any shelf without walking past the others).

Each shelf can hold a single byte. To put something into memory or take something out, the worker has to know the shelf number — that's called the **address**.

But people don't actually want to think in raw shelf numbers like "shelf 140737488355328." That's painful. So x86 has a tiny built-in calculator that computes addresses for you using a formula. You hand the calculator a few register values and constants, and it works out which shelf to use.

In this chapter we learn that formula. And we meet `lea`, a magical instruction that uses the calculator to compute addresses — but doesn't actually go fetch anything. That makes `lea` secretly a math instruction.

Vocabulary check:

- **Memory / RAM** = the warehouse of numbered shelves. Slower than registers.
- **Address** = the shelf number.
- **Load** = read from a shelf into a register.
- **Store** = write from a register into a shelf.
- **Effective address** = the actual shelf number the CPU works out from the formula below.

## The one formula

The whole of x86 memory addressing collapses into a single formula:

```
effective_address  =  base  +  index * scale  +  displacement
```

Each piece does a job:

- **`base`** — a 64-bit register (or the special register `rip`). Think of it as the starting shelf.
- **`index`** — any 64-bit register except `rsp`. Think of it as "how many steps to walk from the base."
- **`scale`** — must be `1`, `2`, `4`, or `8`. Think of it as "how big each step is." (Why those numbers? Because typical data types are 1, 2, 4, or 8 bytes wide.)
- **`displacement`** — a plain signed constant up to about ±2 GiB. Think of it as a final fixed nudge.

Any subset of those pieces is allowed. Every legal `[ ... ]` operand is some specialization of the formula:

```asm
[rax]                           # base only
[rax + 8]                       # base + disp
[rax + rcx]                     # base + index
[rax + rcx*4]                   # base + index*scale  (array of 4-byte ints!)
[rax + rcx*8 + 16]              # the full form
[rip + label]                   # RIP-relative (more on this below)
[label]                         # absolute (rare in 64-bit code)
[0x401000]                      # absolute by raw number (rarer still)
```

The CPU computes that address, then either **loads** from it (reads the shelf), **stores** to it (writes the shelf), or — with the special `lea` instruction — just hands you the address itself **without going to the shelf**.

## Why this matters: array indexing for free

In C, here's how you read element `i` of an array of integers:

```c
int  arr[10];
int  i;
int  x = arr[i];                // logically: x = *(arr + i)
```

In assembly, if `rbx` holds the address of `arr[0]` and `rcx` holds the index `i`:

```asm
mov     eax, [rbx + rcx*4]      # int is 4 bytes -> scale 4
```

What this actually does, in plain words:

The CPU's address calculator computes `rbx + rcx * 4`, which is exactly the address of `arr[i]` because each `int` is 4 bytes wide. The CPU goes to that shelf, picks up the 4-byte value sitting there, and puts it into `eax`. One instruction, one cycle (unless the shelf is far away in slow memory and we have a cache miss).

The `*4` is the size of one `int`. For an array of 8-byte integers (`int64_t`), it would be `*8`. For an array of `char` (1 byte), it's `*1` (or you can leave it out).

So why does C scale by the size of the element? Not because language designers thought it was elegant — but because that's literally what the CPU's addressing hardware does in one step. The language is shaped by the chip.

## `lea` — the math instruction in disguise

`lea` stands for **Load Effective Address**. The form is `lea dst, [mem]`, and it **computes the address that the formula would give, then stores that address in `dst` — without actually visiting the shelf**. The brackets `[ ... ]` are purely a formula here. No memory is touched.

Because of that, `lea` is essentially a general-purpose **arithmetic** instruction in disguise:

```asm
lea     rax, [rbx + rcx]        # rax = rbx + rcx          (a 3-operand add!)
lea     rax, [rbx + rbx*4]      # rax = rbx * 5            (multiply by 5)
lea     rax, [rbx + rbx*8]      # rax = rbx * 9
lea     rax, [rbx*4 + 7]        # rax = rbx*4 + 7
```

What this actually does, in plain words: the address calculator doesn't care that we're not really doing memory access — it just performs the arithmetic and hands us the result.

Why is this so useful?

1. **Three operands at once.** A normal `add` destroys one of its inputs (`add rax, rbx` overwrites `rax`). `lea rax, [rbx + rcx]` adds `rbx` and `rcx` into `rax` *without disturbing either one*. Compilers love this.
2. **Multiplying by small constants for free.** `rbx + rbx*4` is `rbx * 5`. So `*3` (`rbx + rbx*2`), `*5`, and `*9` are all one `lea`. Cheaper than `imul`.
3. **Computing pointers.** Getting the address of a struct field, a label, or an element of an array is what `lea` was designed to do.

And one more bonus: **`lea` does not touch the FLAGS lights**. That means you can compute things between a `cmp` and a conditional jump without messing up the flags the jump is about to read. Another reason compilers reach for it.

## RIP-relative addressing

```asm
lea     rax, [rip + msg]        # rax = address of msg
mov     rax, [rip + counter]    # load 8 bytes from counter
```

`rip` is a special register that always holds the address of the *next* instruction to be executed. When you write `[rip + label]`, the linker fills in a fixed offset so that `rip + that_offset` lands exactly on `label`. The result is: "wherever this code ends up in memory, the address still points at the right thing."

This matters because modern operating systems randomize where programs load into memory (a security feature called ASLR — Address Space Layout Randomization). The old style `mov rax, [label]` uses an absolute shelf number baked into the instruction, which breaks under randomization. `[rip + label]` is *relative* to the current instruction, so it works regardless. This is what `gcc -fPIE` (default these days) emits everywhere. **Use `[rip + label]` always.**

## A worked example: sum the first N elements of an int array

```asm
.intel_syntax noprefix
        .section .data
arr:    .long   10, 20, 30, 40, 50          # 5 ints of 4 bytes each
n:      .quad   5

        .section .text
        .globl  _start
_start:
        lea     rbx, [rip + arr]            # rbx = &arr[0]
        mov     rcx, [rip + n]              # rcx = n
        xor     eax, eax                    # rax = 0  (accumulator)
        xor     rdx, rdx                    # rdx = i  (index)
.loop:
        cmp     rdx, rcx
        jge     .done
        add     eax, [rbx + rdx*4]          # eax += arr[i]
        inc     rdx
        jmp     .loop
.done:
        # exit(rax)
        mov     rdi, rax
        mov     rax, 60
        syscall
```

What this actually does, in plain words:

- The `.data` section is our pantry — labeled shelves with starting contents. `arr` is a sticky note on a shelf holding five 4-byte numbers. `n` is a sticky note on another shelf holding the count `5`.
- `lea rbx, [rip + arr]`: ask the calculator for the address of `arr` (without reading from it) and store that address in `rbx`. So `rbx` now points at `arr[0]`.
- `mov rcx, [rip + n]`: actually load the value 5 from the `n` shelf into `rcx`.
- `xor eax, eax`: set the running total to 0.
- `xor rdx, rdx`: set the loop counter `i` to 0.
- The loop compares `i` to `n`, and if `i >= n` jumps out.
- The payload line is the magic: `add eax, [rbx + rdx*4]`. The calculator works out `rbx + rdx*4`, which lands on shelf `arr[i]`, the CPU loads the 4-byte value there, and adds it to the running total in `eax`.
- `inc rdx` bumps the index by 1; jump back to the top.
- When done, exit with the sum as the exit code.

ASCII diagram of the shelves at the start:

```
   address        contents
   --------       ----------
   &arr + 0       10   (4 bytes)
   &arr + 4       20
   &arr + 8       30
   &arr + 12      40
   &arr + 16      50
```

Index `i=2` and scale 4 → `&arr + 8` → shelf holding `30`. That's exactly what the addressing hardware does.

```bash
as -o sum.o sum.s && ld -o sum sum.o
./sum ; echo $?
# => 150
```

That single payload instruction `add eax, [rbx + rdx*4]` does *both* the load `arr[i]` and the addition. The whole `base + index*scale` mechanism makes walking an array painless.

## Try it

1. Change `arr` to `.quad 10, 20, 30, 40, 50` (8-byte elements instead of 4). Update the scale in `[rbx + rdx*4]`. What does it become? (Answer: `*8`.)
2. Use `lea` to compute `5*x + 3` for `x = rcx` into `rax` in **one instruction**. (Answer: `lea rax, [rcx*4 + rcx + 3]`.)
3. Disassemble a `gcc -O2` build of a function that returns `a + b*4 + 7`. You'll almost certainly see one `lea` and a `ret`.

## What's next

We have registers, instructions, and memory access. We're missing one thing every program needs: a stack — a special spot for the CPU to save things temporarily. [Part 07](../07_The_Stack/README.md).
