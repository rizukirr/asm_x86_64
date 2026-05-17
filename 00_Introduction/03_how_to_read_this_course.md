# 03 — How to read this course

## A story: a guided tour through a clockwork factory

**In plain words:** this course is not a reference manual. It's a guided walk. Each chapter opens a new door in the same factory and shows you one mechanism in detail before moving on. If you read in order and run every example, the picture fills in piece by piece.

**The analogy.** Imagine you're a new hire at a clockwork factory. On day one, nobody hands you the 900-page manual. Instead, a senior engineer walks you to one machine and says, "this lever moves that gear. Press it. Watch what happens." Then to the next machine. Then the next. By the end of the tour you can read the 900-page manual on your own, because every term in it now points at something you have actually touched.

That is the shape of this course. Each chapter teaches you one mechanism by writing and running a tiny program that uses it.

**The technical layer.** The whole course is fifteen chapters plus this introduction. They build strictly on each other — Part 04 assumes you read Part 03, and so on. Skipping forward is fine for browsing, but the explanations will reference earlier ideas without re-explaining them.

**Check yourself.** Could you treat this course as a reference and read chapters out of order? (You could, but you'd miss the "we explained this in Part N" callouts that compress later chapters. Linear is the intended path.)

## The Feynman 4-beat pattern

**In plain words:** every concept in this course is explained the same way — four short beats, in the same order. Once you notice the pattern, you can skim it for review and read it slowly when something is new.

The beats are:

1. **In plain words** — the one-sentence summary in everyday language. If you only read this beat, you still get the idea.
2. **The analogy** — a concrete physical picture (cups, shelves, forms, workers). Your brain remembers the picture; the picture is a handle for the technical detail.
3. **The technical layer** — the actual precise rules. Register names, byte counts, what the kernel does, what the manual says.
4. **Gotcha / Check yourself** — the trap people fall into, and a small self-check question with a stated answer.

**Gotcha.** Don't skip beats 1 and 2 thinking they're "just intro fluff." The plain-words and analogy beats are where most of your retention actually happens. The technical beat alone doesn't stick if you have no picture to hang it on.

## What's in scope (and what isn't)

This course deliberately narrows the world so explanations can stay concrete instead of constantly hedging with "well, on some systems...".

**In scope:**

- **OS: Linux only.** Every example uses Linux **syscalls** (the way a program asks the kernel for services — covered in detail in Part 01) and the System V AMD64 ABI ("ABI" = the agreed-upon rulebook for how programs call each other).
- **Architecture: x86_64 only.** 64-bit Intel/AMD CPUs. The same chips in most laptops and desktops.
- **Assembler: GNU `as` in Intel syntax.** Always with `.intel_syntax noprefix` at the top.
- **Mode: 64-bit user-space.** Normal programs that the OS runs for us.

**Out of scope:**

- **macOS and Windows.** The *instructions* and *registers* are identical on every OS — only the syscall numbers and the launch conventions differ. On Windows, run the course inside **WSL2** (Windows Subsystem for Linux) for the smoothest experience.
- **Other CPUs.** ARM64 (Apple Silicon, iPhones), RISC-V, and 32-bit x86 use different register names and byte encodings. The big picture transfers; the spelling does not.
- **16-bit real mode, 32-bit protected mode, ring 0 (kernel mode), paging, interrupts, the boot process.** All fascinating, all separate courses.
- **Floating point and SIMD.** The CPU has a parallel universe of registers (`xmm`, `ymm`, `zmm`) for decimal numbers and parallel math. We stay in whole-number land. Pointers for that journey are in Part 15.
- **Security topics.** Buffer overflows, stack canaries, ASLR — visible from here but not pursued.
- **Performance tuning.** Mentioned in passing; not the focus.

**Gotcha.** If a stray Stack Overflow answer assumes Windows calling conventions (registers `rcx`, `rdx`, `r8`, `r9` for arguments), or macOS syscall numbers, or AT&T operand order, do not paste it into our files unchanged. The instructions look familiar but the surrounding rules differ.

## Chapter map

Here is what's ahead, in order:

- **01 — Hello, CPU** — the smallest Linux program that prints text and exits. Every byte explained.
- **02 — Registers** — what the cups on the desk are, what each is for, and how `rax` / `eax` / `ax` / `al` are the same register at different widths.
- **03 — Moving data** — `mov` and the rules for shuffling bits between cups and shelves.
- **04 — Arithmetic** — `add`, `sub`, `mul`, `div`, and the flags they set.
- **05 — Bitwise** — `and`, `or`, `xor`, `not`, shifts. The thinking tools for working at the bit level.
- **06 — Addressing modes** — `[base + index*scale + disp]`. How the CPU computes an address.
- **07 — The stack** — push, pop, and the call/return mechanism.
- **08 — Control flow** — `cmp`, `jmp`, conditional jumps. How "if" works in assembly.
- **09 — Loops** — counted loops, `loop`, and why most real loops don't use `loop`.
- **10 — Functions** — the System V calling convention, prologues, epilogues.
- **11 — Talking to C** — calling C from assembly and assembly from C.
- **12 — Strings and arrays** — `rep movsb`, `rep stosb`, and string-friendly instructions.
- **13 — Syscalls** — a deeper look at the kernel interface introduced in Part 01.
- **14 — A tiny program** — assembling everything into one small, real-feeling program.
- **15 — Where next** — pointers to SIMD, OS dev, security, and other paths.

## Your sanity-check program

**In plain words:** before Part 01, make sure your environment is good. See [`03_how_to_read_this_course.s`](03_how_to_read_this_course.s):

```asm
.intel_syntax noprefix

        .section .text
        .globl  _start
_start:
        xor     rdi, rdi        # status = 0
        mov     rax, 60         # exit
        syscall
```

**The technical layer.** Two instructions before `syscall`: `xor rdi, rdi` zeros the register `rdi` (XOR-ing any value with itself produces 0 — it's the standard idiom for "set to zero"; Part 01 explains why we prefer it over `mov rdi, 0`), and `mov rax, 60` requests the exit syscall. Status 0 means "everything fine."

Build and run:

```bash
as -o check.o 03_how_to_read_this_course.s
ld -o check check.o
./check && echo "ready"
# => ready
```

**In plain words.** The `&&` only runs `echo "ready"` if `./check` exits with status 0. If you see `ready`, your toolchain is happy and you're set up correctly.

**Gotcha.** If you see `ready` but nothing else, that's correct. This program is supposed to be silent — it just exits cleanly. Silence plus a 0 exit status is success.

**Check yourself.** What would `./check && echo "ready"` print if the program exited with status 1 instead of 0? (Nothing — the `&&` short-circuits when the left side fails. You could replace `&&` with `;` to always print, or use `echo $?` to see the actual status.)

## A few habits to build now

**In plain words:** assembly is unforgiving. Build habits early so you don't have to debug them later.

- **Build after every change.** Don't accumulate three edits and then assemble. One change, one rebuild. When something breaks, you know exactly which line.
- **Run `objdump -d -M intel` once per chapter.** Looking at what your source compiled to is the fastest way to learn what the assembler actually does.
- **Always pair `syscall` for `write` with `syscall` for `exit`.** There is no automatic return. Falling off the end of `_start` crashes the program. Part 01 demonstrates this on purpose.
- **Read the gotchas.** Every chapter has them. They are the bugs you would have written yourself, pre-empted.

## What's next

You have the picture, the tools, and the map. Time to write your first real program.

Go to [Part 01 — Hello, CPU](../01_Hello_CPU/README.md).
