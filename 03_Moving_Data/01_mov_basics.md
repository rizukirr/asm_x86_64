# 03.1 — `mov`: the photocopier

## A story: copying a phone number from a sticky note

**In plain words:** `mov` doesn't actually *move* anything. It **copies**. The source is untouched; the destination becomes a duplicate.

**The analogy.** You have a sticky note on your fridge with a phone number. You want that same number on a card in your wallet. You don't peel the sticky note off and stuff it in your wallet — that would leave the fridge blank. You **read** the sticky note and **write** the same digits onto the wallet card. Now both places have the number. Nothing was destroyed.

That's `mov`. The misleading name is one of assembly's oldest pranks. If half the world had voted, the instruction would be called `cpy`.

**The technical layer.** If assembly had a favorite verb, it would be `mov`. Roughly half the instructions in a real program are `mov` or one of its close cousins. Getting comfortable with `mov` is most of what it takes to read assembly fluently.

## The shape of the instruction

```
mov  dst, src
```

**In plain words:** put the value of `src` into `dst`. Destination first — Intel order. Like writing a check: payee first, amount second.

`dst` and `src` are called **operands**. An operand is one of three kinds of thing:

- A **register** — one of the 16 cups on the CPU's desk (e.g., `rax`).
- An **immediate** — a constant number written right there in the instruction (e.g., `42`). "Immediate" means "the value is right here in the recipe page, no lookup needed."
- A **memory reference** — a shelf address in the warehouse, written in square brackets (e.g., `[rbx + 8]`, meaning "the shelf whose number is whatever is in `rbx`, plus 8").

## The allowed combinations

The CPU only allows certain pairings:

| `dst`    | `src`      | Allowed? | Notes                                          |
| -------- | ---------- | -------- | ---------------------------------------------- |
| register | register   | yes      | Both must be the same size                     |
| register | immediate  | yes      |                                                |
| register | memory     | yes      | A **load** (fetch from warehouse into a cup)   |
| memory   | register   | yes      | A **store** (stamp cup contents onto a shelf)  |
| memory   | immediate  | yes      | Needs a size hint (see below)                  |
| memory   | memory     | **no**   | Two memory operands per instruction: forbidden |

**Gotcha.** That last rule trips up every beginner. You cannot copy from one shelf directly to another shelf in a single `mov`. To move memory to memory, you have to bounce through a register:

```asm
mov     rax, [src_addr]     # load:  shelf -> cup
mov     [dst_addr], rax     # store: cup  -> shelf
```

**In plain words.** "Fetch 8 bytes from the shelf at `src_addr` into cup `rax`. Then stamp `rax`'s contents onto the shelf at `dst_addr`."

## Operand sizes

**In plain words:** how many bytes does a single `mov` copy? Whatever size the register tells it.

```asm
mov     rax, 1      # 64-bit move: 8 bytes
mov     eax, 1      # 32-bit move: 4 bytes (and zero-extends the top!)
mov     ax,  1      # 16-bit move: 2 bytes
mov     al,  1      # 8-bit move:  1 byte
```

**The technical layer.** The register name picks the width. `rax` = 8 bytes, `eax` = low 4 bytes, `ax` = low 2 bytes, `al` = lowest 1 byte. (Recap of Part 02. If this still feels foggy, re-read it before moving on.)

**Gotcha.** The 32-bit form `mov eax, 1` has a hidden side effect: it **zero-extends** into the upper 32 bits of `rax`. So after `mov eax, 1`, `rax` is exactly `0x0000000000000001`. This does **not** happen for 16-bit (`ax`) or 8-bit (`al`) writes — those leave the upper bits alone. You'll see compilers exploit the 32-bit free zero-extend constantly.

### Size hints for memory-immediate stores

When you store a bare number into memory, the assembler can't tell how big the store should be:

```asm
mov     [rbx], 1        # how many bytes?? 1? 2? 4? 8?
```

Both `mov byte ptr [rbx], 1` and `mov qword ptr [rbx], 1` are legal instructions that do **different things**. So the assembler refuses to guess and you have to spell it out:

```asm
mov     byte  ptr [rbx], 1      # write 1 byte
mov     word  ptr [rbx], 1      # write 2 bytes
mov     dword ptr [rbx], 1      # write 4 bytes
mov     qword ptr [rbx], 1      # write 8 bytes
```

**The technical layer — the size word table.** "word" was 16 bits on the original 8086 in 1978, and the name froze in place forever. A "double word" is 32, a "quad word" is 64. So an x86 "word" is *not* the same as the "machine word" you might hear about elsewhere. Yet another layer of archaeology.

| Size    | x86 name | C-ish equivalent |
| ------- | -------- | ---------------- |
| 1 byte  | byte     | `int8_t`         |
| 2 bytes | word     | `int16_t`        |
| 4 bytes | dword    | `int32_t`        |
| 8 bytes | qword    | `int64_t`        |

When at least one operand is a sized register, the size hint is redundant and you can drop it. The assembler reads `mov [rbx], rax` and knows "rax is 8 bytes, so this is a qword store."

## A worked example

See [`01_mov_basics.s`](01_mov_basics.s):

```asm
.intel_syntax noprefix

        .section .data
val:    .quad   0x1122334455667788
out:    .ascii  "rax low byte was replaced with 0xAA\n"
        .equ    outlen, . - out

        .section .text
        .globl  _start
_start:
        mov     rax, 0x1122334455667788     # register <- immediate
        mov     rbx, [rip + val]            # register <- memory  (load)
        mov     bl,  0xAA                   # partial-register write
        mov     [rip + val], rbx            # memory <- register  (store)
        mov     qword ptr [rip + val], 0    # memory <- immediate (size hint!)

        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + out]
        mov     rdx, outlen
        syscall

        mov     rax, 60
        xor     rdi, rdi
        syscall
```

**In plain words, step by step:**

1. `.quad` carves out an 8-byte slot called `val` in the pantry, pre-filled with `0x1122334455667788`.
2. `mov rax, 0x...` writes the 64-bit immediate into `rax`.
3. `mov rbx, [rip + val]` is a **load**: go to the shelf labeled `val`, grab the 8 bytes, drop them in cup `rbx`. (The `[rip + val]` is **RIP-relative** addressing — covered in detail in Part 06. For now read it as "the address of `val`.")
4. `mov bl, 0xAA` overwrites **only the low byte** of `rbx`. The other 7 bytes of `rbx` are untouched. So `rbx` becomes `0x11223344556677AA`.
5. `mov [rip + val], rbx` is a **store**: stamp the 8 bytes of `rbx` onto the shelf at `val`.
6. `mov qword ptr [rip + val], 0` writes 8 zero bytes into `val`. The size hint `qword ptr` is mandatory because the source `0` is an immediate.
7. The remaining instructions print a message and exit.

## Build and run

```bash
as -o 01_mov_basics.o 01_mov_basics.s
ld -o 01_mov_basics 01_mov_basics.o
./01_mov_basics
# => rax low byte was replaced with 0xAA
```

## Watch it in gdb

```bash
gdb ./01_mov_basics
(gdb) starti
(gdb) x/gx &val          # examine val before any instruction runs
(gdb) si                 # step one instruction
(gdb) info registers rbx
(gdb) x/gx &val          # re-examine val after each step
```

**In plain words.** `x/gx &val` means "examine memory at the address of `val`, formatted as a **g**iant (8-byte) he**x** number." Stepping with `si` and re-running `x/gx &val` after each step shows the shelf's contents change in real time.

## Check yourself

1. Predict what `rbx` and `val` hold after each of the five `mov` instructions in the demo. Verify with `gdb`.
2. Change `mov bl, 0xAA` to `mov eax, 0xAA`. What happens to `rbx`? (Answer: nothing — we wrote `eax`, which is a different cup. But `rax` is now `0x00000000000000AA` — the 32-bit write zero-extended.)
3. Delete the word `qword` from `mov qword ptr [rip + val], 0`. Try to build. The assembler says: `Error: ambiguous operand size for "mov"`. Now you know exactly why size hints exist.

## What's next

`mov` copies same-size bits faithfully. But what if the source is smaller than the destination — say, an 8-bit byte you want in a 64-bit register? Do you pad the new high bits with zeros, or with copies of the sign bit? That's [03.2 — extension](02_extension.md).
