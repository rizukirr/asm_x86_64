# 02 — The toolchain

## A story: a small factory in your terminal

**In plain words:** turning the words you typed into a running program is not one step — it's a small assembly line. Each station does one job: translate, glue, inspect, watch, debug. The stations are real programs you invoke from the shell.

**The analogy.** Imagine a tiny factory.

1. A **translator** (`as`) reads your handwritten English-ish recipe (`hello.s`) and produces a sealed envelope of pure numbers (`hello.o`).
2. A **glue technician** (`ld`) takes one or more envelopes, glues them together, and stamps the result into a finished machine you can press the start button on (`./hello`).
3. An **X-ray machine** (`objdump`) lets you look inside the finished machine and see the numbered parts.
4. A **wiretap** (`strace`) lets you eavesdrop on every conversation the running machine has with the operating system.
5. A **technician with a slow-motion remote** (`gdb`) can pause the machine mid-job, ask "what's in cup A right now?", and let it tick one step forward.

**The technical layer.** All five of these are command-line programs that ship on every Linux distribution as part of `binutils` and friends. They are the *only* tools you need for this whole course.

**Check yourself.** If `as` produces a `.o` file and `ld` produces a runnable program, which step would you rerun after editing a `.s` file: `as` only, `ld` only, or both? (Both. `as` first to regenerate the bytes, then `ld` to relink them.)

## Are the tools installed?

**In plain words:** run one command to make sure everything we'll need is on your machine.

```bash
which as ld gcc gdb objdump strace
```

**The technical layer.** `which` prints the full path of each program if it exists. If anything comes back blank, install it:

- Debian / Ubuntu: `sudo apt install binutils gcc gdb strace`
- Arch: `sudo pacman -S binutils gcc gdb strace`
- Fedora: `sudo dnf install binutils gcc gdb strace`

**Gotcha.** On macOS the toolchain is different (`clang`, no Linux syscalls). On Windows, install **WSL2** (Windows Subsystem for Linux) and run everything inside that. This course assumes Linux for every command.

## Meet each tool with a real file

We will use [`02_the_toolchain.s`](02_the_toolchain.s) as our victim. It prints `tools` and exits.

```asm
.intel_syntax noprefix

        .section .data
msg:    .ascii  "tools\n"
        .equ    msglen, . - msg

        .section .text
        .globl  _start
_start:
        mov     rax, 1                  # write
        mov     rdi, 1                  # stdout
        lea     rsi, [rip + msg]        # buffer address
        mov     rdx, msglen             # length
        syscall

        mov     rax, 60                 # exit
        xor     rdi, rdi                # status = 0
        syscall
```

Don't worry about understanding every line yet — Part 01 explains all of it. Right now we are practicing the tools.

### `as` — the assembler

**In plain words:** read a `.s` file, output an `.o` file of bytes.

```bash
as -o tools.o 02_the_toolchain.s
```

**The technical layer.** `as` is the GNU assembler. It reads one or more `.s` source files and writes an **object file** (`.o`) — a partially-built program. The bytes are mostly the real machine code, but addresses and external names are still placeholders.

**Gotcha.** `as` only checks that each instruction is valid by itself. It will not catch a missing `_start` label; that error comes from the linker.

### `ld` — the linker

**In plain words:** glue object files together into a runnable program and fill in the placeholder addresses.

```bash
ld -o tools tools.o
./tools
# => tools
```

**The technical layer.** `ld` is the GNU linker. Its job is to combine all the `.o` files, resolve every symbol (every name like `msg` or `_start`), assign real memory addresses, and write out an executable in **ELF** format (the standard Linux program format).

**Gotcha.** If you forget `.globl _start` in your source, `ld` errors with "undefined reference to `_start`." The label exists in your file, but it's marked as private and the linker can't see it.

### `objdump` — the disassembler

**In plain words:** open a finished program and show you the bytes inside, translated back into readable instructions.

```bash
objdump -d -M intel tools
```

**The technical layer.** `-d` means "disassemble the executable sections" (translate bytes back into instruction names). `-M intel` means "use Intel syntax in the output." You'll see something like:

```
0000000000401000 <_start>:
  401000:  b8 01 00 00 00       mov    eax, 0x1
  401005:  bf 01 00 00 00       mov    edi, 0x1
  ...
```

Left column: address of each instruction. Middle: the actual bytes the CPU eats. Right: the human-readable form.

**Gotcha.** Without `-M intel`, `objdump` defaults to AT&T syntax on Linux — operands flipped, `%` prefixes, `$` on numbers. Your output won't look like your source. Always pass `-M intel` to match what we wrote.

### `strace` — the syscall wiretap

**In plain words:** print every single conversation the program has with the kernel.

```bash
strace ./tools
```

**The technical layer.** `strace` intercepts every syscall the program makes and prints it. Run it on our tiny program and you'll see roughly:

```
execve("./tools", ["./tools"], ...) = 0
write(1, "tools\n", 6)                = 6
exit(0)                               = ?
+++ exited with 0 +++
```

That's it. No libc, no startup machinery. Just the two syscalls we asked for, plus the `execve` the OS used to launch us. **No syscalls happen that we didn't write.** That is unusual — most real programs make dozens of syscalls before `main` even starts.

**Check yourself.** What would `strace` show if you removed the second `syscall` (the exit one) and the program crashed? (It would still show the `write`, then likely a `SIGSEGV` line and an abnormal termination, instead of `exit(0)`.)

### `gdb` — the debugger

**In plain words:** pause your program at any instruction, look inside every register, and step forward one move at a time.

```bash
gdb ./tools
```

Inside `gdb`:

```
(gdb) layout asm           # show the assembly view
(gdb) break _start         # pause when we reach _start
(gdb) run                  # start the program
(gdb) info registers       # show every cup
(gdb) stepi                # advance one instruction
(gdb) quit
```

**The technical layer.** `gdb` is the GNU debugger. `break _start` tells it to stop the first time the CPU lands on the `_start` label. `stepi` advances exactly one instruction at a time (as opposed to `step`, which is for high-level languages and tries to advance one *source line*). `info registers` dumps every register.

**Gotcha.** If you build *without* debug info, `gdb` still works, but it won't know your label names beyond what the linker recorded. For more comfortable debugging later we'll occasionally pass `--gstabs` to `as` or `-g` style flags; for now the bare program is fine.

## The AT&T vs Intel detour

**In plain words:** there are two ways to spell the *same* instruction. We picked Intel; here's why.

```
AT&T:    movq  $60, %rax
Intel:   mov   rax, 60
```

**The technical layer.** AT&T syntax is the historic Unix default. Intel syntax is what the official Intel and AMD manuals use. Differences:

| Aspect          | AT&T              | Intel              |
| --------------- | ----------------- | ------------------ |
| Operand order   | `src, dst`        | `dst, src`         |
| Register prefix | `%rax`            | `rax`              |
| Immediate       | `$60`             | `60`               |
| Memory          | `8(%rbp,%rcx,4)`  | `[rbp + rcx*4 + 8]`|

**Gotcha.** Most beginners get bitten by the **operand order** difference. AT&T says "source, destination." Intel says "destination, source." `mov rax, 60` in Intel means "put 60 *into* rax" — destination first. If you copy a snippet from a tutorial that uses AT&T and paste it into our files, the operands will be backward and your program will misbehave silently.

We use Intel everywhere by putting `.intel_syntax noprefix` at the top of every `.s` file. When you run `objdump`, always pass `-M intel`. When you read GCC's `-S` output, pass `-masm=intel`.

## Your toolchain dry-run

Try the full pipeline yourself on the file from this topic:

```bash
as -o tools.o 02_the_toolchain.s          # translate
ld -o tools tools.o                       # glue
./tools                                   # run
objdump -d -M intel tools | head -n 20    # x-ray
strace ./tools 2>&1 | head -n 10          # wiretap
```

If all five commands behave (the third prints `tools`, the fourth shows assembly, the fifth shows two syscalls), your toolchain is ready.

**Check yourself.** Why does `strace ./tools` pipe stderr (`2>&1`) instead of stdout? (Because `strace` prints to stderr by default. Without `2>&1`, the `head` filter wouldn't see anything.)

## What's next

You can now build, run, and inspect a program. The last setup step is understanding *how this course is laid out* — what to expect from each chapter, what's in scope, and what isn't.

Go to [03 — How to read this course](03_how_to_read_this_course.md).
