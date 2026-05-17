# 03.2 — `movzx` and `movsx`: widening with intent

## A story: writing a small number into a big box

**In plain words:** you have a tiny number in a small cup and you want to put it into a much larger cup. There's a tiny number's worth of bits, but the big cup has lots more room. What do you put in the empty space?

**The analogy.** Imagine you're writing the score `7` on a scoresheet that has eight digit boxes: `[_][_][_][_][_][_][_][7]`. You can fill the empty boxes with **zeros** — `00000007` — and the meaning of the number is unchanged.

Now imagine the score is `-3`. On a one-box "signed" sheet, that's stored as a special bit pattern (`11111101` in binary, called **two's complement**). If you copy *that pattern* into an eight-box sheet and fill the empty boxes with zeros, you'd get a huge positive number — `253` — not `-3` at all. To preserve the meaning, you have to fill the new boxes with copies of the **top bit** of the original: all 1s. Then `-3` stays `-3`.

That's the choice every widening copy has to make. **Zero-extend** = pad with zeros (good for unsigned values). **Sign-extend** = pad with copies of the top bit (good for signed values, preserves negative numbers).

## The instructions

**In plain words:** x86_64 gives you two explicit instructions because the CPU can't read your mind. You tell it which interpretation you want.

```asm
movzx   rax, bl         # zero-extend  bl  (8-bit)  -> rax
movzx   rax, bx         # zero-extend  bx  (16-bit) -> rax
movsx   rax, bl         # sign-extend  bl  (8-bit)  -> rax
movsx   rax, bx         # sign-extend  bx  (16-bit) -> rax
movsxd  rax, ebx        # sign-extend  ebx (32-bit) -> rax
```

**The technical layer.**

- `movzx` = **mov with zero-extend.** Source can be 8 or 16 bits.
- `movsx` = **mov with sign-extend.** Source can be 8 or 16 bits.
- `movsxd` = **mov with sign-extend, doubleword.** The 32-to-64 variant. The trailing `d` means "doubleword source" (32 bits).

**Gotcha — the missing instruction.** There is no `movzxd`. You don't need one, because of a feature already covered in Part 02: **writing to a 32-bit register automatically zero-extends to 64 bits**. So `mov eax, ebx` already does what `movzxd rax, ebx` would do. You get the zero-extend for free. The CPU designers noticed this and saved an opcode.

## A side-by-side table

The cleanest way to feel the difference is to watch the same byte get widened both ways.

| Source byte `bl` | `movzx rax, bl` (zero-extend) | `movsx rax, bl` (sign-extend)    |
| ---------------- | ----------------------------- | -------------------------------- |
| `0x7F`           | `0x000000000000007F`          | `0x000000000000007F`             |
| `0x80`           | `0x0000000000000080`          | `0xFFFFFFFFFFFFFF80`             |
| `0xFF`           | `0x00000000000000FF`          | `0xFFFFFFFFFFFFFFFF`             |

**In plain words, walking the rows:**

- `0x7F` is `01111111` in binary. The top bit is 0, so "fill with the top bit" and "fill with zeros" produce the same thing. Same answer either way: `127`.
- `0x80` is `10000000`. The top bit is 1. Zero-extend gives `128` (unsigned interpretation). Sign-extend fills the high bits with 1s, giving the 64-bit two's-complement of `-128`.
- `0xFF` is `11111111`. Zero-extend gives `255`. Sign-extend gives `-1` (in 64-bit two's complement: all 1s).

**The rule.** Sign-extension **copies the top bit of the source** to fill all the new high bits. Use it when your value is signed and might be negative. Use `movzx` when your value is unsigned.

## The demo

See [`02_extension.s`](02_extension.s):

```asm
.intel_syntax noprefix

        .section .data
msg:    .ascii  "extension demo done\n"
        .equ    msglen, . - msg

        .section .text
        .globl  _start
_start:
        mov     rbx, 0
        mov     bl,  0xFF           # bl = 0xFF (-1 signed, 255 unsigned)

        movzx   rcx, bl             # rcx = 0x00000000000000FF
        movsx   rdx, bl             # rdx = 0xFFFFFFFFFFFFFFFF

        movsx   r8, bx              # rbx low 16 bits are 0x00FF
                                    # top bit of bx = 0, so r8 = 0x000000FF

        mov     eax, 0xFFFFFFFF     # eax = 0xFFFFFFFF (-1 as 32-bit signed)
        movsxd  r9, eax             # r9 = 0xFFFFFFFFFFFFFFFF

        mov     r10d, 0x7FFFFFFF    # writing r10d zero-extends r10
                                    # r10 = 0x000000007FFFFFFF (free movzxd)

        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + msg]
        mov     rdx, msglen
        syscall

        mov     rax, 60
        xor     rdi, rdi
        syscall
```

**In plain words, step by step:**

1. Zero out `rbx` so we know its upper bytes are clean. Then write `0xFF` into the low byte.
2. `movzx rcx, bl` reads byte `bl` and stuffs it into `rcx` with zeros padding the upper 56 bits.
3. `movsx rdx, bl` reads the same byte but copies its top bit (which is `1`) into the upper bits. Result: all 1s.
4. `movsx r8, bx` widens the 16-bit `bx`. After the earlier setup, `bx` is `0x00FF`. Top bit is 0, so the sign-extend pads with zeros — same as zero-extend here.
5. `mov eax, 0xFFFFFFFF` puts `-1` (32-bit signed reading) into the low 32 bits of `rax`. Note that this `mov` automatically zero-extends, so `rax` is now `0x00000000FFFFFFFF`. (Bit pattern, not meaning.)
6. `movsxd r9, eax` reads `eax` as a signed 32-bit number, sees the top bit is 1, and pads with 1s. `r9 = 0xFFFFFFFFFFFFFFFF`, the 64-bit representation of `-1`.
7. `mov r10d, 0x7FFFFFFF` shows the "free zero-extend" feature: writing the 32-bit half wipes the upper 32 bits to zero, so no `movzxd` is needed.

## Build, run, inspect

```bash
as -o 02_extension.o 02_extension.s
ld -o 02_extension 02_extension.o
./02_extension
# => extension demo done
```

The output line is just so you know it ran. The interesting stuff is in the registers.

```bash
gdb ./02_extension
(gdb) starti
(gdb) layout regs        # optional: visual register pane
(gdb) si                 # step
(gdb) info registers rcx rdx r8 r9 r10
```

Step through and watch `rcx`, `rdx`, `r8`, `r9`, `r10` get filled by each extension. Compare what you see to the table above.

## Check yourself

1. Without running the code, fill in this table:

   | After…                  | `rcx` | `rdx` |
   | ----------------------- | ----- | ----- |
   | `mov bl, 0x42`          | `?`   | `?`   |
   | `movzx rcx, bl`         | `?`   | `?`   |
   | `movsx rdx, bl`         | `?`   | `?`   |

   (Hint: `0x42`'s top bit is 0, so both extensions produce the same value.)

2. Replace `movzx rcx, bl` with the broken-looking `mov rcx, bl`. Try to build. The assembler errors with **operand size mismatch**. `mov` requires both operands to be the same size; widening needs the explicit `movzx`/`movsx`.

3. Why does this code use `movsxd r9, eax` instead of `movsx r9, eax`? (Answer: `movsx` only accepts 8-bit or 16-bit sources. The 32-to-64 variant has its own mnemonic, `movsxd`, because of how it's encoded in machine code. Functionally it's the same idea.)

## Gotcha — printing negative numbers from C

This is where students often discover sign-extension the hard way. If you write a C function that takes an `int` (32 bits) and the caller passes `-1`, the compiler emits `movsxd` (or equivalent) so the negative value survives into the 64-bit register the function reads. Forget that step and `-1` becomes `0x00000000FFFFFFFF` — which is a huge positive number, not `-1`. Real compilers always pick the right extension automatically. When you write assembly by hand, **you** are the compiler.

## What's next

We've moved values and widened them. There's one more flavor of "move" that doesn't actually fetch anything: [03.3 — `lea`](03_lea_address.md). It computes addresses (and, by clever accident, performs free arithmetic).
