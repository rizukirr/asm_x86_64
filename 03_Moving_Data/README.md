# Part 03 — Moving Data

## A story: a photocopier, not a shipping truck

Imagine you have a sheet of paper on your desk with a number written on it. You want that same number on a different piece of paper.

You don't pick up the original and *carry* it to the other paper — that would leave the first spot empty. Instead, you put the original on a **photocopier**, press the button, and stick the copy onto the second sheet. Now both sheets have the number. Nothing was destroyed; the original is untouched.

That's what the `mov` instruction does. The name is misleading — `mov` doesn't *move* anything in the strict sense. It **copies**. The source is unchanged; the destination becomes a duplicate.

If assembly had a favorite verb, it would be `mov`. Roughly half of the instructions in a real program are `mov` (or one of its close cousins). Getting comfortable with `mov` is most of what it takes to read assembly fluently.

## The shape of `mov`

```
mov  dst, src
```

`dst` is the **destination** (where the copy lands) and `src` is the **source** (where the original lives). Remember: Intel syntax puts the destination first. Like writing a check — payee first, amount second.

`dst` and `src` are called **operands**. An operand can be one of three kinds of thing:

- A **register** — one of the 16 cups on the CPU's desk (e.g., `rax`).
- An **immediate** — a constant number written right there in the instruction (e.g., `42`). "Immediate" means "the value is right here, no lookup needed."
- A **memory reference** — a shelf address in the warehouse, written in square brackets (e.g., `[rbx + 8]`, meaning "the shelf whose number is whatever's in `rbx`, plus 8").

The CPU only allows certain combinations of these:

| `dst`    | `src`    | Allowed? | Notes                                        |
| -------- | -------- | -------- | -------------------------------------------- |
| register | register | yes      | Both must be the same size                   |
| register | immediate| yes      |                                              |
| register | memory   | yes      | A **load** (fetch from warehouse to cup)     |
| memory   | register | yes      | A **store** (put cup contents onto a shelf)  |
| memory   | immediate| yes      |                                              |
| memory   | memory   | no       | Two memory operands per instruction: forbidden|

That last rule is the one beginners trip on. You **cannot** copy from one shelf directly to another shelf in a single instruction. To copy memory to memory, you must go through a register — fetch into a cup, then drop the cup's contents onto the other shelf:

```asm
mov     rax, [src]
mov     [dst], rax
```

**What this actually does, in plain words:** "Fetch 8 bytes from the shelf labeled `src` and put them in cup `rax`. Then take what's in `rax` and stamp it onto the shelf labeled `dst`."

## Operand sizes

The size of a move (how many bytes get copied) is determined by the **register** involved, or by an explicit **size hint** when there's no register to give the size away:

```asm
mov     rax, 1                  # 64-bit move
mov     eax, 1                  # 32-bit move (zero-extends to rax!)
mov     ax,  1                  # 16-bit move
mov     al,  1                  # 8-bit move

mov     qword ptr [rbx], 1      # 8 bytes of memory get 0x0000000000000001
mov     dword ptr [rbx], 1      # 4 bytes
mov     word  ptr [rbx], 1      # 2 bytes
mov     byte  ptr [rbx], 1      # 1 byte
```

**What this actually does, in plain words:** the top four lines write the number 1 into various-sized chunks of cup `rax`. The bottom four lines write the number 1 into 8, 4, 2, or 1 bytes of memory at the address held in `rbx`. The `qword ptr` part is the assembler's way of asking, "How many bytes are we writing? You have to tell me, because just looking at `[rbx]` and `1` I can't tell."

The `qword ptr` etc. is needed when the assembler can't figure out the size from the operands alone — typically when storing an immediate (a bare number) into memory. If you write `mov [rbx], 1`, the assembler doesn't know whether you mean 1 byte, 2 bytes, 4 bytes, or 8 bytes — they're all valid encodings — so it complains.

Name table — translating between x86 size words and the sizes you might know from other languages:

| Size    | x86 name | C-ish equivalent |
| ------- | -------- | ---------------- |
| 1 byte  | byte     | `int8_t`         |
| 2 bytes | word     | `int16_t`        |
| 4 bytes | dword    | `int32_t`        |
| 8 bytes | qword    | `int64_t`        |

(Historical quirk: "word" was 16 bits on the original 8086, and the name froze. A "double word" is 32, a "quad word" is 64. So an x86 "word" is *not* the same as a "machine word" in other contexts. Yet another archaeology layer.)

## Immediates: how big?

`mov reg, imm` encodes the immediate (constant) value **inline** in the instruction bytes — that is, the number is baked right into the recipe page. For most sizes, the immediate is the same number of bytes as the destination, with one exception:

```asm
mov     rax, 1                  # actually mov eax, 1 (5 bytes)
mov     rax, 0xFFFFFFFFFFFFFFFF # full 10-byte form, needed for 64-bit imm
```

**What this actually does, in plain words:** when you write `mov rax, 1`, the assembler quietly notices that "1" fits in 32 bits, and rewrites the instruction as `mov eax, 1` — which is shorter in bytes and produces the exact same result (because, remember from Part 02, writing to `eax` zero-extends the top half of `rax` to zero). Only when the constant truly doesn't fit in 32 bits do you get the long 10-byte form (sometimes called `movabs`).

## Sign-extension and zero-extension

Suppose cup `ebx` holds the value `0xFFFFFFFF`. That number is *also* the way you'd write `-1` as a 32-bit signed integer, or `4294967295` as an unsigned one. (The CPU doesn't know which interpretation you want — it just stores bits.)

What happens if you want to take those 32 bits and put them into the full 64-bit `rax`? You have a choice: do you fill the new top bits with zeros (treating the source as unsigned, i.e. positive), or do you fill them with copies of the top bit (preserving its meaning as a signed number, which might be negative)?

Two explicit instructions exist:

```asm
movzx   rax, bl                 # zero-extend  bl  -> rax   (8 -> 64)
movzx   rax, bx                 # zero-extend  bx  -> rax   (16 -> 64)
movsx   rax, bl                 # sign-extend  bl  -> rax
movsx   rax, bx                 # sign-extend  bx  -> rax
movsxd  rax, ebx                # sign-extend  ebx -> rax   (32 -> 64)
```

`movzx` = "move with zero-extend." `movsx` = "move with sign-extend." `movsxd` = the 32-to-64 version of sign-extend (the `d` means "doubleword source").

There is no `movzxd` — you don't need it, because (remember!) **writing to a 32-bit register already zero-extends automatically**. Just `mov eax, ebx` does the job for free.

| Source byte | `movzx rax, bl` | `movsx rax, bl` |
| ----------- | --------------- | --------------- |
| `0x7F`      | `0x000000000000007F` | `0x000000000000007F` |
| `0x80`      | `0x0000000000000080` | `0xFFFFFFFFFFFFFF80` |
| `0xFF`      | `0x00000000000000FF` | `0xFFFFFFFFFFFFFFFF` |

Walking through the table: `0x7F` is `01111111` in binary — top bit is 0, so it's positive either way; the result is the same. `0x80` is `10000000` — top bit is 1. With `movzx`, the new high bits are all 0. With `movsx`, the new high bits are all 1 (copies of that top bit), giving the bit pattern for `-128` as a 64-bit signed number. Same for `0xFF` (which is `-1` signed): zero-extend gives `255`, sign-extend gives `-1`.

The rule: **sign-extension copies the top bit of the source to fill the new high bits.** Use it for signed integer widening; use `movzx` for unsigned.

## Memory operands: a teaser

```asm
mov     rax, [rbx]                      # load 8 bytes from address in rbx
mov     rax, [rbx + 16]                 # load from rbx+16
mov     rax, [rbx + rcx*8]              # load from rbx + rcx*8 (array index!)
mov     rax, [rbx + rcx*8 + 16]
```

**What this actually does, in plain words:**
- Line 1: "Go to shelf number `rbx`, grab 8 bytes, drop in `rax`."
- Line 2: "Go to shelf number `rbx + 16` (16 shelves to the right of `rbx`), grab 8 bytes." This is how you reach a field inside a struct.
- Line 3: "Go to shelf number `rbx + rcx*8`." If `rbx` is the start of an array of 8-byte numbers and `rcx` is the index, this fetches `array[rcx]`.
- Line 4: a combination — start address `rbx`, plus index `rcx` scaled by 8, plus offset 16.

That last form is the **full effective address**: `[base + index*scale + displacement]`, where `scale` can only be 1, 2, 4, or 8 (the legal sizes of array elements). Every memory access uses some specialization of this one shape. We dedicate [Part 06](../06_Addressing/README.md) to it.

## `mov` is not the only mover

A few common cousins of `mov`:

| Instruction | What it does                                                |
| ----------- | ----------------------------------------------------------- |
| `xchg a, b` | **Exchange.** Atomic swap of two values. Surprisingly slow on modern CPUs; rarely used outside locks.  |
| `lea r, [m]`| **Load Effective Address.** Compute the address but don't dereference (don't go fetch). Often used as a sneaky way to do math, since `[a + b*4 + 8]` is a free calculation. We treat it as math in [Part 06](../06_Addressing/README.md). |
| `push r`   | **Push onto the stack** (a special scratch area we'll cover in [Part 07](../07_The_Stack/README.md)). |
| `pop  r`   | **Pop from the stack** — undo the matching `push`. |
| `cmov??`    | **Conditional move** — copy *only if* a flag condition holds. Replaces some `if` branches with branch-free code. |

## A worked example

```asm
.intel_syntax noprefix
        .section .data
val:    .quad   0x1122334455667788

        .section .text
        .globl  _start
_start:
        # Load 8 bytes from `val` into rax
        mov     rax, [rip + val]

        # Replace just the low byte
        mov     al, 0xAA

        # Store the modified value back
        mov     [rip + val], rax

        # Exit
        mov     rax, 60
        xor     rdi, rdi
        syscall
```

**What this actually does, in plain words:**

1. In the pantry (`.data` section), set up a shelf labeled `val` that contains the 8-byte number `0x1122334455667788`. (`.quad` means "make an 8-byte slot here with this initial value.")
2. In the recipe book (`.text` section), do this:
3. Fetch the 8 bytes from `val` into cup `rax`. Now `rax` = `0x1122334455667788`.
4. Overwrite just the lowest byte of `rax` with `0xAA`. Now `rax` = `0x11223344556677AA`. (Remember from Part 02: writing to `al` only touches the bottom byte.)
5. Put the new value of `rax` back onto the shelf at `val`. The shelf now reads `0x11223344556677AA`.
6. Slide the "exit" form under the door.

Build it and inspect `val` before and after:

```bash
as -o mov.o mov.s && ld -o mov mov.o
gdb ./mov
(gdb) starti
(gdb) x/gx &val               # 64-bit hex view of val
(gdb) si                      # step
```

The `gdb` command `x/gx &val` means "examine memory at the address of `val`, formatted as a giant hex number." `g` = "giant" (8 bytes), `x` = "hex." Run it before and after each `si` to watch `val` change.

## Try it

1. Predict what `[rip + val]` contains after each instruction. Verify with gdb.
2. Change `mov al, 0xAA` to `mov eax, 0xAA`. Predict — and verify — that the top 32 bits of `rax` (and therefore the upper half of `val` after the store) become zero. (The Part 02 rule strikes again.)
3. Try `mov dword ptr [rbx], 1` without the `dword ptr`. The assembler errors: "operand size mismatch." Now you know why size hints exist.

## What's next

We can copy bits. Time to do something with them. [Part 04](../04_Arithmetic/README.md) covers integer arithmetic — `add`, `sub`, `imul`, `idiv`, and the flags that record what happened.
