# Topic 03 — Reading the Machine: `lea`-as-math, `objdump`, `gdb`

## A story: the X-ray machine

**In plain words:** assembly is the easiest language to *debug* once you know how to look at it, because the compiler stops being a black box. With two free tools — `objdump` and `gdb` — you can see the exact instructions the CPU sees and watch the registers change one step at a time.

**The analogy.** Up until now you've been *writing* recipes. The disassembler and the debugger are X-ray machines: they let you see the recipe inside any built program, including ones you didn't write. A compiler's output, a stranger's binary, your own buggy code — they all become readable.

**The technical layer.** Three tools cover most of what you need:

- **`objdump -d -M intel <prog>`** — disassemble: turn bytes back into instructions. Static view, no running required.
- **`gdb <prog>`** — interactive debugger: step instructions, inspect registers and memory while the program is paused.
- **`strace ./<prog>`** — print every syscall the program makes. Great for the "what does this program actually *do*?" question.

This topic gives you a tiny program to practise the X-ray on, and uses it to introduce one beautiful instruction you've already met in passing: `lea` as a pocket-calculator.

## What we will build

A program that computes `y = 3*x + 5` for `x = 7` (so `y = 26`) using a **single** instruction. The whole point: this is what the compiler emits when it sees `int y = 3*x + 5;` at `-O2`. Once you can read it, the compiler is your colleague, not your competitor.

See [`03_lea_and_disasm.s`](03_lea_and_disasm.s):

```asm
.intel_syntax noprefix

        .section .text
        .globl  _start
_start:
        mov     edi, 7                  # x = 7
        # Compute y = 3*x + 5 using a single LEA.
        # [rdi + rdi*2 + 5]  ==  x + 2*x + 5  ==  3*x + 5  ==  26.
        lea     edi, [rdi + rdi*2 + 5]  # edi = 26

        mov     rax, 60                 # syscall: exit
        syscall
```

## Build and run

```bash
as -o 03_lea_and_disasm.o 03_lea_and_disasm.s
ld -o 03_lea_and_disasm 03_lea_and_disasm.o
./03_lea_and_disasm
echo $?
# => 26
```

## `lea` as a one-instruction calculator

**In plain words:** `lea` was *invented* to compute memory addresses, but the CPU doesn't actually check whether the result is a real address. It just does the arithmetic. So we use it as a free arithmetic instruction.

**The technical layer.** The general addressing-mode formula on x86_64 is:

```
[ base + index*scale + displacement ]
```

where `scale` is one of `1, 2, 4, 8`. `lea` evaluates that whole expression and stores the *result*, not what's at that address. So with `base = rdi`, `index = rdi`, `scale = 2`, `displacement = 5`, we get:

```
rdi + rdi*2 + 5  =  3*rdi + 5
```

…in **one instruction**, on **most pipelines in one cycle**, and crucially **without touching the `FLAGS` register** (so it doesn't disturb a pending `cmp` result). That's why compilers love `lea` for small integer math.

**Gotcha.** `scale` can only be `1`, `2`, `4`, or `8`. So `lea` gives you free multiplications by `2x+1`, `4x+1`, `8x+1`, `3x`, `5x`, `9x` — but not by `7x` directly. Compilers strength-reduce other constants out of `mul` into chains of `lea`+`shift`+`add` when they can.

## Disassemble with `objdump`

```bash
$ objdump -d -M intel 03_lea_and_disasm

03_lea_and_disasm:     file format elf64-x86-64

Disassembly of section .text:

0000000000401000 <_start>:
  401000:  bf 07 00 00 00          mov    edi, 0x7
  401005:  8d 7c 7f 05             lea    edi, [rdi + rdi*2 + 0x5]
  401009:  b8 3c 00 00 00          mov    eax, 0x3c
  40100e:  0f 05                   syscall
```

**Reading it:**

- Address column on the left, raw bytes in the middle, mnemonic on the right.
- `lea edi, [rdi + rdi*2 + 0x5]` is **four bytes**: `8d 7c 7f 05`. One instruction. The `05` at the end is the `+5` displacement, sitting right there in the encoding.
- `mov eax, 0x3c` — that's `0x3c = 60`, the `exit` syscall number. Notice the assembler downgraded our `mov rax, 60` to `mov eax, 60` (5 bytes instead of 7) using the same zero-extension trick from Part 01.
- `0f 05` is the `syscall` instruction. Two bytes. That's the whole "ask the kernel for help" mechanism.

**Useful flags for `objdump`:**

- `-d` — disassemble executable sections.
- `-M intel` — Intel syntax (matches this course).
- `-S` — interleave source lines (when symbols / debug info are present).
- `-j .text` — show only the `.text` section.
- `-l` — show file/line numbers (with `-g` builds).

## Walk it in `gdb`

```
$ gdb ./03_lea_and_disasm
(gdb) break _start
(gdb) run
(gdb) layout asm        # split window: code on top, prompt on bottom
(gdb) layout regs       # add a register view
(gdb) info registers rdi
rdi            0x0      0
(gdb) si                # step one instruction:  mov edi, 7
(gdb) info registers rdi
rdi            0x7      7
(gdb) si                # step:  lea edi, [rdi + rdi*2 + 5]
(gdb) info registers rdi
rdi            0x1a     26
(gdb) si                # step:  mov rax, 60
(gdb) si                # step:  syscall  -> process exits
[Inferior 1 (process …) exited with code 032]
```

(That trailing `032` is `26` in octal — `gdb`'s default base for exit codes. Don't be fooled.)

**The technical layer of each command:**

- `break _start` — set a breakpoint at the entry-point label.
- `run` — start the program; it pauses at the breakpoint.
- `layout asm` / `layout regs` — switch to the **TUI** (Text User Interface), a free split-pane view with the current instruction highlighted.
- `si` — "**s**tep **i**nstruction": run exactly one machine instruction and stop. (Compare `ni` for "**n**ext **i**nstruction", which steps *over* `call`s instead of into them.)
- `info registers` — dump all the integer registers. `info registers xmm0` dumps a float register with every reasonable interpretation.
- `x/16xb $rsp` — examine 16 bytes at `rsp`, formatted as hex bytes. The `x/FMT ADDR` mini-language is the universal "show me memory" command.

## A few other tools worth knowing

| Tool                     | Use it for                                     |
| ------------------------ | ---------------------------------------------- |
| `nm <prog>`              | list symbols (functions, globals) in a binary  |
| `readelf -a <prog>`      | look at every ELF header, section, segment     |
| `strings <prog>`         | print the printable text inside a binary       |
| `strace ./<prog>`        | log every syscall the program makes            |
| `ltrace ./<prog>`        | log every libc / dynamic-library call          |
| `perf stat -d ./<prog>`  | count cycles, instructions, cache misses       |
| `rr record ./<prog>`     | record a run for *reverse* debugging later     |

Each one is a one-line `man` page away from being your new best friend.

## Try it

1. **Run `objdump -d -M intel 03_lea_and_disasm`** on the binary and confirm the `lea` encoding ends in `05` (the `+5` displacement). Change the source to `+7` and rebuild — the byte becomes `07`.
2. **Replace `lea edi, [rdi + rdi*2 + 5]`** with two instructions (`add edi, edi` + `add edi, edi` + `add edi, 5`, etc.) and observe the difference in `objdump`: same answer, more bytes, more uops.
3. **Run `strace ./03_lea_and_disasm`.** You'll see exactly one syscall (`exit_group(26)`). The first three lines of `strace` output are the kernel loading the program — not syscalls *by* the program, but interactions *for* it.
4. **In gdb, set `$rdi = 100` manually** with `set $rdi = 100` *before* the `lea`, then `si`. The exit code becomes `(3*100 + 5) & 0xff = 49`. The CPU doesn't care that you cheated.

## What's next

Nothing — this is the last topic of the last chapter. Head back to the [chapter index](README.md) for the further-reading list and a closing thought.
