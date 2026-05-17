# 07.01 — The Stack as a Tray Pile

## A story: the cafeteria tray dispenser

**In plain words:** the **stack** is a chunk of memory the CPU uses as scratch space. New values go **on top**; values come back **off the top**. Last in, first out.

**The analogy.** Picture the spring-loaded tray dispenser in a cafeteria. When a cook brings a clean tray over, they press it down onto the pile — the pile sinks a little, the new tray sits on top. When a hungry student grabs a tray, they pull the top one off and the pile springs up a little. Nobody ever digs into the middle. Only the top is reachable.

That's the stack. The cooks and students are **your instructions** (`push`, `pop`, `call`, `ret`). The pile of trays is **memory**. The hand that's always touching the top tray is a special register called **`rsp`** — the "stack pointer."

**The technical layer.** When Linux loads your program, the kernel:

1. Picks a large block of memory (typically 8 megabytes).
2. Sets `rsp` to point **near the top** of that block.
3. Hands control to `_start`.

From that moment on, anything you push lands at a memory address *lower* than where `rsp` was pointing. Then `rsp` is updated to point at the new top. The stack **grows downward** in memory.

**Gotcha — "down" is just convention.** A stack could grow either way. On x86_64 Linux it grows downward, and the `push`/`pop` instructions are hard-wired to that direction. Don't fight it; just remember: **push lowers `rsp`, pop raises `rsp`.**

## Why does the stack exist?

**In plain words:** the CPU only has a small handful of named cups (registers) on its desk. When the worker needs to step away to do another task, it can't carry every cup along. So before stepping away, it stacks up the cup contents on a pile in the warehouse, does the other task, and pulls them back off when it returns.

That's the most common use. Other uses we'll meet later:

- **Function calls** — when you `call` somewhere, the CPU automatically pushes the "come back to here" address onto the stack.
- **Local variables** — a function carves out scratch room on the stack for its own variables.
- **Saving registers across noisy work** — you stash a register's value so you can reuse the cup.

## Vocabulary check

- **Stack** — a region of memory used last-in-first-out.
- **`rsp`** — the cup on the desk that always points at the current top of the stack. Short for "Stack Pointer."
- **`push`** — put a new value on top. `rsp` goes **down** by 8.
- **`pop`** — take the top value off. `rsp` goes **up** by 8.
- **Stack frame** — the chunk of stack that belongs to one function call. Covered in topic 03.
- **Alignment** — the rule that `rsp` must be a multiple of 16 at certain moments. Covered in topic 04.

## A map of where the stack lives

```
high addresses
    +----------------+
    |   argv/envp    |   <- the kernel parked program arguments
    |   ...          |      and environment variables up here
    +----------------+   <- rsp at the very start of _start
    |   free space   |
    |       ↓        |      future pushes will land here
    |                |
    +----------------+
low addresses
```

When `_start` begins running, `rsp` is somewhere in the middle of the picture. Everything above it (program arguments, environment variables) is set up by the kernel and belongs to your program too — but you don't usually touch it directly. Everything below it is yours to scribble on with `push`, `pop`, or by writing directly through `[rsp]`.

## Look at it for yourself

Let's print the actual value of `rsp` at program start. The number will be different every run (Linux randomizes it for security — a feature called **ASLR**, address space layout randomization), but it will always be a giant 48-bit hexadecimal number somewhere up in the user-space stack region.

See [`01_stack_basics.s`](01_stack_basics.s):

```asm
.intel_syntax noprefix

        .section .bss
buf:    .skip   32                      # scratch space for the printed string

        .section .data
prefix: .ascii  "rsp = 0x"
        .equ    prefix_len, . - prefix
nl:     .ascii  "\n"

        .section .text
        .globl  _start
_start:
        mov     rax, rsp                # snapshot rsp before we touch it
        ...
```

**In plain words.** We copy `rsp` into `rax`, then loop sixteen times. Each iteration rotates the top 4 bits of `rax` down into the bottom 4 bits, masks off the rest, turns the nibble into the ASCII character `'0'..'9'` or `'a'..'f'`, and stores it into a 16-byte buffer. Then we make three `write` syscalls (prefix, hex digits, newline) and exit.

The clever instruction is **`rol rax, 4`** — "rotate `rax` left by 4 bits." Bits that fall off the top come back in at the bottom. By repeatedly rotating left by 4, we walk through the 16 nibbles of the 64-bit value from most-significant to least-significant. After 16 rotations, `rax` is back to its original value.

## Build and run

```bash
as -o /tmp/01.o 01_stack_basics.s
ld -o /tmp/01    /tmp/01.o
/tmp/01
```

You'll see something like:

```
rsp = 0x00007fff1ba905b0
```

The exact number will differ every run. But two things will always be true:

1. **It's huge.** Numbers like `0x7fff...` mean the stack lives near the top of the 48-bit user-space address range.
2. **It ends in a small number.** Usually `0x0`, sometimes `0x8`. That's not an accident — see topic 04 on alignment.

**Try it.** Run the program three times. Compare the addresses. They differ in the middle bits — that's ASLR. The end nibble stays in `{0, 8}` because the kernel sets `rsp` 16-byte aligned, and the program does no pushes before measuring.

## Gotcha — the CPU does not check stack bounds

**In plain words:** if you keep `pop`-ing past where you `push`-ed, `rsp` will silently walk up into the kernel-supplied environment area, and then past it into nothing at all. The CPU does **not** raise an alarm. The next time something touches `[rsp]` it'll crash — but the error message won't say "stack underflow." It'll say `SIGSEGV` and you'll have to figure out why.

Keeping pushes and pops balanced is **your** responsibility. Topic 02 dives into that.

## Check yourself

1. **If `rsp` started at `0x7fff1ba905b0` and you executed two `push` instructions, what would `rsp` be?**
   *Answer: `0x7fff1ba905a0` (subtract 16 — two pushes of 8 bytes each).*

2. **If a friend says "the stack overflowed," in which direction did `rsp` go?**
   *Answer: down, toward lower addresses. "Overflow" here means the stack grew past the bottom of the allocated 8 MB region.*

3. **Why doesn't the CPU stop you from `pop`-ing more than you pushed?**
   *Answer: the CPU has no concept of "your stack." It just executes the instruction `add rsp, 8` and trusts you. The crash happens later, when some other code reads through a now-bogus `rsp`.*

## Next

Now that you know what `rsp` is and which way the stack grows, [`02_push_pop.md`](02_push_pop.md) breaks down what `push` and `pop` actually do, byte by byte.
