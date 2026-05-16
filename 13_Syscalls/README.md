# Part 13 — Syscalls

## The picture first: asking the building manager

Imagine you live in a giant apartment building. Inside your apartment you can do almost anything you like — rearrange your furniture, cook, sleep, paint the walls. But some things you simply cannot do from your apartment, no matter how clever you are:

- You cannot unlock the mailroom door.
- You cannot turn on the heating for the whole building.
- You cannot open the front gate to let a delivery in.

For those, you call down to the **building manager**. They have keys you don't. They have permissions you don't. You phone them, say what you want, hand over any details they need, and wait for them to do it (or refuse).

That building manager is the **kernel** — the heart of the operating system. Your apartment is your program. The phone call is the `syscall` instruction.

A **syscall** ("system call") is how a program asks the kernel to do something the program isn't allowed to do directly: read from the keyboard, write to the screen, open a file, ask for more memory, start a new process, exit. The kernel runs at higher privilege than you do; the `syscall` instruction is the doorbell that hands control over to the kernel's pre-arranged front desk, which looks at your registers to figure out what you want.

(In an earlier chapter we also met **libc** — a helpful coworker in your apartment who already knows the building manager and will translate friendly requests like "print this line, please" into the gritty syscall the manager actually expects. We will come back to that.)

## The Linux x86_64 syscall ABI

**ABI** stands for "Application Binary Interface" — a fancy way of saying "the agreed-upon paperwork rules." Before you ring the doorbell, you must put each piece of information in the exact cup the manager expects to look in. Cups, of course, means registers.

| Register | Role                |
| -------- | ------------------- |
| `rax`    | syscall number      |
| `rdi`    | arg 1               |
| `rsi`    | arg 2               |
| `rdx`    | arg 3               |
| `r10`    | arg 4 **(not rcx!)**|
| `r8`     | arg 5               |
| `r9`     | arg 6               |
| `rax`    | return value (negative errno on failure) |

"Syscall number" is just an integer ID. Every kind of request the kernel knows how to handle has a number: 0 means "read," 1 means "write," 60 means "exit." You write the number into `rax`, fill out the argument cups, ring the doorbell, and the kernel does the job.

Compare against the C calling convention from [Part 10](../10_Functions/README.md):

| Position | C ABI | Syscall ABI |
| -------- | ----- | ----------- |
| 4th      | `rcx` | **`r10`**   |

That is the only difference. Why is it different? Because the `syscall` instruction itself secretly uses `rcx` for bookkeeping (it stashes the return address there). So when you want the kernel to receive your fourth argument, you put it in `r10` instead. Forgetting this is a classic bug.

One more consequence: `syscall` clobbers (overwrites) `rcx` and `r11`. Treat both of those cups as empty after every syscall.

## Some useful syscall numbers

Linux on x86_64 has roughly 400 different syscalls. Here are the headline ones you will meet first.

| #   | Name      | Args                                          |
| --- | --------- | --------------------------------------------- |
| 0   | `read`    | `fd, buf, count` → bytes read                 |
| 1   | `write`   | `fd, buf, count` → bytes written              |
| 2   | `open`    | `path, flags, mode` → fd                      |
| 3   | `close`   | `fd`                                          |
| 9   | `mmap`    | `addr, len, prot, flags, fd, off` → pointer   |
| 11  | `munmap`  | `addr, len`                                   |
| 35  | `nanosleep` | `req, rem`                                  |
| 39  | `getpid`  | (none)                                        |
| 57  | `fork`    | (none) → pid                                  |
| 59  | `execve`  | `pathname, argv, envp`                        |
| 60  | `exit`    | `status`                                      |
| 231 | `exit_group` | `status`                                   |

A note on the word `fd`: it stands for "file descriptor." Think of it as a coat-check ticket. When you ask the kernel to open a file, it does the work and hands you back a small number — that number is your ticket for talking about this open file later. By tradition, three tickets are always pre-issued when your program starts:

- `fd 0` is **stdin** (standard input — usually the keyboard).
- `fd 1` is **stdout** (standard output — usually the screen).
- `fd 2` is **stderr** (standard error — also the screen, by convention used for error messages).

The authoritative list of syscall numbers lives in `/usr/include/asm/unistd_64.h` or `man 2 syscall`.

## Errors

Most programming languages have an `errno` variable that says what went wrong. Linux syscalls do not. Instead, the syscall returns a negative number in `rax` whose absolute value is the error code. So `-2` means "error number 2" (which is `ENOENT`, "no such file or directory").

```asm
mov     rax, 0                  # read
mov     rdi, 0                  # fd 0 (stdin)
mov     rsi, rsp                # buf
mov     rdx, 16                 # count
syscall
test    rax, rax
js      .error                  # negative -> error
```

What this actually does, in plain words: "Ask the kernel to read up to 16 bytes from stdin into the spot on the stack pointed to by `rsp`. After the call, look at `rax`. If its top bit is set — meaning it is a negative number — that's an error; jump to the error label."

`js` is "jump if **s**ign flag is set." The sign flag (`SF`) is another one-bit memory inside the CPU, set to 1 whenever the last result came out negative. If you want to print the error code as a positive number, use `neg rax` to flip the sign.

## A read-then-echo program

This program reads up to 128 bytes from stdin and echoes them right back to stdout. No libc, just two syscalls and an exit.

```asm
.intel_syntax noprefix
        .bss
buf:    .skip   128

        .text
        .globl  _start
_start:
        # n = read(0, buf, 128);
        xor     rax, rax                # 0 = read
        xor     rdi, rdi                # fd 0 = stdin
        lea     rsi, [rip + buf]
        mov     rdx, 128
        syscall

        # if (n <= 0) exit(1)
        test    rax, rax
        jle     .err

        # write(1, buf, n);
        mov     rdx, rax                # count = bytes read
        mov     rax, 1                  # 1 = write
        mov     rdi, 1                  # fd 1 = stdout
        lea     rsi, [rip + buf]
        syscall

        # exit(0)
        xor     rdi, rdi
        mov     rax, 60
        syscall
.err:
        mov     rdi, 1
        mov     rax, 60
        syscall
```

What this actually does, in plain words:

1. Reserve a 128-byte chunk of memory called `buf` — a row of 128 one-byte lockers.
2. Set up a `read` syscall: number 0 in `rax`, fd 0 (stdin) in `rdi`, the address of `buf` in `rsi`, and 128 (the max number of bytes to read) in `rdx`. Ring the doorbell.
3. The kernel returns the number of bytes it actually read in `rax`. If that number is zero or negative, jump to the error path.
4. Set up a `write` syscall: number 1 in `rax`, fd 1 (stdout) in `rdi`, address of `buf` again in `rsi`, and the byte count (which is sitting in `rax` from the read) goes into `rdx`. Ring the doorbell.
5. Set up `exit(0)`: number 60 in `rax`, status 0 in `rdi`. Ring the doorbell. The kernel ends our program here; nothing after this line will ever run.

`.bss` (short for "block started by symbol" — a name from the 1950s) is the section of your program that lists memory you want, but want pre-filled with zeros. `.skip 128` says "reserve 128 bytes here." None of those zero bytes are actually stored in the binary on disk; the operating system creates and zeros them when your program loads. Free real estate.

```bash
as -o echo.o echo.s && ld -o echo echo.o
echo hello | ./echo
# => hello
```

## syscall vs libc — when to pick which

Remember, libc is the helpful coworker who already knows the building manager. Sometimes you call them. Sometimes you go talk to the manager yourself. Here is when each makes sense.

| Use syscall directly when…                       | Use libc when…                       |
| ------------------------------------------------ | ------------------------------------ |
| Writing freestanding code (no libc).             | Doing anything that benefits from buffering, formatting, locale, threading. |
| Implementing the lowest layer of a runtime.      | Calling anything stdio-shaped: `printf`, `fopen`, `fread`. |
| Sandboxed/seccomp setup, perf experiments.       | You need portability across Unixes — libc smooths over differences. |
| You truly need the precise kernel behavior.      | You want correctness for free.       |

A small subtlety: when you call `printf`, libc doesn't run to the kernel for each character. It collects letters in a private notebook (a buffer) and hands them over to the kernel in big batches. That's good for speed. But if you mix `printf` and direct `write` syscalls in the same program, your output will come out in the wrong order — half of it stuck in libc's notebook, half already printed. Pick one lane.

## `strace`: see your syscalls

`strace` is a tool that records every syscall a program makes, with arguments and return values. It is the X-ray machine for "what did this binary actually ask the kernel to do?"

```bash
strace ./echo <<<"hi"
# read(0, "hi\n", 128)        = 3
# write(1, "hi\n", 3)         = 3
# exit(0)                     = ?
```

If you ever wonder what a program is doing under the hood, `strace` is unbeatable.

## Try it

1. Write a program that prints its own PID (process ID — the number Linux gave your running program) by calling syscall 39 (`getpid`) and converting to ASCII. (Hint: divide by 10 in a loop.)
2. Open a file (`open`) read-only, read 64 bytes, write them to stdout. Mind the 4th-argument `r10` rule if you pass `mode`.
3. Use `strace -c ./your_program` to count which syscalls a libc-using program issues. A `printf("hello\n")` program makes more syscalls than you'd expect.

## What's next

Time to put it all together. [Part 14](../14_Tiny_Program/README.md) — a complete asm program that reads a number, doubles it, and prints it. No libc.
