# Part 15 — Where Next

## The picture first: a map of further roads

Imagine you've just finished walking through a small town. You learned the streets, the shops, the names of the people who run them. You can find your way around without a map.

Now you're standing at the edge of town, looking out at a wide-open landscape with roads heading in every direction. Each road leads somewhere worth going — a mountain pass to high-performance code, a forest of operating-system internals, a valley of compilers, a coast of security research. You can't walk them all at once. But you should know they're there, so you can pick one when you're ready.

That's what this chapter is. A road map of where to go from here.

## What you have in your pack already

Take a moment to appreciate what you packed during the walk through town:

- Registers and their widths (`rax`/`eax`/`ax`/`al`).
- The `mov` family and operand sizes.
- Arithmetic and the FLAGS register (the CPU's tiny scratchpad of yes/no answers about the last calculation).
- Bitwise ops, shifts, idioms.
- The effective-address formula and `lea`-as-math.
- The stack and frame pointers.
- `cmp`/`test` + `jcc` for control flow.
- Loops in their three classic shapes.
- The System V calling convention (the agreed-upon paperwork for function calls).
- C interop (how asm and C call each other politely).
- String instructions and `rep` (the tireless robot).
- Linux syscalls (asking the building manager for help).
- One complete tiny program tying it together.

That is genuinely most of what you need to **read** x86_64 disassembly, debug a crash from a core dump, or write small bits of asm by hand. From here, branches into specialties.

## 1. Floating-point and SIMD (`xmm`, `ymm`, `zmm`)

So far we've been working with integers — whole numbers in `rax` through `r15`. Real-world code also has to handle fractions, like `3.14`, and that needs a different toolkit.

**Floating-point** ("float" for short) is the computer's way of storing fractional numbers. It uses a clever encoding where part of the bits store the digits and part of the bits store where the decimal point goes — like scientific notation. There's a whole separate set of registers dedicated to floats.

**SIMD** stands for "**S**ingle **I**nstruction, **M**ultiple **D**ata." Picture one instruction that adds *four pairs of numbers at the same time* instead of one. That's SIMD. You pack several numbers into a single wide register, and one instruction operates on all of them in parallel. It is how modern code moves photos, sounds, and 3D graphics around fast.

The wider registers live in a separate cabinet from `rax`–`r15`:

| Width  | Names               | What lives there                              |
| ------ | ------------------- | --------------------------------------------- |
| 128 b  | `xmm0..xmm15`       | scalar `float`/`double`, SSE vectors          |
| 256 b  | `ymm0..ymm15`       | AVX vectors (8 floats or 4 doubles)           |
| 512 b  | `zmm0..zmm31`       | AVX-512 vectors (16 floats or 8 doubles)      |

("Scalar" means "one number at a time." "Vector" means "several numbers packed side by side in one wide register.")

Scalar arithmetic — one number at a time, like the integer code you already know:

```asm
movsd   xmm0, [rdi]             # load 8-byte double
addsd   xmm0, xmm1              # xmm0 += xmm1
mulsd   xmm0, xmm2
```

What this actually does, in plain words: load an 8-byte fractional number ("double") from memory into the `xmm0` register, then add another to it, then multiply. The trailing `sd` stands for "**s**calar **d**ouble" — one double at a time.

Vector ("packed") arithmetic — several numbers in parallel:

```asm
movupd  xmm0, [rdi]             # load 2 doubles
addpd   xmm0, [rsi]             # add 2 doubles in parallel
movupd  [rdi], xmm0
```

What this actually does, in plain words: load *two* doubles side by side into the 128-bit `xmm0`. Add *two* other doubles to them — both additions happen in a single instruction. Store the two results back. The `pd` suffix means "**p**acked **d**ouble."

The SysV ABI passes the first 8 float/double args in `xmm0..xmm7`, returns in `xmm0`. Variadic functions (functions that take a variable number of arguments, like `printf`) use `al` to record how many `xmm` registers were used — this is why we did `xor eax, eax` before calling `printf` in earlier chapters. We were telling it "zero float arguments this time."

Read: the Intel "Intrinsics Guide" website is searchable by mnemonic and includes pseudocode for every instruction.

## 2. Optimization

**Optimization** is the craft of making programs faster (or smaller, or both) without changing what they do. Once you can read disassembly, optimization stops being magic — you can see what the compiler did and why.

Start here:

- Compile with `-O2 -S -masm=intel -fno-asynchronous-unwind-tables` and read your own code. The first time you see your hot loop reduced to four instructions, you'll smile. (A "hot loop" is the tight inner loop where your program spends most of its time.)
- Agner Fog's *Optimization Manuals* (free PDFs) are the canonical reference for x86 microarchitecture — cache (the CPU's small fast scratch memory), pipeline (the CPU's assembly-line way of overlapping instructions), branch prediction (the CPU's guess about which way `if` statements will go), instruction latencies.
- *Computer Architecture: A Quantitative Approach* (Hennessy & Patterson) for the theory.
- `perf stat -d ./prog` and `perf record` / `perf report` to find out where your cycles actually go. Speculation without measurement is fan-fiction.

## 3. Debugging tools

Tools for figuring out what a misbehaving program is actually doing:

- **`gdb`** with `layout asm`, `layout regs`, `display/i $pc`, `tbreak`, conditional breakpoints, `record full` for reverse execution. Learn `gdb -tui` and you have a free IDE.
- **`objdump -d -M intel -S`** to disassemble with source interleaved (when symbols are present). "Disassemble" means take the finished binary and turn it back into human-readable asm.
- **`nm`**, **`readelf -a`**, **`strings`** for poking at binaries.
- **`strace`** and **`ltrace`** to see syscalls / library calls.
- **`perf annotate`** to see hot disassembly inline.
- **`rr`** for record-and-replay reverse debugging — life-changing for hard bugs. You record the run once, then step *backwards* through it as many times as you want.

## 4. Operating systems and freestanding

A natural next step from "I can write asm" is "I can write an operating system." It is genuinely possible — and you have most of the prerequisites already. Start small:

- Write a bootloader that says hello in 16-bit real mode (yes, your CPU still boots in 16-bit mode in 2026, for backwards compatibility with the 1970s).
- Move to 32-bit protected mode, then to 64-bit long mode.
- Set up paging (the trick that gives each program its own pretend address space), a GDT and an IDT (tables the CPU reads to know how to handle interrupts and protection levels), a tiny kernel that handles a keyboard interrupt.
- *Operating Systems: Three Easy Pieces* (free online) for the concepts.
- The *OSDev wiki* for the painful x86 boot details.

## 5. Other architectures

x86 is a fascinating fossil — its design dates back to the 1970s and it has been growing barnacles ever since. But **ARM64 (also called AArch64)** runs your phone, your laptop (if it's Apple Silicon), and most cloud instances now. Once you know x86_64, AArch64 is easy:

- Fixed 4-byte instruction width, simple decoding. (Every instruction is exactly the same size, unlike x86's wildly varying ones.)
- 31 general-purpose registers (`x0..x30`), no register sub-naming chaos — though `w0` is the 32-bit view of `x0`.
- Load/store architecture: arithmetic instructions only work on registers. To touch memory you have to `ldr` (load) first or `str` (store) afterward. No `add rax, [mem]` shortcut.
- Cleaner addressing modes.

After x86, AArch64 feels almost like a high-level language.

## 6. Security

Once you understand the stack and `ret`, a lot of computer security clicks into place:

- **Stack overflows, ROP, JOP** — return-oriented and jump-oriented programming. Attacks that hijack the `ret` mechanism by overwriting return addresses on the stack.
- *Hacking: The Art of Exploitation* (Erickson) — old but excellent.
- CTF challenges on pwn.college, HackTheBox, picoCTF; they have asm and binary-exploitation tracks. ("CTF" = Capture The Flag, a kind of security puzzle competition.)

## 7. Compilers

A **compiler** is a program that translates one language into another — usually a friendly language (C, Rust) into a less friendly one (asm, machine code). You're in the `compiler/` directory next to `acwj/` ("A Compiler Writing Journey," a tutorial series). Going through ACWJ with asm in your bones is a different experience — you understand *why* the code generator emits what it emits. Then:

- *Crafting Interpreters* (Nystrom) — free online, builds an interpreter and a bytecode VM.
- *Engineering a Compiler* (Cooper & Torczon) for the deeper theory.
- LLVM tutorials when you want a real backend.

## A closing thought

Assembly used to be how you got performance. Now it's how you get **understanding**. Compilers are usually smarter than you about register allocation, instruction scheduling, and constant folding. They are not smarter than you about *intent* — which is why reading asm is a superpower (you can verify the compiler did what you meant) but writing it by hand is rarely the move.

Build the mental model, then carry it back up through the abstraction stack. C will feel like asm with manners. C++ will feel like C with paperwork. Rust will feel like C++ that respects your stack. Python will feel like a polite suggestion to the CPU. None of them will ever again feel like magic.

Good luck.

---

← Back to [the journey index](../README.md).
