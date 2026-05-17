# 02 — RIP-Relative Addressing

## A story: the moving warehouse

**In plain words:** modern Linux deliberately loads your program into a *different* warehouse address every time it runs. If your code says "shelf 4198400," that absolute number is wrong as soon as the program moves. So x86_64 has a smarter way to point at things: say "the shelf 32 steps after this instruction." That always works, no matter where the warehouse ended up.

**The analogy.** Imagine you're writing a treasure map. You could write "the chest is at GPS coordinates 47.6, -122.3." That works only if the island is exactly where you expected. Or you could write "from where you're standing, the chest is 30 steps north." That works on *any* island, as long as you start from the marked spot.

`rip` is "where you're standing." `[rip + label]` is "30 steps north of here, please."

**The technical layer.** `rip` is the **instruction pointer** — a special register that always holds the address of the *next* instruction the CPU will execute. You can't load it with `mov` like a normal register, but you can use it inside `[...]` as the `base`. When you write `[rip + msg]`, the assembler and linker work together to compute a fixed offset such that `rip + that_offset` lands exactly on `msg`, *no matter where the program is loaded*.

## Why we always use this in 64-bit code

**In plain words:** modern operating systems randomize where programs load, for security. The old style `mov rax, [msg]` bakes a fixed address into the instruction and breaks. `[rip + msg]` is relative and always correct.

**The technical layer.** The security feature is called **ASLR** — Address Space Layout Randomization. Every run, the kernel picks different base addresses for your `.text`, `.data`, stack, and heap, so an attacker can't predict where to jump to. To be ASLR-friendly, your code must avoid absolute addresses. RIP-relative addressing achieves that: the *offset* between an instruction and a nearby data label is fixed at link time, even though the absolute addresses aren't fixed until load time.

This is what `gcc -fPIE` (the default these days) emits everywhere. **Use `[rip + label]` always in 64-bit code.**

**Gotcha.** You'll see old tutorials write `mov rsi, msg` or `lea rsi, [msg]`. Those still assemble, but on modern Linux toolchains they often refuse to link, or they only work for non-PIE executables. The safe, portable, modern form is `lea rsi, [rip + msg]`.

**Check yourself.** Why does `lea rsi, [rip + msg]` work, but `mov rsi, rip` does not? (Answer: `rip` isn't a general-purpose register. You can't read or write it directly. You can only use it implicitly inside `[...]`, where the assembler encodes a special "RIP-relative" addressing mode.)

## The example program

See [`02_rip_relative.s`](02_rip_relative.s). It does two RIP-relative things:

1. Compute the address of a string with `lea rsi, [rip + msg]` and `write` it.
2. Load an 8-byte value from a labeled shelf with `mov rdi, [rip + counter]` and exit with it as the status.

```asm
.intel_syntax noprefix

        .section .data
msg:    .ascii  "RIP-relative works!\n"
        .equ    msglen, . - msg

counter:
        .quad   42                      # an 8-byte number named 'counter'

        .section .text
        .globl  _start
_start:
        mov     rax, 1                  # syscall: write
        mov     rdi, 1                  # fd: stdout
        lea     rsi, [rip + msg]        # rsi = address of msg (RIP-relative)
        mov     rdx, msglen
        syscall

        mov     rdi, [rip + counter]    # rdi = 42
        mov     rax, 60
        syscall
```

**In plain words:**

- `lea rsi, [rip + msg]` computes the address of `msg` and puts it in `rsi`. Notice: we get an *address*, we don't fetch from it. That's the job of `lea`.
- `mov rdi, [rip + counter]` computes the address of `counter` AND fetches the 8 bytes at that shelf into `rdi`. That's the job of `mov`.

The difference between the two is the difference between "where is it?" and "what's there?" — and it's the difference between `lea` and `mov` with the same `[...]` operand.

## Build and run

```bash
as -o ex.o 02_rip_relative.s
ld -o ex ex.o
./ex ; echo $?
# RIP-relative works!
# 42
```

## Look at the bytes

```bash
objdump -d -M intel ex
```

You'll see something like:

```
401000 <_start>:
  401000:  b8 01 00 00 00       mov    eax,0x1
  401005:  bf 01 00 00 00       mov    edi,0x1
  40100a:  48 8d 35 ef 1f 00 00 lea    rsi,[rip+0x1fef]
```

**In plain words.** Look at that last line. The encoded instruction is `lea rsi, [rip + 0x1fef]` — the assembler has *baked in the offset* `0x1fef` from this instruction to `msg`. At run time, the CPU adds that offset to whatever `rip` happens to be. If the program loaded somewhere else, the *base* changes but the *offset* doesn't, and the math still lands on `msg`.

**Gotcha.** That offset is signed and limited to ±2 GiB. For tiny programs like ours this never matters. For huge programs or large memory models, you sometimes need other addressing strategies — but you'll know when, because the linker will complain.

## Try it

1. Comment out the `lea` and replace it with `mov rsi, OFFSET msg` (or `mov rsi, msg`, depending on your binutils). Try to link. On a modern PIE-default toolchain, the link may fail or emit a warning. That's ASLR pushing back.
2. Run `./ex` a few times under `cat /proc/self/maps` or `setarch -R ./ex` to see how loading addresses change.
3. Use `gdb` to break at `_start`, run `info registers rip`, run `stepi` once, then check `rsi` — verify it's the address of `msg`, and that `x/s $rsi` prints the string.

## What's next

We've been using `lea` casually — to grab addresses. But `lea` has a secret life as a general-purpose math instruction. Next: [`03_lea_as_math.md`](03_lea_as_math.md).
