# 07.03 — Stack Frames and Scratch Room

## A story: renting a workbench

**In plain words:** when a function starts, it carves out a chunk of stack as **scratch room** for its own variables. When it finishes, it gives that chunk back. The carved-out chunk is called a **stack frame**.

**The analogy.** Imagine a shared woodworking shop. When you walk in, you reserve a workbench by hammering a stake into the floor labeled "mine starts here." You spread your tools on the bench, do your work, then before leaving you pull the stake and the bench is free for the next person.

In assembly:

- The stake is **`rbp`** (the "base pointer" or "frame pointer"). It marks the *anchor* of your frame.
- The bench surface is **the memory between `rbp` and `rsp`**. That's your scratch room.
- The local variables you put on the bench are addressed as **`[rbp - 8]`, `[rbp - 16]`, ...** (negative because the stack grows down).

## The classic prologue and epilogue

**In plain words:** every "by-the-book" function on x86_64 Linux opens with three lines (the **prologue**) and closes with three lines (the **epilogue**):

```asm
my_func:
        push    rbp                     # 1. save caller's frame anchor
        mov     rbp, rsp                # 2. anchor our own frame here
        sub     rsp, N                  # 3. carve N bytes of locals (N a multiple of 16, typically)

        ... body ...

        mov     rsp, rbp                # 4. discard the locals
        pop     rbp                     # 5. restore caller's frame anchor
        ret                             # 6. jump back to caller
```

**Step by step in plain words:**

1. **`push rbp`** — save the caller's frame anchor on the stack so we can put it back later. The caller doesn't know we're going to scribble on `rbp`.
2. **`mov rbp, rsp`** — declare "my frame starts right here." From now until the epilogue, `rbp` doesn't move, even though `rsp` will.
3. **`sub rsp, N`** — lower `rsp` by `N` bytes. The memory between `rsp` (new top) and `rbp` (our anchor) is our private scratch room.
4. **`mov rsp, rbp`** — collapse the scratch room. `rsp` is now back at the anchor, as if the `sub` never happened.
5. **`pop rbp`** — put the caller's frame anchor back. `rsp` rises by 8.
6. **`ret`** — jump to the return address that's now at the top of the stack (pushed there by the caller's `call`).

**Gotcha — why save `rbp`?** Because the caller is also using `rbp` to track its own frame. If we overwrote it without saving, the caller would come back to find its bench markers gone.

## Addressing locals

**In plain words:** once `rbp` is anchored, local variables live at fixed negative offsets from it.

```
high addresses
                    +-----------------+
                    | saved rbp       |   <- [rbp]
        rbp  ---->  +-----------------+
                    | local 1 (8 B)   |   <- [rbp - 8]
                    +-----------------+
                    | local 2 (8 B)   |   <- [rbp - 16]
                    +-----------------+
                    | local 3 (8 B)   |   <- [rbp - 24]
                    +-----------------+
                    | local 4 (8 B)   |   <- [rbp - 32]
        rsp  ---->  +-----------------+
low addresses
```

The crucial property: **`rbp` doesn't move during the function**. So no matter what crazy stuff happens to `rsp` (more pushes, calls into other functions, allocations of arrays), `[rbp - 8]` always refers to the same local variable. That's why compilers love this pattern — it's easy to generate code against.

## Worked example: four locals, summed

See [`03_stack_frames.s`](03_stack_frames.s):

```asm
.intel_syntax noprefix

        .section .text
        .globl  _start
_start:
        push    rbp                     # save caller's rbp (kernel's, here)
        mov     rbp, rsp                # anchor our frame
        sub     rsp, 32                 # 32 bytes = four 8-byte locals

        mov     qword ptr [rbp - 8],  1
        mov     qword ptr [rbp - 16], 2
        mov     qword ptr [rbp - 24], 3
        mov     qword ptr [rbp - 32], 4

        xor     rax, rax
        add     rax, [rbp - 8]
        add     rax, [rbp - 16]
        add     rax, [rbp - 24]
        add     rax, [rbp - 32]         # rax = 10

        mov     rsp, rbp                # discard locals
        pop     rbp                     # restore caller's rbp

        mov     rdi, rax
        mov     rax, 60
        syscall
```

**In plain words.** We open a frame, write `1, 2, 3, 4` into four slots, zero out `rax`, sum the four slots into `rax`, close the frame, and exit with `rax` as the status. `1 + 2 + 3 + 4 = 10`, so the program exits with status 10.

**Zooming in on `qword ptr`.** When you write `mov [rbp - 8], 1`, the assembler has a problem: is `1` an 8-bit, 16-bit, 32-bit, or 64-bit value being stored? The destination is just a memory address — it has no inherent width. So you must tell the assembler with a **size override**:

- `byte ptr`  — 1 byte
- `word ptr`  — 2 bytes
- `dword ptr` — 4 bytes
- `qword ptr` — 8 bytes ("quad word")

We want a full 64-bit slot, so `qword ptr`.

## Build and run

```bash
as -o /tmp/03.o 03_stack_frames.s
ld -o /tmp/03    /tmp/03.o
/tmp/03 ; echo $?
```

Output:

```
10
```

## The "skip the frame pointer" variant

**In plain words:** modern compilers, when optimizing, often skip `rbp` and address everything off `rsp` directly. This frees up `rbp` for general-purpose use, giving the compiler one more register to play with.

```asm
my_func:
        sub     rsp, 32                 # carve scratch
        mov     qword ptr [rsp + 0],  1 # local 1 (at the new low end)
        mov     qword ptr [rsp + 8],  2 # local 2
        ...
        add     rsp, 32                 # release
        ret
```

Two differences:

1. No `push rbp` / `mov rbp, rsp` / `pop rbp`.
2. Locals are at **positive** offsets from `rsp` (because `rsp` is at the *bottom* of the frame and locals are above it).

**Gotcha.** The downside: if any instruction inside the function changes `rsp` (a `push`, a `call`, anything), the offsets to your locals shift. You have to track that. The compiler does, but humans get it wrong easily. Beginner advice: use the `rbp` pattern until you're comfortable.

You'll see both styles when reading `objdump` output. GCC at `-O0` keeps the frame pointer; at `-O1` and above it usually omits it.

## Gotcha — don't return with a busted `rsp`

**In plain words:** if `rsp` is not exactly where it was when the function started (after accounting for the caller's `call`), then `ret` reads the wrong slot and jumps to nonsense.

Concretely: if you `push` something during the function body and don't `pop` it before the epilogue, then `mov rsp, rbp` will fix it (because `rbp` is unaffected). But if you skipped the `rbp` pattern and rely on `rsp` arithmetic alone, an unmatched push **will** crash the function. This is why the `rbp` pattern is forgiving — `mov rsp, rbp` is a "reset" button.

## Check yourself

1. **You write `sub rsp, 32`. How many 8-byte locals does that give you?**
   *Answer: four. `32 / 8 = 4`.*

2. **After `push rbp ; mov rbp, rsp`, what is the relationship between `rsp` and `rbp`?**
   *Answer: they're equal. `rsp` will decrease as you carve locals; `rbp` stays put.*

3. **You `sub rsp, 24` instead of 32. Will the program still work?**
   *Answer: depends. It'll work mechanically, but you have only three local slots and the alignment is now wrong (`rbp - rsp = 24` plus the saved `rbp` and return address — see topic 04). If your function calls anything else, it'll break.*

4. **Why is `mov rsp, rbp` safer than `add rsp, 32`?**
   *Answer: because `mov rsp, rbp` undoes whatever happened to `rsp` regardless of stray pushes in the body. `add rsp, 32` assumes nothing else moved `rsp`.*

## Next

[`04_alignment.md`](04_alignment.md) — the 16-byte alignment rule that bites everyone who calls into libc for the first time.
