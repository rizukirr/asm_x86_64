# Part 15 — Where Next

## The picture first: a map of further roads

Imagine you've just finished walking through a small town. You learned the streets, the shops, the names of the people who run them. You can find your way around without a map.

Now you're standing at the edge of town, looking out at a wide-open landscape with roads heading in every direction. Each road leads somewhere worth going — a mountain pass to high-performance code, a forest of operating-system internals, a valley of compilers, a coast of security research. You can't walk them all at once. But you should know they're there, so you can pick one when you're ready.

That's what this final chapter is: a road map, plus three short, hands-on tastes of the most useful roads.

## What you have in your pack already

Take a moment to appreciate what you packed during the walk through town:

- Registers and their widths (`rax`/`eax`/`ax`/`al`).
- The `mov` family and operand sizes.
- Arithmetic and the FLAGS register.
- Bitwise ops, shifts, idioms.
- The effective-address formula and `lea`-as-math.
- The stack and frame pointers.
- `cmp`/`test` + `jcc` for control flow.
- Loops in their three classic shapes.
- The System V calling convention.
- C interop.
- String instructions and `rep`.
- Linux syscalls.
- One complete tiny program tying it together.

That is genuinely most of what you need to **read** x86_64 disassembly, debug a crash from a core dump, or write small bits of asm by hand. From here, branches into specialties — and the three topics below give you a working taste of the most common ones.

## Topics in this chapter

Each topic has a short Feynman-style write-up and a tiny `.s` program you can build with `as` and `ld`. The programs report their result through the **exit status**, so `echo $?` after running tells you what the CPU computed.

1. [Topic 01 — Scalar Floating Point (`xmm` + `addsd`)](01_scalar_fp.md) — meet the second workshop, the `xmm` registers. Adds two doubles and exits with the integer result. Source: [`01_scalar_fp.s`](01_scalar_fp.s).
2. [Topic 02 — SIMD: Four Adds in One Instruction (`addps`)](02_simd_addps.md) — pack four floats into one register and add them all in a single instruction. Source: [`02_simd_addps.s`](02_simd_addps.s).
3. [Topic 03 — Reading the Machine: `lea`-as-math, `objdump`, `gdb`](03_lea_and_disasm.md) — the X-ray tools. One `lea` instruction computes `3*x + 5`, and we look at the bytes and step through it in gdb. Source: [`03_lea_and_disasm.s`](03_lea_and_disasm.s).

## Other roads — pointed at, but not walked

Three roads we don't have room to walk in this chapter, but you now have enough context to start them on your own.

- **AVX and AVX-512.** The 256-bit `ymm` registers and 512-bit `zmm` registers extend the SIMD idea from Topic 02. Same mental model — wider lanes, three-operand instructions (`vaddps ymm0, ymm1, ymm2`), and in AVX-512, per-lane mask registers `k0..k7`.
- **Operating systems and freestanding.** Bootloaders, 16-bit real mode, 32-bit protected mode, paging, the GDT/IDT. *Operating Systems: Three Easy Pieces* (free online) for the concepts; the OSDev wiki for the painful x86 boot details.
- **Other architectures.** ARM64 / AArch64 — what your phone and most Apple Silicon laptops run. Fixed 4-byte instructions, 31 general-purpose registers, load/store architecture. After x86, AArch64 feels almost like a high-level language.
- **Security.** Stack overflows, ROP, JOP — attacks that hijack the `ret` mechanism by overwriting return addresses. *Hacking: The Art of Exploitation* (Erickson) is the classic. Practice on pwn.college, picoCTF, HackTheBox.
- **Compilers.** You're already inside the `compiler/` directory next to `acwj/`. Walking through *A Compiler Writing Journey* with asm in your bones is a different experience — you understand *why* the code generator emits what it emits.

## Further reading — the canonical references

These are the four resources that practising x86_64 programmers actually keep open in a browser tab:

- **Intel Software Developer's Manual (SDM).** The official, authoritative description of every x86 / x86_64 instruction, every register, every flag. Free PDF download from Intel. Volume 2 (instruction set reference) is the one you'll consult most. Search: *Intel 64 and IA-32 Architectures Software Developer's Manual*.
- **AMD64 Architecture Programmer's Manual.** AMD's parallel document. Mostly equivalent to Intel's, occasionally clearer.
- **Agner Fog's Optimization Manuals.** Free PDFs covering x86 microarchitecture, instruction latencies and throughputs, cache behaviour, branch prediction. The canonical references for tuning. <https://www.agner.org/optimize/>
- **Felix Cloutier's x86/x64 Reference.** A beautifully hyperlinked HTML render of the Intel SDM instruction reference. Faster to grep than the PDFs. <https://www.felixcloutier.com/x86/>
- **Intel Intrinsics Guide.** Searchable by mnemonic, includes pseudocode for every SIMD instruction (handy after Topic 02). <https://www.intel.com/content/www/us/en/docs/intrinsics-guide/index.html>

## A closing thought

Assembly used to be how you got performance. Now it's how you get **understanding**. Compilers are usually smarter than you about register allocation, instruction scheduling, and constant folding. They are not smarter than you about *intent* — which is why reading asm is a superpower (you can verify the compiler did what you meant) but writing it by hand is rarely the move.

Build the mental model, then carry it back up through the abstraction stack. C will feel like asm with manners. C++ will feel like C with paperwork. Rust will feel like C++ that respects your stack. Python will feel like a polite suggestion to the CPU. None of them will ever again feel like magic.

Congratulations — you finished the walk through town.
