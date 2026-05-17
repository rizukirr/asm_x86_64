# 04 — Size Suffixes: `BYTE PTR`, `WORD PTR`, `DWORD PTR`, `QWORD PTR`

## A story: how big a bite?

**In plain words:** memory addresses are just shelf numbers, but each shelf holds only one byte. When you read or write *at* an address, you also have to say *how many shelves in a row* you mean — 1, 2, 4, or 8. Usually the register you're using tells the assembler that. But sometimes there's no register, and you have to spell it out with `BYTE PTR`, `WORD PTR`, `DWORD PTR`, or `QWORD PTR`.

**The analogy.** Imagine you ask the warehouse worker, "go to shelf 47 and grab... uh, some stuff." The worker pauses: "How much stuff? One box? Two? Four? Eight?" If you said `mov al, [shelf]`, the worker knows: `al` is 1 byte, grab 1 byte. If you said `mov rax, [shelf]`, that's 8 bytes. But if you said `mov [shelf], 1`, the worker is stuck — the destination is just memory, the source is just a number, and neither tells anyone the size. So you have to write `mov BYTE PTR [shelf], 1` or `mov DWORD PTR [shelf], 1` to clear it up.

**The technical layer.** The four sizes you'll see:

| Keyword     | Size in bytes | Equivalent register width | Old name |
| ----------- | ------------- | ------------------------- | -------- |
| `BYTE PTR`  | 1             | `al`, `bl`, ...           | byte     |
| `WORD PTR`  | 2             | `ax`, `bx`, ...           | word     |
| `DWORD PTR` | 4             | `eax`, `ebx`, ...         | double word |
| `QWORD PTR` | 8             | `rax`, `rbx`, ...         | quad word |

The names "word," "double word," "quad word" are historical: on the original Intel 8086 (1978), a "word" was 16 bits = 2 bytes. The names stuck even as the chip widened. So a 4-byte value is forever a "double word," abbreviated `DWORD`.

**Gotcha.** Common modern languages use "word" loosely to mean "machine register size" (often 8 bytes today). In x86 assembly, **`WORD` always means 2 bytes**, never anything else. Don't let your C/Rust intuitions trick you here.

**Check yourself.** Why is `mov [rax], 1` ambiguous, but `mov [rax], bl` is not? (Answer: in the second form, the source `bl` is a 1-byte register, so the assembler knows the destination must also be 1 byte. In the first form, the literal `1` could be 1, 2, 4, or 8 bytes wide. You have to disambiguate.)

## When you must spell it out

There are three common situations:

1. **Storing a literal to memory:** `mov [addr], 42` — the assembler has no idea how many bytes you want. Required: `mov BYTE PTR [addr], 42`.
2. **Mixing widths through a `movzx` or `movsx`:** `movzx eax, BYTE PTR [addr]` makes it explicit that the source is 1 byte and gets zero-extended into the 32-bit `eax`.
3. **Comparing memory to a literal:** `cmp [addr], 0` — same problem. Use `cmp DWORD PTR [addr], 0`.

If a register operand is present *and* it has a known width, the assembler will usually infer the memory operand's size and you can drop the keyword. But spelling it out always works, and is often clearer to future-you.

## The example program

See [`04_size_suffixes.s`](04_size_suffixes.s). It writes four different widths to four different shelves, then reads them back into the matching register widths.

```asm
.intel_syntax noprefix

        .section .data
bytebuf:  .byte 0
wordbuf:  .word 0
dwordbuf: .long 0
qwordbuf: .quad 0

        .section .text
        .globl  _start
_start:
        # Stores -- size keyword required because the source is a literal.
        mov     BYTE PTR  [rip + bytebuf],  0x7F
        mov     WORD PTR  [rip + wordbuf],  0x1234
        mov     DWORD PTR [rip + dwordbuf], 0xDEADBEEF
        mov     QWORD PTR [rip + qwordbuf], 0x11

        # Loads back into matching widths.
        movzx   eax, BYTE PTR  [rip + bytebuf]    # eax = 0x7F
        movzx   ecx, WORD PTR  [rip + wordbuf]    # ecx = 0x1234
        mov     edx,           [rip + dwordbuf]   # size from edx (4 bytes)
        mov     rsi, QWORD PTR [rip + qwordbuf]   # rsi = 0x11

        mov     rdi, rsi                # exit code = 0x11 = 17
        mov     rax, 60
        syscall
```

**In plain words.**

- The `.section .data` block reserves four labeled buffers of different widths using `.byte`, `.word`, `.long`, and `.quad` (assembler directives for 1/2/4/8 bytes).
- Each `mov` with a literal source has an explicit `PTR` keyword. Without it, the assembler refuses.
- `movzx` ("move with zero-extend") loads a smaller value into a wider register, padding the upper bits with zeros. We use it here to be safe.
- The final `mov edx, [rip + dwordbuf]` drops the `PTR` keyword — the destination `edx` is 4 bytes, so the assembler infers `DWORD PTR`. Both forms produce identical bytes.

## Build and run

```bash
as -o ex.o 04_size_suffixes.s
ld -o ex ex.o
./ex ; echo $?
# => 17
```

`17` is `0x11` in decimal. The program is silently shuttling bytes between memory and registers; the exit code is just a way to prove the final `QWORD` load worked.

## Subtle but important

**32-bit writes zero-extend; smaller writes don't.** On x86_64:

- `mov eax, ...` clears the upper 32 bits of `rax` to zero automatically.
- `mov ax, ...` leaves the upper 48 bits of `rax` *untouched*.
- `mov al, ...` leaves the upper 56 bits of `rax` *untouched*.

So if you do `mov al, [BYTE PTR addr]`, the top of `rax` may contain garbage. That's why we use `movzx eax, BYTE PTR [...]` — it explicitly zero-fills the upper bits. Use `movsx` if you want sign-extension instead.

**Gotcha.** Forgetting this is a classic bug: you load a small value with `mov al, ...`, then use `rax` later, and get a confusing result because the upper bits still hold whatever was there before. Default to `movzx`/`movsx` when reading sub-32-bit values from memory.

## Try it

1. Remove the `BYTE PTR` keyword from the first store: `mov [rip + bytebuf], 0x7F`. Try to assemble. You should get an error like "ambiguous operand size."
2. Change `0xDEADBEEF` to a number that doesn't fit in 32 bits, like `0x1DEADBEEF`. The assembler should reject it because you asked for `DWORD PTR` (4 bytes).
3. Single-step under `gdb`, set a watchpoint on `dwordbuf`, and confirm only 4 bytes change when the `DWORD` store fires.

## What's next

That's all of memory addressing. You can now point at any byte, any int, any element of any array, using the one formula, RIP-relative for safety, `lea` for arithmetic shortcuts, and `PTR` keywords for width. Next chapter: [`../07_The_Stack/README.md`](../07_The_Stack/README.md) — the special, automatically-managed slice of memory every function lives on.
