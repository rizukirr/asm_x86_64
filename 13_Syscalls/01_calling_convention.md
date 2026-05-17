# 13.1 — The Syscall Calling Convention

## A story: the strict paperwork window

**In plain words:** before your program is allowed to talk to the kernel, it has to fill out a form. The form has fixed slots, and each slot must contain a specific piece of information in a specific cup.

**The analogy.** Picture a government office with a single service window. The clerk behind the glass will do almost any job for you — issue a passport, change your address, file a tax form — but only if you put the paperwork in *exactly* the right order on the tray. Slot 1 is the form number. Slots 2 through 7 are the details. You slide the tray under the glass, the clerk processes it, and a single number slides back: either the result, or an error code.

That clerk is the **Linux kernel**. The tray is a set of CPU registers. The "slide it under" gesture is one special instruction: `syscall`.

**The technical layer.** A **syscall** ("system call") is how a user program asks the kernel to do something it isn't allowed to do directly — touch the screen, read a file, allocate memory, exit. The agreement about which register holds what is called the **syscall ABI** ("Application Binary Interface"). On Linux x86_64, the ABI is:

| Register | Role                                              |
| -------- | ------------------------------------------------- |
| `rax`    | syscall number (input) / return value (output)    |
| `rdi`    | argument 1                                        |
| `rsi`    | argument 2                                        |
| `rdx`    | argument 3                                        |
| `r10`    | argument 4 **(not `rcx`!)**                       |
| `r8`     | argument 5                                        |
| `r9`     | argument 6                                        |

**Gotcha.** Argument 4 is `r10`, not `rcx`. In the regular C function calling convention, the fourth argument lives in `rcx`. But the `syscall` instruction itself secretly uses `rcx` for bookkeeping — it stashes the return address there. So the kernel agreed to look in `r10` instead. Forgetting this is one of the most common syscall bugs.

**Also clobbered:** after every `syscall`, the contents of `rcx` and `r11` are garbage. Treat both cups as empty.

**Check yourself.** If you call a C function with four arguments, the 4th goes in `rcx`. If you make a Linux syscall with four arguments, the 4th goes in `____`. (Answer: `r10`.)

## A handful of syscall numbers to memorize

Every syscall has a number. Linux x86_64 has roughly 400 of them. The authoritative list lives in `/usr/include/asm/unistd_64.h` (or `man 2 syscalls`). The headline numbers you will meet first:

| #   | Name         | Args                                       |
| --- | ------------ | ------------------------------------------ |
| 0   | `read`       | `fd, buf, count`                           |
| 1   | `write`      | `fd, buf, count`                           |
| 2   | `open`       | `path, flags, mode`                        |
| 3   | `close`      | `fd`                                       |
| 8   | `lseek`      | `fd, offset, whence`                       |
| 39  | `getpid`     | (none)                                     |
| 60  | `exit`       | `status`                                   |
| 231 | `exit_group` | `status`                                   |

A note on the word `fd` ("file descriptor"): think of it as a coat-check ticket. When you ask the kernel to open a file, it does the work and hands you back a small number — that number is your ticket for talking about this open file later. Three tickets are pre-issued for free when your program starts:

- `fd 0` — **stdin** (standard input, usually the keyboard).
- `fd 1` — **stdout** (standard output, usually the screen).
- `fd 2` — **stderr** (standard error, also the screen by default).

## The errno trick: how the kernel reports failure

**In plain words:** the kernel never sets a separate "error" variable. Instead, it stuffs the error code into the same `rax` it would have used for a success value — but as a *negative* number.

**The technical layer.** After `syscall` returns, look at `rax`:

- If `rax` is `>= 0`, it is the success result (bytes read, fd opened, etc.).
- If `rax` is in the range `-1` to `-4095`, it is `-errno`. That is, `rax = -2` means "error number 2," which is `ENOENT` ("no such file or directory").

Why `-4095`? Because the kernel reserves the range `[-4095, -1]` exclusively for errors. Anything more negative than `-4095` is treated as a legitimate (if huge) signed result. In practice you check the sign:

```asm
        syscall
        test    rax, rax
        js      .error              # jump if negative
```

`test rax, rax` is "compute `rax AND rax` and set the flags, but throw the result away." That's the cheapest way to find out whether `rax` is zero, positive, or negative. `js` is "jump if **s**ign flag is set" — i.e., jump if the previous result was negative.

**Gotcha.** If you want to print the error code as a positive integer, use `neg rax` first. Otherwise you will print something like `-2`, which is just confusing.

## The smallest possible syscall demo

See [`01_calling_convention.s`](01_calling_convention.s):

```asm
.intel_syntax noprefix

        .section .text
        .globl  _start
_start:
        mov     rax, 39                 # syscall: getpid (no args)
        syscall
        # rax now holds our PID. We won't print it -- just exit.

        mov     rax, 60                 # syscall: exit
        xor     rdi, rdi                # status = 0
        syscall
```

**In plain words.** We call `getpid`, syscall number 39. It takes no arguments. The kernel writes our process ID into `rax`. We don't do anything with it — we just call `exit(0)` and quit.

This is the bare skeleton. Every other syscall in this chapter is just "fill more cups before ringing the doorbell."

## Build and run

```bash
as -o demo.o 01_calling_convention.s
ld -o demo demo.o
./demo
echo $?
# => 0
```

If `echo $?` prints `0`, the program exited cleanly. There's no visible output because we never asked the kernel to write anything to the screen — that's the next file.

## Watch it happen with `strace`

```bash
strace ./demo
```

You will see something like:

```
execve("./demo", ["./demo"], ...) = 0
getpid()                          = 12345
exit(0)                           = ?
```

Exactly two syscalls (`execve` is the kernel loading your program; it's not part of your code). `strace` is the X-ray machine for "what did this binary actually ask the kernel to do?" — keep it in your back pocket for the rest of this chapter.

## Check yourself

1. What goes into `rax` *before* `syscall`? What comes out *in* `rax` *after* `syscall`? (Answer: before — the syscall number; after — the return value, possibly negative for an error.)
2. Which register holds the 4th syscall argument? (Answer: `r10`.)
3. After `syscall`, which two general-purpose registers should you assume are trashed? (Answer: `rcx` and `r11`.)

## Next

Now that you know the form rules, let's fill out the most useful form there is — [13.2 — Writing to stdout and stderr](02_write_stdout.md).
