# 09.1 — Counted Loops: `dec` + `jnz`

## A story: a kid counting down on their fingers

**In plain words:** the CPU doesn't have a "loop" idea. What it has is "jump." A loop is just normal code with a jump at the bottom that points back up — plus a way to eventually stop.

**The analogy.** Picture a small kid who wants to take exactly five jellybeans out of a jar. They don't say "loop five times." They count on their fingers. Five fingers up. Take one bean — put one finger down. Four fingers up. Take one bean — put one finger down. They keep going until **all the fingers are down**, then they stop. The fingers are the **counter**. The check "are all the fingers down yet?" is the **condition**. The "go grab another bean" is the **jump back to the top**.

**The technical layer.** That is exactly the most common loop in assembly — the **counted loop**:

1. Put the count in a register (the fingers).
2. Do one unit of work (one bean).
3. Knock the counter down by one (`dec`).
4. If the counter is **not zero**, jump back to step 2 (`jnz`).

`dec` is short for *decrement* — subtract one. `jnz` is short for *jump if not zero*. The pair `dec ; jnz` is the bread-and-butter counted loop on x86_64.

**Check yourself.** If the counter starts at 5, how many times does the body run? (Answer: 5. The counter goes 5→4→3→2→1→0. `jnz` fires on the first four and the body runs on counter values 5,4,3,2,1.)

## How `dec` and `jnz` talk to each other

**In plain words:** `dec` not only subtracts one — it also flips a little light on the CPU called the **zero flag**. `jnz` looks at that light.

**The technical layer.** The CPU has a tiny notebook called **FLAGS**: a handful of yes/no bits that get updated every time you do arithmetic. After `dec rcx`, the **ZF** (zero flag) is set to 1 if the result was zero, or 0 if it wasn't. `jnz target` (also spelled `jne target`) means "if ZF = 0, jump to `target`; otherwise fall through."

So `dec r12 ; jnz .loop` reads, in English, as: "subtract one from `r12`; if the result isn't zero yet, go back to the top of the loop."

**Gotcha.** `dec` updates ZF (and most arithmetic flags), but **it does not touch the carry flag CF**. That tiny detail makes `dec` slightly different from `sub r12, 1` — and on very rare occasions (mostly inside `adc`/`sbb` chains) the difference matters. For ordinary counted loops, `dec` is fine and one byte shorter.

## The program

We print the digits `1 2 3 4 5` followed by a newline, using a counted loop.

See [`01_counted_loops.s`](01_counted_loops.s):

```asm
.intel_syntax noprefix

        .section .data
digit:  .byte   '0'
nl:     .byte   '\n'

        .section .text
        .globl  _start
_start:
        mov     r12, 5                  # counter
        mov     bl, '1'                 # current ASCII digit

.loop:
        lea     rsi, [rip + digit]      # rsi -> digit
        mov     [rsi], bl               # store current digit
        mov     rax, 1                  # write(1, &digit, 1)
        mov     rdi, 1
        mov     rdx, 1
        syscall

        inc     bl                      # bump ASCII digit
        dec     r12                     # tick counter
        jnz     .loop                   # again if not done

        mov     rax, 1                  # write a newline
        mov     rdi, 1
        lea     rsi, [rip + nl]
        mov     rdx, 1
        syscall

        mov     rax, 60                 # exit(0)
        xor     rdi, rdi
        syscall
```

**In plain words.** `r12` is the finger-counter starting at 5. `bl` is the ASCII byte we'll print this iteration. Each lap: copy `bl` into the one-byte buffer `digit`, call `write` to print that one byte, bump `bl` to the next ASCII digit, knock the counter down, jump back if more left.

## Build and run

```bash
as -o 01.o 01_counted_loops.s
ld -o 01 01.o
./01
# => 12345
```

## Dissecting it

### Why `r12` instead of `rcx`?

**In plain words:** every time we do a `syscall`, the kernel is allowed to scribble over `rcx` and `r11`. If we kept the counter in `rcx`, the syscall would wipe it out and our loop would do something wild.

**The technical layer.** On Linux x86_64, the `syscall` instruction itself uses `rcx` to save the return address and `r11` to save the FLAGS — that's part of the CPU's contract. So **after every `syscall`, the values of `rcx` and `r11` are gone**. The kernel may also clobber some other registers, but those two are guaranteed lost. Registers `r12` through `r15` (and `rbx`, `rbp`) are **callee-saved**: a well-behaved syscall (or function) restores them, so they survive across calls.

**Gotcha.** If we'd written `mov rcx, 5` and used `dec rcx ; jnz .loop`, the program would print a wild flood of bytes — the syscall replaces `rcx` with some random kernel address, the loop counter is destroyed, and `dec`/`jnz` runs roughly forever. (Try it once on purpose; the lesson sticks.)

### Why `inc bl` works

**In plain words:** `bl` is one byte (8 bits) — the low byte of the `rbx` register. Adding 1 to ASCII `'1'` gives ASCII `'2'`, then `'3'`, and so on, because the ASCII codes for digits are consecutive (`'0'` is 0x30, `'1'` is 0x31, ..., `'9'` is 0x39).

**Gotcha.** Unlike 32-bit writes, an 8-bit write to `bl` **does not** zero out the upper bits of `rbx`. The high bytes keep their old values. Here we don't care because we never read `rbx`'s upper bits, only `bl`. But this is a classic surprise — see [Part 02](../02_Registers/README.md).

### Why `lea` then `mov [rsi], bl`?

**In plain words:** GAS Intel syntax is fussy about RIP-relative stores. We get the address of `digit` into `rsi` with `lea`, then store through `rsi`.

**The technical layer.** `lea rsi, [rip + digit]` computes "the address of `digit`, as an offset from the current instruction pointer." That's the modern, position-independent way to point at a global. Then `mov [rsi], bl` stores one byte at that address. We could write it as a single instruction in some assemblers, but the two-line form is the most portable and reads clearly.

## Counter-runs-out variations

**`dec`/`jnz`** counts down to zero. Two other common shapes:

- **Count up to N, exit on equal.** Useful when the index is also an array subscript.

  ```asm
        xor     rcx, rcx                # i = 0
  .loop:
        ; body uses rcx as index
        inc     rcx
        cmp     rcx, 5
        jne     .loop
  ```

- **Count down, exit on negative.** Useful when zero is a valid iteration.

  ```asm
        mov     rcx, 5                  # i = 5
  .loop:
        ; body uses rcx (5,4,3,2,1,0)
        dec     rcx
        jns     .loop                   # jump while sign-bit clear (>= 0)
  ```

`jns` is "jump if not signed" — jump while the result is non-negative. There are about 15 of these `jcc` shapes (`je`, `jne`, `jg`, `jge`, `jl`, `jle`, `ja`, `jb`, `js`, `jns`, ...). We met them in [Part 08](../08_Control_Flow/README.md).

**Check yourself.** If you replace `dec r12 ; jnz .loop` with `sub r12, 1 ; jnz .loop`, does the program still work? (Yes — the only practical difference is one byte of code size and a slightly different effect on the carry flag, which we don't read.)

## Try it

1. Change `mov r12, 5` to `mov r12, 10` and `mov bl, '1'` to `mov bl, '0'`. What gets printed? (Hint: ASCII keeps going past `'9'`.)
2. Move the counter back into `rcx` and `push rcx` / `pop rcx` around the syscall. Verify it works again.
3. Replace `dec r12 ; jnz .loop` with `sub r12, 1 ; jnz .loop` and re-disassemble with `objdump -d -M intel ./01`. Note the code is one byte longer.

## What's next

Counted loops are the simplest shape. The next file looks at the **two condition-driven shapes** — `while` and `do-while` — and how to choose between them. → [02_while_dowhile.md](02_while_dowhile.md)
