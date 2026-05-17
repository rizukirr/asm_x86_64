# 01 — What is assembly, and why bother?

## A story: the absurdly fast worker

**In plain words:** the CPU is not a brilliant thinker. It is a worker who only knows a handful of tiny moves, but performs them billions of times per second. Assembly language is the list of those tiny moves, written down in a form you can actually read.

**The analogy.** Picture a worker sitting at a small desk in a giant warehouse.

The worker can only do bite-sized jobs: "grab the cup labeled A," "add one to whatever is in cup A," "put cup A back on the desk." That is the whole job description. There is no "make me a sandwich" instruction. There is no "open Netflix" instruction. There are only tiny shuffles between cups on the desk and shelves in the warehouse.

But this worker is supernaturally fast. They do *billions* of tiny shuffles every second. Stack enough of those shuffles end-to-end and you get a web browser. Stack more and you get a video game. Stack more still and you get the program running this very page in your editor.

**The technical layer.** The worker is the **CPU** (Central Processing Unit — the brain chip inside your computer). The cups on the desk are **registers** (a tiny, fixed set of named slots inside the CPU itself, where work happens). The shelves are **main memory** (also called **RAM** — a giant array of numbered storage cells, much bigger than the registers but much slower to reach). The "list of tiny moves" is **machine code**: long ribbons of numbers the CPU eats one at a time. And **assembly language** is just machine code spelled with words instead of numbers so a human can read it.

**Check yourself.** If the CPU only knows tiny moves, where does something like "play a video" come from? (Answer: software writers chained millions of tiny moves together. Every fancy feature in every program eventually decomposes into the same handful of CPU instructions.)

## Why learn this in 2026?

**In plain words:** you will almost never *write* assembly to ship a real product. You will, however, often need to **read** it. That is the real win.

Here are the moments where knowing assembly suddenly pays off:

- A **profiler** (a tool that measures which parts of your program are slow) points at a chunk of assembly and says "this is your bottleneck." You need to understand what it is showing you.
- A bug only appears in **release mode** (the optimized build), where the compiler has rearranged your code so aggressively that the source no longer matches what the CPU is actually doing.
- A program crashes, and the helpful labels are stripped away — all you have is the raw instructions.
- You want to know what mysterious words like `volatile`, atomics, or SIMD intrinsics *actually mean* down at the metal.
- You are learning compilers, operating systems, security, embedded systems, or game engines.

**The real payoff** is not "I can now write assembly." It is **demystification** — losing the feeling that computers are magic. Once you can see registers, memory, jumps, and calls happen with your own eyes, every higher-level language stops feeling like sorcery.

## The mental model in one picture

Here is the picture to keep in your head for the entire course.

```
        +-------------------------------+
        |             CPU               |
        |  Registers (cups on the desk) |
        |    rax  rbx  rcx  rdx         |
        |    rsi  rdi  rbp  rsp         |
        |    r8 .. r15                  |
        |    rip   rflags               |
        +-------------------------------+
                  ^         |
            load  |         |  store
                  |         v
        +-------------------------------+
        |           Memory              |
        |  .text   (your instructions)  |
        |  .data   (named globals)      |
        |  stack   (grows downward)     |
        |  heap    (grows upward)       |
        +-------------------------------+
```

**In plain words.** The CPU has a tiny set of slots on the desk where the actual work happens. Memory is a vast field of numbered storage out back. The arrows are the worker walking back and forth: **load** = "fetch from a shelf into a cup," **store** = "put a cup's contents back on a shelf."

**The technical layer.** Forever and ever, the CPU runs this loop:

1. Look at the address stored in a special register called **`rip`** (the **instruction pointer** — the cup that always says "what should I do next?").
2. Walk to that shelf in memory and read the instruction written there.
3. Decode it (figure out what it means).
4. Execute it — usually this moves bits between registers and memory, or does some arithmetic on registers.
5. Advance `rip` to the next instruction (unless the instruction was a "jump," meaning "go look at a different shelf instead").
6. Go back to step 1.

Billions of times per second. That is the whole CPU. Functions, loops, objects, web servers, video games — all of it is built on top of that one loop.

## What "x86_64" actually means

**In plain words:** x86_64 is the *name* of the family of CPUs and the language they speak. Almost every laptop and desktop sold in the last twenty years (except Apple Silicon Macs) is an x86_64 machine.

**The technical layer.**

- **x86** is a CPU family that started with the Intel 8086 chip in 1978. The name comes from the fact that most of the early chip numbers ended in 86 (8086, 80286, 80386, ...). Early x86 chips handled 16 bits at a time, then later 32 bits.
- **x86_64** (also called **AMD64**, **x64**, or **Intel 64**) is the **64-bit** version, designed by AMD in 2003 and later adopted by Intel. "64-bit" means each register can hold a number up to 64 binary digits wide — vastly larger than before — and memory addresses are 64 bits too. It also gave us 16 general-purpose registers instead of the original 8.

**Gotcha.** "x86" by itself usually means the 32-bit version. "x86_64" specifically means 64-bit. We are doing 64-bit. If a stray tutorial uses 32-bit conventions (registers named `eax` instead of `rax`, syscall numbers that don't match ours, etc.), it is talking about a different — older — world.

## The smallest possible program

**In plain words:** let's actually run something. The tiniest x86_64 Linux program you can write is one that does nothing visible — it just sets an exit code and quits. That alone proves the whole pipeline (write → assemble → link → run) works.

See [`01_what_is_assembly.s`](01_what_is_assembly.s):

```asm
.intel_syntax noprefix

        .section .text
        .globl  _start
_start:
        mov     rax, 60         # syscall number 60 = exit
        mov     rdi, 42         # exit status
        syscall
```

**The technical layer.** Three instructions, top to bottom:

1. `mov rax, 60` — put the number 60 into the register `rax`. 60 is the Linux **syscall number** for "exit." (A **syscall** is how a program asks the operating system for a service. We cover them properly in Part 01.)
2. `mov rdi, 42` — put 42 into register `rdi`. This is the exit status the program will return to the shell. 42 is just a number we picked; it could be anything from 0 to 255.
3. `syscall` — actually invoke the operating system. The kernel reads `rax` to see *which* service we want (60 = exit), reads `rdi` for the argument (42 = our chosen status), and ends the program.

**Build and run:**

```bash
as -o tiny.o 01_what_is_assembly.s
ld -o tiny tiny.o
./tiny
echo $?
# => 42
```

**In plain words:**

- `as` turns your readable `.s` file into a `.o` file of raw bytes (this is **assembling**).
- `ld` turns the `.o` file into a runnable program (this is **linking**).
- `./tiny` runs it. It prints nothing.
- `echo $?` asks the shell "what did the last program exit with?" — and that's how you see the 42.

**Gotcha.** Don't expect any output. If the terminal stays silent and `echo $?` says `42`, you succeeded. Programs talk to the world through **syscalls**, and this program only made the "exit" syscall — it never asked the OS to print anything.

**Check yourself.** Change `42` to `7`, rebuild, run, and run `echo $?` again. Does it print `7`? (It should. You just controlled a CPU directly. Welcome.)

## What's next

You have the picture: CPU is the worker, registers are cups on the desk, memory is shelves in the warehouse, and assembly is the list of tiny moves. Next we look at the **tools** you'll use to turn `.s` files into runnable programs and to peek inside them when things go wrong.

Go to [02 — The toolchain](02_the_toolchain.md).
