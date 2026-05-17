# 13.4 — Files: open, close, lseek

## A story: the coat check at a busy theater

**In plain words:** to talk to a file, your program first asks the kernel "please open this file by name and give me a ticket." From then on, you only ever wave the ticket. The name disappears from the conversation.

**The analogy.** Imagine a theater coat check. When you arrive you hand over your coat *with* a slip naming who you are, and the attendant gives you a small numbered ticket. For the rest of the night, every interaction — "please take a photo of my coat," "I'll be back later" — uses the ticket, never your name. At the end you hand the ticket back to retrieve the coat, and the attendant tears it up.

That ticket is a **file descriptor**. The first interaction (`open`) trades a name for a number. Every subsequent interaction (`read`, `write`, `lseek`) uses the number. The final interaction (`close`) returns the number; the kernel forgets your file.

## The four syscalls

| #  | Name    | Args                              | Returns                              |
| -- | ------- | --------------------------------- | ------------------------------------ |
| 2  | `open`  | `path, flags, mode`               | new fd, or `-errno`                  |
| 3  | `close` | `fd`                              | `0`, or `-errno`                     |
| 8  | `lseek` | `fd, offset, whence`              | new file position, or `-errno`       |
| 0  | `read`  | `fd, buf, count`                  | bytes read (`0` = EOF), or `-errno`  |

We already met `read` in the previous file; here it works on a regular file instead of stdin. The two new players are `open` and `close`.

### `open`

```
open(path, flags, mode) -> fd
```

| Cup    | Holds              | Meaning                                                  |
| ------ | ------------------ | -------------------------------------------------------- |
| `rax`  | `2`                | syscall number                                           |
| `rdi`  | `path`             | pointer to a **NUL-terminated** filename                 |
| `rsi`  | `flags`            | how to open: `O_RDONLY=0`, `O_WRONLY=1`, `O_RDWR=2`, …    |
| `rdx`  | `mode`             | permission bits (e.g. `0644`) — only used with `O_CREAT` |

The returned `fd` is the smallest non-negative integer not currently in use by your process. On a freshly started program, you already own 0, 1, 2 (stdin, stdout, stderr), so your first `open` typically returns `3`.

**Gotcha.** `open` expects the path to end in a zero byte (`\0`). Use `.asciz` (or `.string`) in the assembler instead of `.ascii` — `asciz` appends the trailing NUL for you. If you use `.ascii "myfile"`, the kernel keeps reading past the end of your string and treats whatever garbage is next in memory as more filename. The result is usually `ENOENT`.

### `close`

```
close(fd)
```

Just hand the ticket back. After `close`, the fd is invalid; using it again returns `-EBADF`. Always close what you open — file descriptors are a finite resource (default limit around 1024 per process), and leaks add up.

### `lseek`

```
lseek(fd, offset, whence) -> new_position
```

Every open file carries an internal **cursor** — the byte offset where the next `read` or `write` will land. `lseek` moves that cursor.

- `whence = 0` (`SEEK_SET`): set the cursor to exactly `offset`.
- `whence = 1` (`SEEK_CUR`): move the cursor by `offset` (positive or negative).
- `whence = 2` (`SEEK_END`): set the cursor to `(file_size + offset)`.

A common trick: `lseek(fd, 0, SEEK_END)` returns the file's size without reading it.

## The code

See [`04_open_close.s`](04_open_close.s):

```asm
.intel_syntax noprefix

        .equ    SYS_read,  0
        .equ    SYS_write, 1
        .equ    SYS_open,  2
        .equ    SYS_close, 3
        .equ    SYS_exit,  60
        .equ    O_RDONLY,  0

        .section .rodata
path:   .asciz  "/etc/hostname"         # NUL-terminated, as open() expects

        .section .bss
buf:    .skip   256

        .section .text
        .globl  _start
_start:
        # fd = open("/etc/hostname", O_RDONLY, 0);
        mov     rax, SYS_open
        lea     rdi, [rip + path]
        mov     rsi, O_RDONLY
        xor     rdx, rdx                # mode (ignored without O_CREAT)
        syscall

        test    rax, rax
        js      .err                    # negative -> error

        mov     r12, rax                # save fd in callee-saved register

        # n = read(fd, buf, 256);
        mov     rax, SYS_read
        mov     rdi, r12
        lea     rsi, [rip + buf]
        mov     rdx, 256
        syscall

        test    rax, rax
        jle     .close

        # write(1, buf, n);
        mov     rdx, rax
        mov     rax, SYS_write
        mov     rdi, 1
        lea     rsi, [rip + buf]
        syscall

.close:
        mov     rax, SYS_close
        mov     rdi, r12
        syscall

        mov     rax, SYS_exit
        xor     rdi, rdi
        syscall

.err:
        mov     rax, SYS_exit
        mov     rdi, 1
        syscall
```

**In plain words.** Three steps that mirror how you'd describe it to a friend: open a file, slurp some bytes out of it and dump them to the screen, close the file. Exit cleanly. If the file refuses to open, exit with status 1.

**Zooming in on `r12`.** Between `open` and `close` we make a `read` syscall. That syscall returns its result in `rax` and is allowed to clobber `rcx` and `r11`. But we need to remember the fd across the call. The cleanest place to park it is one of the **callee-saved** registers (`rbx`, `rbp`, `r12`–`r15`) — the kernel will not touch those. We picked `r12`.

**Zooming in on `.asciz "/etc/hostname"`.** The `z` matters. Compare:

- `.ascii  "/etc/hostname"`   → 13 bytes, no NUL. `open` reads past the end into whatever garbage follows. Usually fails with `ENOENT`.
- `.asciz  "/etc/hostname"`   → 14 bytes, with trailing `\0`. `open` stops at the NUL. Works.

**Zooming in on `.rodata`.** The path is constant — we never modify it — so it belongs in **`.rodata`** (read-only data). Putting it in `.data` would still work, but `.rodata` makes the intent explicit and lets the linker map it into read-only pages (so a stray write would trap loudly instead of silently corrupting the string).

## Build and run

```bash
as -o f.o 04_open_close.s
ld -o f f.o
./f
# => your-hostname
```

The program reads `/etc/hostname` (which exists on every Linux system) and prints its contents.

## Try it yourself

1. Run with `strace ./f`. You will see:

   ```
   openat(AT_FDCWD, "/etc/hostname", O_RDONLY) = 3
   read(3, "myhost\n", 256)                     = 7
   write(1, "myhost\n", 7)                      = 7
   close(3)                                     = 0
   exit(0)                                      = ?
   ```

   (Note: `strace` shows `openat` rather than `open` because newer glibc/strace render it that way, but on x86_64 the syscall number 2 is still the classic `open`.)

2. Change the path to `/etc/no-such-file`. Rebuild. Run `echo $?` — it prints `1`, because `open` returned `-ENOENT` (`-2`), the `js .err` branch fired, and we exited with status 1.

3. Add `lseek` before the `read` to skip the first 2 bytes of the file:

   ```asm
           mov     rax, 8                  # lseek
           mov     rdi, r12                # fd
           mov     rsi, 2                  # offset = 2
           xor     rdx, rdx                # SEEK_SET
           syscall
   ```

   Now your output starts at the third character of the file.

4. Forget the `close`. Run `strace ./f` again — the kernel will still tear down your fd at `exit`, because process exit closes all descriptors. But in a long-running program, leaking fds is a real bug.

## Check yourself

1. Why must the path passed to `open` be NUL-terminated? (Answer: the kernel has no length argument — it walks the bytes until it sees `\0`.)
2. Why save the fd in `r12` instead of leaving it in `rax`? (Answer: `rax` will be overwritten by the next syscall's return value; `r12` is callee-saved and survives syscalls untouched.)
3. What does `lseek(fd, 0, SEEK_END)` return? (Answer: the size of the file in bytes, because `SEEK_END` sets the cursor to `file_size + 0` and `lseek` returns the resulting position.)

## Next

You now know the four pillars: the calling convention, writing, reading, and files. Time to use them in anger. [Part 14 — Tiny Program](../14_Tiny_Program/README.md) puts them all together in a complete, real, no-libc program.
