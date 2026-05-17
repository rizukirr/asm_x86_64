# 13.2 — Writing: stdout and stderr

## A story: shouting and whispering down the hallway

**In plain words:** to put text on the screen, your program asks the kernel to copy a chunk of bytes from your memory to a "file" identified by a small ticket number. Ticket 1 means "shout it normally." Ticket 2 means "this is an error message, please route it separately."

**The analogy.** Imagine the apartment manager has two megaphones on their desk. The white one is for normal announcements. The red one is for emergencies. Both megaphones happen to be pointed out the same window (your terminal), so to a casual listener they sound identical — but the manager keeps a log of which one was used, and a careful listener can pipe the red one into a different room. The white megaphone is **file descriptor 1**, called **stdout**. The red one is **file descriptor 2**, called **stderr**.

**The technical layer.** The syscall is `write`, number 1 in the table:

```
write(fd, buf, count) -> bytes_written (or -errno)
```

Three arguments, in the usual order:

| Cup    | Holds              | Meaning                                            |
| ------ | ------------------ | -------------------------------------------------- |
| `rax`  | `1`                | syscall number for `write`                         |
| `rdi`  | `fd`               | which "file" to write to (`1` stdout, `2` stderr)  |
| `rsi`  | pointer to bytes   | the address of the buffer to send                  |
| `rdx`  | `count`            | how many bytes from that address                   |

After `syscall`, `rax` contains the number of bytes the kernel actually wrote. For a tiny `write` to a healthy terminal, this will equal what you asked for. For a write to a slow pipe or full disk, it can be smaller — a "short write." We ignore that here.

**Gotcha.** `write` writes raw bytes. It does not append a newline. If you forget the `\n` at the end of your string, the next shell prompt will appear glued to your output. This is not a bug; the kernel is doing exactly what you asked.

## The code

See [`02_write_stdout.s`](02_write_stdout.s):

```asm
.intel_syntax noprefix

        .section .data
msg1:   .ascii  "stdout: hello\n"
        .equ    msg1len, . - msg1
msg2:   .ascii  "stderr: also hello\n"
        .equ    msg2len, . - msg2

        .section .text
        .globl  _start
_start:
        mov     rax, 1                  # write
        mov     rdi, 1                  # fd 1 = stdout
        lea     rsi, [rip + msg1]
        mov     rdx, msg1len
        syscall

        mov     rax, 1                  # write
        mov     rdi, 2                  # fd 2 = stderr
        lea     rsi, [rip + msg2]
        mov     rdx, msg2len
        syscall

        mov     rax, 60                 # exit
        xor     rdi, rdi
        syscall
```

**In plain words.** Two `write` syscalls back to back — one to fd 1, one to fd 2. Then `exit(0)`. The only thing that changes between the two writes is the file descriptor and the message; the syscall number, the layout, the convention — all identical.

**Zooming in on `lea rsi, [rip + msg1]`.** This is "load effective address." It does *not* fetch the bytes at `msg1`; it computes the address of `msg1` and parks that address in `rsi`. The `[rip + msg1]` form is RIP-relative — "the location of `msg1` expressed as a distance from the current instruction." That's the modern, position-independent way to refer to a label, and it works regardless of where the operating system happened to load your program.

**Zooming in on `.equ msg1len, . - msg1`.** The dot `.` means "the address right here, right now." So `. - msg1` is "the address right after the string minus the address where it starts" — the length of the string, in bytes, computed by the assembler. Change the string, the length re-computes for free.

## Build and run

```bash
as -o w.o 02_write_stdout.s
ld -o w w.o
./w
# => stdout: hello
# => stderr: also hello
```

## Proving stderr is really a different channel

The two messages look identical when both are pointed at your terminal. But they aren't. To prove it, run with stdout redirected to a file:

```bash
./w >/tmp/out.txt
# screen shows only:  stderr: also hello
cat /tmp/out.txt
# => stdout: hello
```

The white megaphone (stdout) was redirected into a file. The red megaphone (stderr) kept shouting at the screen. That's why errors are conventionally written to fd 2: when someone redirects your program's normal output to a log, they still want to see complaints.

## Try it yourself

1. Change `msg1` to `"Hi.\n"`. Notice that `msg1len` recomputes automatically — that's what `. - msg1` bought you.
2. Remove the `\n` from `msg1`. Rebuild. Run. Watch your shell prompt glue itself to the output. This is the lesson: `write` writes exactly what you tell it to.
3. Run `strace -e write ./w`. You'll see your two `write` syscalls with the exact arguments, the bytes, and the return values.

## Check yourself

1. Which register selects between stdout and stderr? (Answer: `rdi`.)
2. What does `rax` contain *after* a `write` call? (Answer: the number of bytes actually written, or a negative errno.)
3. Why is the message in `.data` and not `.text`? (Answer: `.text` is read-only and executable; `.data` is read/write. We never execute the string, we just read it as data.)

## Next

Writing was the easy half. Now flip the arrows: [13.3 — Reading from stdin](03_read_stdin.md).
