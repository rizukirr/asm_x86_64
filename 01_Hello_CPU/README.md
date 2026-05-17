# Part 01 — Hello, CPU

## A story: ordering pizza from the building manager

**In plain words:** your program can't touch the screen, the disk, or the network directly. It has to ask the operating system to do those things for it.

**The analogy.** Imagine you live in a giant apartment building. You're hungry, but you can't leave your room. Lucky for you, the building has a **manager** who can do things for you — order pizza, take out the trash, call a taxi.

But the manager only listens to a strict form. You write four things on the form:

1. **Which job number?** (1 = order pizza, 2 = call taxi, 60 = move out, etc.)
2. **First detail** (e.g., what flavor of pizza)
3. **Second detail**
4. **Third detail**

Then you slide the form under the door, the manager handles it, and a result slides back.

**The technical layer.** That manager is the **operating system kernel** (the most important piece of software running on your computer — the part that actually controls the screen, the disk, and the network). The form you slide under the door is called a **syscall** (short for "system call"). And the strict rules about which detail goes in which spot are called a **calling convention**.

**Check yourself.** If syscalls are how programs ask the kernel for things, what do you think happens if a program tries to write to the screen *without* a syscall? (Answer: it can't — the program has no direct access. Every `print`, `open`, `read` in every language eventually becomes a syscall under the hood.)

In this chapter we slide two forms under the door:

1. **Form #1**: "Please print this text to the screen."
2. **Form #2**: "I'm done, please clean me up."

That's all our program does. But by the end you'll have seen every layer of how a computer turns letters in a file into pixels on a screen.

## Our first program

**In plain words:** we will write the tiniest possible Linux program — one that prints `Hello, CPU!` and exits.

No `libc` (the standard C library — a giant helper toolkit most programs use), no `main` function, no startup code — just a `.s` file (your handwritten assembly), an assembler, and a linker.

## The code

See [`hello.s`](hello.s):

```asm
.intel_syntax noprefix

        .section .data
msg:    .ascii  "Hello, CPU!\n"
        .equ    msglen, . - msg

        .section .text
        .globl  _start
_start:
        mov     rax, 1          # syscall number: write
        mov     rdi, 1          # fd: stdout
        lea     rsi, [rip + msg]# buffer pointer
        mov     rdx, msglen     # length
        syscall

        mov     rax, 60         # syscall number: exit
        xor     rdi, rdi        # status = 0
        syscall
```

**In plain words.** The first chunk fills out form #1 ("print this text"): it writes the job number 1 in a specific cup (`rax`), then writes "screen" (file descriptor 1, meaning standard output) in another cup, then the address where the text lives in a third cup, then how long the text is in a fourth cup. Then `syscall` slides the form under the door.

The second chunk fills out form #60 ("I'm done"), with status 0 (meaning "everything went fine"), and slides that form under too.

## Build and run

```bash
as -o hello.o hello.s
ld -o hello hello.o
./hello
# => Hello, CPU!
```

**In plain words:**

- `as -o hello.o hello.s` runs the **assembler**: read the human-readable file `hello.s`, output a file of bytes called `hello.o`.
- `ld -o hello hello.o` runs the **linker**: take the bytes and finish turning them into a runnable program called `hello`.
- `./hello` actually runs it.

If you got `Hello, CPU!` — congratulations, you executed an instruction stream you wrote yourself.

## Dissecting it

### `.intel_syntax noprefix`

**In plain words:** a note to the assembler that says "use the easier-to-read style for the rest of this file."

**The technical layer.** This is an **assembler directive** — not a real CPU instruction, just a note to the translator. It says "translate the rest of this in Intel style, and don't make me put `%` in front of every register name." Everything below this line reads `mov dst, src` (destination first, source second).

**Gotcha.** There are two flavors of assembly syntax for the same x86 CPU: AT&T (the default, with `%` prefixes and source-first order) and Intel (destination-first, no prefixes). This course uses Intel because it matches the official Intel/AMD manuals.

### Sections

```asm
.section .data
.section .text
```

**In plain words:** the program file is divided into labeled compartments. `.text` is for instructions, `.data` is for data.

**The analogy.** Think of a program file as a binder with several labeled tabs. Each tab holds a different *kind* of stuff:

- **`.text`** — the recipe book: executable instructions. Read-only when the program is running, because nobody should be allowed to scribble on the recipes while you're following them.
- **`.data`** — the pantry: named ingredients you set up ahead of time. Strings, tables, global variables. Readable AND writable.
- **`.bss`** — empty pantry shelves: variables you'll fill in later, that start at zero.
- **`.rodata`** — the locked pantry: read-only ingredients (constants) you can look at but not change.

**The technical layer.** `.text`, `.data`, `.bss` are not arbitrary names — they're conventions baked into the **ELF** format (the standard file format Linux uses for programs) and recognized by the linker, the loader, and the OS.

**Gotcha.** You can't rename `.text` to `.code` and expect it to work the same — the linker maps `.text` to executable memory *because* of that exact name.

So:

```asm
.section .data    # next stuff goes into the data section
...

.section .text    # next stuff goes into the text section
.globl  _start
_start:
...
```

### The string

```asm
msg:    .ascii  "Hello, CPU!\n"
        .equ    msglen, . - msg
```

**In plain words:** put the 12 bytes "Hello, CPU!\n" in the data section, name that spot `msg`, and let `msglen` mean "12" so we don't have to count by hand.

**The analogy.** `msg:` is a **label** — a sticky note naming an address. Like writing "Bob's Pizza" on shelf number 47 so you never have to remember the number, just the name. When you say `msg` later in the program, the assembler quietly swaps it for the real shelf number.

**The technical layer.**

- `.ascii` emits the bytes of the string into the data section (without a NUL terminator).

  > NOTE: A **null terminator** is a special invisible character (the byte `0x00`) used by some programming languages (like C) to mark the end of a string. `.ascii` does NOT add one. We don't need one here because we're explicitly telling the kernel how many bytes to print.

- `.equ` is an assembler directive that defines a **symbolic constant** — like `#define` in C, or a regular `const` in modern programming languages. It assigns a name to a value at assemble time. No memory is allocated, no instruction is emitted; it's purely a labeling trick that happens before the program ever runs. In a modern language you'd write `const msg_len = <value>`; in assembly we write `.equ msg_len, <value>`.

- `.equ msglen, . - msg` is a clever compile-time computation. The dot `.` is a special symbol meaning **"the address right here, right now"** (i.e., wherever the assembler currently is in the file). So `. - msg` is "the address right after the string, minus the address where the string starts" — which equals the length of the string in bytes. The assembler does this subtraction while building the program. By the time your program runs, `msglen` is just a fixed number baked in.

**Check yourself.** If you change the string to `"Hi!\n"`, what does `msglen` become? (Answer: 4, automatically — that's the whole point of `. - msg`. You never have to recount.)

### `_start`

```asm
.globl  _start
_start:
```

**In plain words:** `_start` is the door the operating system walks through to begin running our program.

**The analogy.** It's the assembly equivalent of `main` in C — except `main` is actually invented by `libc` (the C library); the kernel itself only knows about `_start`.

**The technical layer.** `_start` is the **entry point** — the spot the Linux loader jumps to right after loading our program into memory. The `.globl` directive makes the `_start` label visible to the linker (otherwise the linker would treat it as a private detail of this file and fail to find it).

**Gotcha.** If you forget `.globl`, the link step fails with "undefined reference to `_start`." The label exists, but the linker can't see it.

### The write syscall

**In plain words:** put the right numbers in the right cups, then say `syscall`, and the kernel prints your text.

**The analogy / table.** Linux gives your program access to its services through one special instruction: `syscall`. The agreement on x86_64 — the "form" we mentioned at the top — is:

| Register | Traditional Role              |
| -------- | -------------------- |
| `rax`    | Accumulator — return values, syscall number       |
| `rdi`    | Destination Index — 1st syscall arg                |
| `rsi`    | Source Index — 2nd syscall arg                |
| `rdx`    | Data — 3rd syscall arg                |
| `r8 - r15`     | Extras added in x86-64                |

**The technical layer.** For the C-style call `write(fd, buf, len)` — meaning "write to file descriptor `fd`, the bytes at address `buf`, of length `len`" — the syscall number is 1. A **file descriptor** is just a small number the OS uses to identify an open file or stream. By convention, `fd = 1` means standard output (your terminal screen).

```asm
mov     rax, 1                  # write
mov     rdi, 1                  # stdout
lea     rsi, [rip + msg]        # buf  -> address of msg
mov     rdx, msglen             # len
syscall
```

**In plain words, step-by-step:**

1. Put 1 in cup `rax` — that's the form number for "write."
2. Put 1 in cup `rdi` — first detail: write to screen (file descriptor 1).
3. Put the address of our `msg` string in cup `rsi` — second detail: which bytes to write.
4. Put 12 (the value of `msglen`) in cup `rdx` — third detail: how many bytes.
5. Hit `syscall` — slide the form under the door. The kernel reads the cups, prints the bytes, and lets us continue.

**Zooming in on `lea`.** `lea rsi, [rip + msg]` deserves attention.

- **In plain words:** "figure out the address of `msg` and put that address (not the contents) in `rsi`."
- **The technical layer.** `lea` means **load effective address**: compute an address and put it into a register, without actually going to that shelf and fetching what's there. (Compare to `mov`, which *does* go fetch.) `[rip + msg]` is **RIP-relative** addressing — it means "the address of `msg`, expressed as how far away it is from the current instruction pointer." This is the modern, position-independent way to refer to a label (it works even if the operating system loaded our program into a different spot in memory than expected).
- **Don't panic.** We cover `lea` and addressing modes in depth in [Part 06](../06_Addressing/README.md).

After `syscall`, the kernel does the work and returns control to our program. The result (the number of bytes successfully written, or a negative error code) appears in `rax`. We ignore it here.

### The exit syscall

```asm
mov     rax, 60                 # exit
xor     rdi, rdi                # status = 0
syscall
```

**In plain words:** put 60 in `rax` (the form number for "exit"), put 0 in `rdi` (the exit status — 0 means "no problem"), slide the form. The kernel cleans up our program and never returns control to us.

**Zooming in on `xor rdi, rdi`.**

- **In plain words:** "set `rdi` to zero, using the shortest possible instruction."
- **The technical layer.** Any number XOR'd with itself is always 0 (XOR is a bit operation that gives 1 only when its two inputs differ; a number can't differ from itself, so the result is all zeros). The clever part is that this encoding is shorter in bytes than `mov rdi, 0`.
- **Gotcha.** You will see `xor reg, reg` literally everywhere in real assembly — it's the standard way to zero a register. Don't read it as "XOR these two things"; read it as "zero this register."

**Why a second `syscall`?** Because if we just "fell off the end" of `_start`, `rip` would continue advancing into whatever random bytes happened to live after our code in memory and the CPU would obediently try to execute them — almost certainly resulting in a crash (`SIGSEGV` means "you touched a shelf you weren't allowed to" and `SIGILL` means "that's not a real instruction"). **There is no automatic return from `_start`.** You must explicitly tell the kernel you are done.

## Look at the bytes

**In plain words:** let's peek at the actual machine code the CPU sees.

```bash
objdump -d -M intel hello
```

**The technical layer.** `objdump` is a tool that opens a built program and shows you what's inside. `-d` means "disassemble" (turn bytes back into readable instructions). `-M intel` means "show me in Intel style."

You will see something like:

```
0000000000401000 <_start>:
  401000:  b8 01 00 00 00       mov    eax, 0x1
  401005:  bf 01 00 00 00       mov    edi, 0x1
  40100a:  48 8d 35 ef 0f 00..  lea    rsi, [rip + 0xfef]
  ...
```

The leftmost column is the address of each instruction. The middle column is the actual bytes the CPU eats. The right column is the human-readable version.

**Two things to notice (and one gotcha):**

1. The assembler turned `mov rax, 1` into `mov eax, 1` (5 bytes instead of 7). On x86_64, **writing to a 32-bit register zero-extends into the full 64-bit register** — if you fill in only the bottom half (`eax`), the CPU automatically wipes the top half to all zeros. So `mov eax, 1` and `mov rax, 1` produce the exact same result when the source value is small, but `mov eax, 1` is encoded with fewer bytes. We'll see this trick again.
2. Every instruction is just a small handful of bytes. That's all a "program" really is — a long ribbon of numbers the CPU walks through, one mouthful at a time.

**Gotcha.** Don't try this zero-extension trick with 16-bit (`ax`) or 8-bit (`al`) writes — those do *not* clear the upper bits. Only 32-bit writes get the free zero-extend. We come back to this in Part 02.

## Try it

1. **Change the string.** Rebuild. The length recomputes automatically — that's what `. - msg` bought you.
2. **Remove the second `syscall` block.** Rebuild. Run. Observe the crash (a `SIGSEGV` or weird behavior). This is the lesson: there is no automatic exit.
3. **Run `strace ./hello`.** `strace` is a tool that prints every syscall a program makes. You will see exactly the two syscalls, and nothing else. No libc, no init, no anything. This is the smallest functioning Linux program.

## What's next

We can already see that **registers are the workbench** (the cups on the desk) and **memory is the storage room** (the warehouse shelves). In [Part 02](../02_Registers/README.md) we look at the registers themselves: what each one is for, why some have names like `rdi`/`rsi`, and how `rax`/`eax`/`ax`/`al` are all the same register seen at different widths.
