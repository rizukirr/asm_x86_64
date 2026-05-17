# 03.3 — `lea`: addresses without fetching

## A story: the shelf number vs. the cookie on the shelf

**In plain words:** sometimes you don't want the *thing* on the shelf — you just want to know *which shelf number* it lives on. `lea` gives you the shelf number. `mov` would go fetch the cookie.

**The analogy.** You walk into a warehouse with your friend. You say, "Bring me the cookie from shelf 47." Your friend walks over, opens the shelf, grabs the cookie, and brings it back. That's `mov rax, [shelf47]`.

Now you say, "Just tell me which shelf has the cookies." Your friend points and says, "Shelf 47." No cookie changes hands; you just got the location. That's `lea rax, [shelf47]`.

**The technical layer.** `lea` stands for **load effective address**. It evaluates the address expression inside the square brackets — `[base + index*scale + displacement]` — and writes the *resulting address* into the destination register. It does **not** dereference. It does **not** touch memory. Despite the square brackets in the syntax, the brackets here are just the assembler's way of saying "compute this address expression."

## The shape

```asm
lea  dst, [address_expression]
```

`dst` must be a register. The address expression follows the same rules as any memory operand:

```
[base + index*scale + displacement]
```

where `base` and `index` are registers, `scale` is `1`, `2`, `4`, or `8`, and `displacement` is a constant (or a label). Any of these parts is optional.

**In plain words.** Anything you can write between `[` and `]` for a `mov` load, you can write for `lea` instead — and `lea` gives you the address it *would have* loaded from, without doing the load.

## The two uses of `lea`

### Use 1 — taking the address of a label

```asm
lea     rsi, [rip + msg]
```

**In plain words.** "Compute the address of `msg`, expressed as how far it is from the current instruction pointer, and put that address into `rsi`."

**The technical layer.** `[rip + label]` is **RIP-relative** addressing — the standard, position-independent way to refer to a fixed label on x86_64. The assembler turns `rip + msg` into a constant offset baked into the instruction. At runtime, the CPU adds that offset to whatever `rip` is currently pointing at and gets the true address — no matter where the operating system loaded the program in memory.

**Gotcha.** `mov rsi, msg` (without brackets) is **not** the same thing. In a position-independent binary, it either won't link or will produce wrong code. `lea rsi, [rip + msg]` is the right idiom for "give me the address of this label." We used it in Part 01 to point `rsi` at the message we wanted to print.

### Use 2 — `lea` as a free calculator

This is the trick that makes `lea` famous. Because the address expression can compute `base + index*scale + displacement`, you can use `lea` to do **arithmetic** even when no memory is involved.

```asm
lea     rax, [rbx + rcx*4 + 8]      # rax = rbx + rcx*4 + 8
lea     rdx, [rcx + rcx*2]          # rdx = rcx * 3
lea     rax, [rax + rax*4]          # rax = rax * 5
```

**In plain words.** `lea rdx, [rcx + rcx*2]` does what `imul rdx, rcx, 3` does (multiply `rcx` by 3 and store in `rdx`) — but in fewer bytes and without going through the multiplier unit. Compilers love this. You'll see `lea` used as "math that happens to look like an address" all over optimized code.

**Gotcha.** `lea` is not a "real" load — it doesn't touch memory, so the brackets are misleading. Reading optimized assembly, you have to learn to skim past `lea reg, [...]` as "did some math" instead of "fetched something from memory."

**Why is it called load *effective address*?** Because what gets computed is the same address a `mov reg, [...]` would compute and use for the fetch. `lea` simply stops one step early — it produces the address itself.

## The demo

See [`03_lea_address.s`](03_lea_address.s):

```asm
.intel_syntax noprefix

        .section .data
greet:  .ascii  "lea: I know where things live!\n"
        .equ    greetlen, . - greet

        .section .text
        .globl  _start
_start:
        # Use 1: address of a label
        lea     rsi, [rip + greet]
        mov     rax, 1
        mov     rdi, 1
        mov     rdx, greetlen
        syscall

        # Use 2: lea as a calculator
        mov     rbx, 100
        mov     rcx, 5
        lea     rax, [rbx + rcx*4 + 8]      # rax = 100 + 20 + 8 = 128

        # The "multiply by 3" trick
        lea     rdx, [rcx + rcx*2]          # rdx = 5 + 10 = 15

        mov     rax, 60
        xor     rdi, rdi
        syscall
```

**In plain words, step by step:**

1. `lea rsi, [rip + greet]` puts the address of the greeting in `rsi`. The string itself stays put in the data section.
2. The write syscall prints the string.
3. `mov rbx, 100`, `mov rcx, 5` set up two cups.
4. `lea rax, [rbx + rcx*4 + 8]` evaluates `100 + 5*4 + 8 = 128` and stores `128` in `rax`. Zero memory accesses occurred — this is pure arithmetic that just happens to be written in address-expression syntax.
5. `lea rdx, [rcx + rcx*2]` evaluates `5 + 5*2 = 15` and stores `15` in `rdx`. Multiply-by-three in one instruction.
6. Exit cleanly with status 0.

## Build, run, and watch the math

```bash
as -o 03_lea_address.o 03_lea_address.s
ld -o 03_lea_address 03_lea_address.o
./03_lea_address
# => lea: I know where things live!
```

To see the math actually land in registers, use gdb. Set a breakpoint right before the exit syscall:

```bash
gdb ./03_lea_address
(gdb) starti
(gdb) layout regs                 # optional register pane
(gdb) break *_start+<offset>      # or simply step with si until just before exit
(gdb) si                          # step until you're past both lea instructions
(gdb) info registers rax rdx
```

Right before the exit syscall you should see `rax = 0x80` (128) and `rdx = 0xf` (15). Those are the results of the two `lea`-as-calculator computations.

If you don't want to count instructions, an easier trick: temporarily change `xor rdi, rdi` to `mov rdi, rax` and re-build. Now the program exits with `rax mod 256` as the shell status. Run it and:

```bash
./03_lea_address; echo $?
# => 128
```

That's `lea` returning the math directly to your shell. (Don't forget to put `xor rdi, rdi` back if you want clean status-0 exits.)

## Check yourself

1. What does `lea rax, [rcx + rcx*8]` compute, in terms of `rcx`? (Answer: `rcx * 9`. The expression is `rcx*1 + rcx*8`.)

2. Write a single `lea` that puts `rcx * 10` into `rdx`. (Hint: there isn't one. `lea` can't do it in a single instruction — `10` isn't `1 + (1|2|4|8)`. You'd need two `lea`s, or an `imul`. This is one of the few times the trick fails.)

3. Why is `lea rsi, msg` (no brackets) wrong, but `lea rsi, [rip + msg]` right? (Answer: `lea` requires a memory-operand-shape — that is, square brackets. Without them, the assembler doesn't know whether you mean "the address of `msg`" or "the value 0x401000 as an immediate." With `[rip + msg]`, you also get RIP-relative addressing, which is mandatory for position-independent code.)

## Gotcha — `lea` does not set flags

Unlike `add` or `sub`, `lea` does **not** update the CPU flags. This is sometimes the deciding factor for compilers: if they want to compute `a + b` but the surrounding code depends on the flags from a previous comparison, `lea rax, [rax + rbx]` is preferable to `add rax, rbx` because it leaves the flags alone. We meet the flags formally in Part 04.

## What's next

You now know how to copy bytes (`mov`), widen them (`movzx`/`movsx`/`movsxd`), and compute addresses or do free math (`lea`). Time to actually crunch numbers: [Part 04 — Arithmetic](../04_Arithmetic/README.md).
