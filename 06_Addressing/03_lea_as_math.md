# 03 — `lea`: the Math Instruction in Disguise

## A story: the calculator that never goes shopping

**In plain words:** `lea` borrows the address calculator we met in topic 01, runs the formula, and hands you the answer — *without* ever walking to the shelf. So if you ignore the "address" interpretation, `lea` is just a fancy arithmetic instruction that can add and multiply in a single step.

**The analogy.** The warehouse has a clerk at the door whose job is to compute shelf numbers for the workers. Normally a worker says "compute shelf `rbx + rcx*4` and go fetch the box." But you can also walk up to the clerk and say "I don't actually want the box. Just *tell me the number you'd compute.*" The clerk thinks for a moment, says "47," and you walk off with that number written on a sticky note. That's `lea`.

**The technical layer.** `lea` stands for **Load Effective Address**. The form is `lea dst, [mem]`. It runs the `base + index*scale + disp` formula and stores the *result* in `dst`. The brackets are now purely a formula. No memory is touched.

Compare:

```asm
mov     rax, [rbx + rcx*4]      # fetch the 8 bytes at that shelf into rax
lea     rax, [rbx + rcx*4]      # put the shelf NUMBER into rax (no fetch)
```

Same brackets, different verb, very different meaning.

**Check yourself.** Why might a compiler *prefer* `lea rax, [rbx + rcx]` over `mov rax, rbx ; add rax, rcx`? (Three reasons: it's one instruction, it doesn't destroy either input, and it doesn't touch FLAGS. Keep reading.)

## Three superpowers

**1. Three-operand add.** Normal `add rax, rbx` is two-operand: it destroys `rax` to hold the sum. `lea rax, [rbx + rcx]` adds two registers *into a third*, leaving both inputs untouched. C compilers reach for this constantly.

**2. Multiply by small constants for free.** The `scale` is 1/2/4/8, and you can add the base back in:

```asm
lea     rax, [rbx + rbx*2]      # rax = rbx * 3
lea     rax, [rbx + rbx*4]      # rax = rbx * 5
lea     rax, [rbx + rbx*8]      # rax = rbx * 9
```

So `*3`, `*5`, and `*9` are one `lea` each. Combined with a displacement, you can compute things like `5*x + 3` in one shot:

```asm
lea     rax, [rcx*4 + rcx + 3]  # rax = 4*rcx + rcx + 3 = 5*rcx + 3
```

That single line replaces an `imul` plus an `add`.

**3. Doesn't disturb FLAGS.** Most arithmetic instructions (`add`, `sub`, `inc`, `dec`...) update the FLAGS register, which affects later conditional jumps. `lea` updates *no flags*. That means you can squeeze `lea` between a `cmp` and a `jne` without the jump changing its mind. Compilers love this for scheduling.

**Gotcha.** `lea` is arithmetic, but the syntax forces you to write `[...]`. That makes it look like a memory access. Read `lea` aloud as "let `dst` equal..." and ignore the brackets.

## The example program

See [`03_lea_as_math.s`](03_lea_as_math.s). It computes `5*x + 3` for `x = 7` in one `lea`, and demonstrates a non-destructive 3-operand add.

```asm
.intel_syntax noprefix

        .section .text
        .globl  _start
_start:
        # Pretend x = 7.  Compute  5*x + 3  in ONE instruction.
        mov     rcx, 7                  # rcx = x
        lea     rax, [rcx*4 + rcx + 3]  # rax = 4*rcx + rcx + 3 = 5*rcx + 3 = 38

        # 3-operand add: rdi = rbx + rdx, inputs untouched.
        mov     rbx, 10
        mov     rdx, 20
        lea     rdi, [rbx + rdx]        # rdi = 30, rbx and rdx unchanged

        # Exit with rax (38) so we can verify via $?.
        mov     rdi, rax
        mov     rax, 60
        syscall
```

**In plain words.** With `x = 7`:

- `rcx*4` is 28.
- `+ rcx` is 35.
- `+ 3` is 38.

Exit code 38. Done in one instruction. No multiply, no second add.

## Build and run

```bash
as -o ex.o 03_lea_as_math.s
ld -o ex ex.o
./ex ; echo $?
# => 38
```

## Look at the bytes

```bash
objdump -d -M intel ex
```

You should see one `lea` with the scale-index-base encoding compressed into a few bytes — the address calculator's full power expressed in a single instruction.

## Try it

1. Compute `9*x` for `x = rdi` into `rax` in one instruction. (Answer: `lea rax, [rdi + rdi*8]`.)
2. Compute `x + y + 16` for `x = rbx`, `y = rcx` in one instruction. (Answer: `lea rax, [rbx + rcx + 16]`.)
3. Try to compute `7*x` in one `lea`. (Spoiler: you can't directly, because `scale` is 1/2/4/8. The closest one-liner is `lea rax, [rdi*8]` then `sub rax, rdi` — two instructions. Or `lea rax, [rdi + rdi*2]` to get `3x`, then `lea rax, [rdi + rax*2]` for `7x`. Compilers do exactly this.)
4. Use `gdb`, set a breakpoint at `_start`, single-step, and watch `rax` go from 0 to 38 after the `lea`.

## What's next

We've been quietly assuming "load 8 bytes" or "load 4 bytes" based on the registers involved. But sometimes the operand size isn't obvious — and you have to spell it out with `BYTE PTR`, `WORD PTR`, etc. That's the last addressing topic: [`04_size_suffixes.md`](04_size_suffixes.md).
