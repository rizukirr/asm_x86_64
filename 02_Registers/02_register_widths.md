# 02 — One cup, four rulers

## A story: a ruler with four scales

**In plain words:** `rax`, `eax`, `ax`, `ah`, and `al` are not five separate registers. They are five different *views* of the same 64-bit cup.

**The analogy.** Imagine a single wooden ruler. Along one edge it's marked in millimeters. Along another edge, centimeters. Another, inches. Another, feet. Four scales, one ruler. If you sand off a millimeter mark, you've changed the ruler — and *every* scale now reads slightly differently for that spot.

The 64-bit cup `rax` is the ruler. `eax`, `ax`, `ah`, `al` are just different scales on the same physical thing.

**The technical layer.**

```
 63                              31              15      7       0
 +-------------------------------+---------------+-------+-------+
 |                       rax (64 bits)                           |
 +-------------------------------+---------------+-------+-------+
                                 |          eax (32 bits)        |
                                 +---------------+-------+-------+
                                                 |   ax (16)     |
                                                 +-------+-------+
                                                 |  ah   |  al   |
                                                 +-------+-------+
```

- `rax` is the whole 64-bit cup.
- `eax` is just the bottom 32 bits.
- `ax` is just the bottom 16 bits.
- `al` is just the bottom 8 bits — the very low byte.
- `ah` is the *second*-lowest byte (bits 8–15).

Every other GPR has the same layered naming. `rbx eax bx bl bh`, `rcx ecx cx cl ch`, and so on. The `r8`–`r15` registers use a slightly different convention: `r8 r8d r8w r8b` for 64/32/16/8 bits, and they have **no** "high byte" form.

The full width table:

| 64-bit | 32-bit | 16-bit | 8-bit low | 8-bit high |
| ------ | ------ | ------ | --------- | ---------- |
| `rax`  | `eax`  | `ax`   | `al`      | `ah`       |
| `rbx`  | `ebx`  | `bx`   | `bl`      | `bh`       |
| `rcx`  | `ecx`  | `cx`   | `cl`      | `ch`       |
| `rdx`  | `edx`  | `dx`   | `dl`      | `dh`       |
| `rsi`  | `esi`  | `si`   | `sil`     | —          |
| `rdi`  | `edi`  | `di`   | `dil`     | —          |
| `rbp`  | `ebp`  | `bp`   | `bpl`     | —          |
| `rsp`  | `esp`  | `sp`   | `spl`     | —          |
| `r8`   | `r8d`  | `r8w`  | `r8b`     | —          |
| ...    | ...    | ...    | ...       | —          |

## The big surprise

There are four rules for what happens to the *other* bits of the cup when you write to a narrow view:

1. `mov al,  X` — only the bottom 8 bits change. Top 56 bits untouched.
2. `mov ax,  X` — only the bottom 16 bits change. Top 48 bits untouched.
3. `mov eax, X` — bottom 32 bits get `X`, **and the top 32 bits are wiped to zero**.
4. `mov rax, X` — all 64 bits get `X`.

That third rule is the 64-bit-only quirk that catches everyone. Worth memorizing:

> **Writing to a 32-bit register zero-extends into the full 64-bit register.**

("Zero-extends" means: fill the upper bits with zeros.) This is why compilers love `xor eax, eax` to zero out `rax` — it's two bytes long and zeroes all 64 bits in one shot.

**Gotcha.** Writes to 16-bit (`ax`) or 8-bit (`al`, `ah`) views do *not* clear the upper bits. Only 32-bit writes get the free zero-extend. Mixing this up is a top-five beginner bug.

## A paper-only exercise

Predict what each line leaves in `rax`, starting from `rax = 0x1122334455667788`.

```asm
mov     al,  0xAA
mov     ax,  0xBBCC
mov     eax, 0xDDEEFF00
```

| After                     | `rax`                |
| ------------------------- | -------------------- |
| `mov al,  0xAA`           | `0x11223344556677AA` |
| `mov ax,  0xBBCC`         | `0x112233445566BBCC` |
| `mov eax, 0xDDEEFF00`     | `0x00000000DDEEFF00` |

Walkthrough:
- `mov al, 0xAA` — only the bottom byte changes. `88` becomes `AA`; everything else stays.
- `mov ax, 0xBBCC` — only the bottom 2 bytes change. `77AA` becomes `BBCC`.
- `mov eax, 0xDDEEFF00` — **wipes the top 32 bits to zero**. So `11223344` becomes `00000000`. This is the rule that catches everyone.

If that last one surprised you, re-read the rule above.

## The code

See [`02_register_widths.s`](02_register_widths.s):

```asm
.intel_syntax noprefix

        .section .data
msg:    .ascii  "one cup, four rulers\n"
        .equ    msglen, . - msg

        .section .text
        .globl  _start
_start:
        mov     rax, 0x1122334455667788
        mov     al,  0xAA               # 0x11223344556677AA
        mov     ax,  0xBBCC             # 0x112233445566BBCC
        mov     eax, 0xDDEEFF00         # 0x00000000DDEEFF00  <-- top wiped

        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + msg]
        mov     rdx, msglen
        syscall

        mov     rax, 60
        xor     rdi, rdi
        syscall
```

**In plain words.** Stuff a recognizable test pattern into `rax`. Then poke the low byte, the low word, and the low dword in turn. The visible output is just a banner — the real lesson is what happens inside `rax`, which you can only see with `gdb`.

## Build and run

```bash
as -o 02_register_widths.o 02_register_widths.s
ld -o 02_register_widths 02_register_widths.o
./02_register_widths
# => one cup, four rulers
```

## Watch it with gdb (this is the lesson)

```bash
gdb ./02_register_widths
(gdb) layout regs
(gdb) starti
(gdb) si
(gdb) si
(gdb) si
(gdb) si
```

After each `si`, look at `rax` in the register pane:

1. After `mov rax, 0x1122334455667788` — `rax = 0x1122334455667788`.
2. After `mov al, 0xAA` — `rax = 0x11223344556677AA`. Only the last two hex digits changed.
3. After `mov ax, 0xBBCC` — `rax = 0x112233445566BBCC`. Last four hex digits changed.
4. After `mov eax, 0xDDEEFF00` — `rax = 0x00000000DDEEFF00`. **The top half got wiped.** This is the zero-extension rule in action.

You are now the CPU, watching the rule fire.

## Check yourself

If `rbx = 0xFFFFFFFFFFFFFFFF` and you execute `mov ebx, 0`, what is `rbx`? (Answer: `0x0000000000000000`. The 32-bit write zero-extends. If you'd written `mov bx, 0` instead, `rbx` would be `0xFFFFFFFF00000000` — the top 48 bits untouched.)

## What's next

You've met the 16 GPRs and seen how to view each at four widths. Two more cups deserve a special mention: `rip`, which the CPU touches for you, and `rflags`, which the CPU touches *because* of what you do. See [`03_rip_and_rflags.md`](03_rip_and_rflags.md).
