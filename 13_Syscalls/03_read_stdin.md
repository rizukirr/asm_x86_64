# 13.3 — Reading from stdin

## A story: the suggestion box

**In plain words:** to read input, your program hands the kernel an empty box and says "fill this with whatever's waiting on stdin, up to N bytes." The kernel writes the bytes in, then tells you how many it actually wrote.

**The analogy.** Imagine you've nailed a wooden suggestion box to your apartment door. Every so often someone slips a note through the slot. When you want to know what's in the box, you can't peek; you have to ask the building manager. You hand the manager an empty envelope, say "fit up to 128 letters in here," and the manager either:

1. Pulls some notes out of the box, stuffs them in the envelope, and tells you "I put 17 letters in" (a normal read).
2. Tells you "the box is empty and the slot has been welded shut" — they return zero (**end-of-file**, EOF).
3. Reports a problem ("the box is on fire") — a negative errno.

That suggestion box is **file descriptor 0**, **stdin**.

**The technical layer.** The syscall is `read`, number 0:

```
read(fd, buf, count) -> bytes_read (or 0 = EOF, or -errno)
```

| Cup    | Holds              | Meaning                                |
| ------ | ------------------ | -------------------------------------- |
| `rax`  | `0`                | syscall number for `read`              |
| `rdi`  | `fd`               | which fd to read from (`0` for stdin)  |
| `rsi`  | pointer to buffer  | where to put the bytes                 |
| `rdx`  | `count`            | maximum bytes to read                  |

**Gotcha.** A `read` of zero bytes is not an error — it means **EOF**, end of file. The other side closed the stream. Your loop must stop. Treating `0` as "try again" is how programs spin forever.

**Gotcha #2.** A `read` can return *fewer* bytes than you asked for, even if there's more data coming. This is a "short read." Real programs loop until they've gathered what they need; a one-shot demo like ours just uses whatever came back.

## The blocking trap

**In plain words:** if the suggestion box is empty but the slot is still open, the manager **does not return**. They sit there waiting for the next note. Your program is frozen until somebody types something — or until you tell the shell to feed input from somewhere else.

This is why a naive `read` from stdin will *hang* if you run it without input. To make our demo verifiable (and not hang any CI loop), we will redirect stdin from `/dev/null` when we run it. `/dev/null` is a special file that is always immediately at EOF — so `read` returns `0` instantly instead of waiting.

```bash
./demo </dev/null      # safe -- read returns 0, program handles it
```

## The code

See [`03_read_stdin.s`](03_read_stdin.s):

```asm
.intel_syntax noprefix

        .section .data
empty:  .ascii  "(no input on stdin)\n"
        .equ    emptylen, . - empty

        .section .bss
buf:    .skip   128

        .section .text
        .globl  _start
_start:
        # n = read(0, buf, 128);
        xor     rax, rax                # 0 = read
        xor     rdi, rdi                # fd 0 = stdin
        lea     rsi, [rip + buf]
        mov     rdx, 128
        syscall

        # if (n <= 0) goto .empty
        test    rax, rax
        jle     .empty

        # write(1, buf, n);
        mov     rdx, rax                # count = bytes read
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + buf]
        syscall
        jmp     .done

.empty:
        # write(2, empty, emptylen);
        mov     rax, 1
        mov     rdi, 2
        lea     rsi, [rip + empty]
        mov     rdx, emptylen
        syscall

.done:
        mov     rax, 60                 # exit
        xor     rdi, rdi
        syscall
```

**In plain words.** Reserve a 128-byte landing pad called `buf` in the `.bss` section. Ask the kernel to read up to 128 bytes from stdin into that pad. Look at the return value:

- `> 0` → echo exactly those bytes back to stdout, then exit.
- `0` (EOF) or negative (error) → print a friendly "(no input on stdin)" message to stderr, then exit.

**Zooming in on `.bss`.** `.bss` stands for "block started by symbol" — a name from the 1950s, nobody likes it. The thing it does is useful: any space you `.skip` here is reserved at runtime and pre-filled with zeros, but **none of those zero bytes are stored on disk**. The OS creates and zeros the memory when your program loads. Free real estate for buffers and zero-initialized globals.

**Zooming in on `test rax, rax` + `jle`.** `test rax, rax` computes `rax AND rax` and sets the flags but discards the result. `jle` means "jump if less-or-equal" — taken when the previous result was negative or zero. Equivalent to "either we had an error OR we hit EOF; either way, no bytes to echo."

**Zooming in on `mov rdx, rax`.** Right after `read`, `rax` holds the number of bytes read. We move it into `rdx` so the upcoming `write` knows exactly that many bytes to send. This is the bridge: the kernel told us the count, and we pass that count straight to the next syscall.

## Build and run

The safe way (won't hang):

```bash
as -o r.o 03_read_stdin.s
ld -o r r.o
./r </dev/null
# => (no input on stdin)         -- printed to stderr

echo "hello world" | ./r
# => hello world
```

The interactive way (will block on keyboard until you type and press Ctrl-D for EOF):

```bash
./r
# you type:  hi<Enter>
# then press Ctrl-D
# => hi
```

## Try it yourself

1. Feed it a file: `./r < some_text.txt`. Notice it echoes only the first 128 bytes — that's the buffer size.
2. Run `strace -e read,write ./r </dev/null`. You'll see one `read(0, ..., 128) = 0` and one `write(2, "(no input on stdin)\n", 20)`.
3. Bump the buffer from 128 to 4096 by changing the `.skip` and the `mov rdx, 128`. Now larger inputs come through in one read.
4. Change `xor rdi, rdi` (which makes `rdi = 0`) to `mov rdi, 99`. Rebuild. Run with `</dev/null`. The read returns `-9` (`EBADF`, "bad file descriptor"); our code treats that as the empty path and prints the stderr message. Watch with `strace`.

## Check yourself

1. What does `read` return when the other side has closed stdin? (Answer: `0` — EOF.)
2. Why do we redirect from `/dev/null` in the verification command? (Answer: so `read` returns immediately at EOF instead of blocking forever waiting for keyboard input.)
3. After a successful `read`, which register holds the byte count, and where does it need to move next? (Answer: it's in `rax`; we copy it to `rdx` for the follow-up `write`.)

## Next

Reading and writing the pre-issued descriptors (0, 1, 2) is the easy case. To talk to *files*, you have to open them first: [13.4 — Files: open, close, lseek](04_open_close.md).
