# 01 — The One Formula: `[base + index*scale + disp]`

## A story: the warehouse calculator

**In plain words:** every time you write `[...]` in x86 assembly, a tiny built-in calculator inside the CPU works out which shelf in memory you mean. The calculator only knows one formula, and it's short.

**The analogy.** Picture a giant warehouse with billions of numbered shelves stretched off into the distance. The warehouse is called **memory** (or **RAM** — random access memory, meaning the worker can jump straight to any shelf without walking past the others). Each shelf holds one byte. To touch a shelf you need its number, called the **address**.

But nobody wants to think in raw shelf numbers like "shelf 140737488355328." That's painful. So x86 lets you describe an address by handing the calculator up to four little pieces, and the calculator adds them together for you.

**The technical layer.** Every legal memory operand on x86_64 is some specialization of one formula:

```
effective_address  =  base  +  index * scale  +  displacement
```

Each piece does a job:

- **`base`** — a 64-bit register. Think "starting shelf."
- **`index`** — any 64-bit register except `rsp`. Think "how many steps from base."
- **`scale`** — must be `1`, `2`, `4`, or `8`. Think "how big each step is." (Why those numbers? Because the common data widths are 1, 2, 4, and 8 bytes.)
- **`displacement`** — a plain signed constant up to about ±2 GiB. A final fixed nudge.

Any subset of those pieces is allowed. Every legal `[ ... ]` is a specialization:

```asm
[rax]                           # base only
[rax + 8]                       # base + disp
[rax + rcx]                     # base + index
[rax + rcx*4]                   # base + index*scale  (array of 4-byte ints!)
[rax + rcx*8 + 16]              # the full form
```

**Gotcha.** The `scale` is hardware-fixed at 1/2/4/8. You can't write `[rax + rcx*3]`. If you need `*3`, you compute it with `lea` (next topic) or break it up.

**Check yourself.** Why is `rsp` banned as an `index` register? (Answer: the instruction encoding reserves the slot that would mean "index = rsp" to signal "no index register present." It's a quirk of how the bits are laid out, not a deep semantic reason.)

## Why this matters: array indexing for free

**In plain words:** the formula matches exactly how you walk an array, so one CPU instruction does the multiply, the add, and the load all at once.

**The analogy.** Your arrays in C look like `arr[i]`. The compiler turns that into shelf number `arr + i * sizeof(element)`. The CPU's addressing calculator *is* that exact expression — base + index*scale. The C language was shaped to match the chip.

**The technical layer.** In C:

```c
int  arr[10];
int  x = arr[i];               // logically: x = *(arr + i)
```

In assembly, if `rbx` holds `&arr[0]` and `rcx` holds `i`:

```asm
mov     eax, [rbx + rcx*4]      # int is 4 bytes -> scale 4
```

The CPU computes `rbx + rcx * 4`, walks to that shelf, picks up 4 bytes, and lands them in `eax`. One instruction. For an array of `int64_t` it would be `*8`; for `char`, `*1` (or just leave the scale off).

**Check yourself.** If `arr` is `long long arr[]` (8-byte elements) and `i = 3`, what does `[rbx + rcx*8]` resolve to? (Answer: `rbx + 24`, the address of `arr[3]`.)

## The example program

See [`01_the_one_formula.s`](01_the_one_formula.s). It sums the first five elements of an `int` array using exactly the formula `[base + index*scale]`, then exits with the sum as its exit code.

```asm
.intel_syntax noprefix

        .section .data
arr:    .long   10, 20, 30, 40, 50      # 5 ints, 4 bytes each
        .equ    arrlen, 5

        .section .text
        .globl  _start
_start:
        lea     rbx, [rip + arr]        # rbx = &arr[0]
        mov     rcx, arrlen             # rcx = n
        xor     eax, eax                # rax = 0  (sum accumulator)
        xor     rdx, rdx                # rdx = i  (index)
.loop:
        cmp     rdx, rcx
        jge     .done
        add     eax, [rbx + rdx*4]      # eax += arr[i]  (the magic line)
        inc     rdx
        jmp     .loop
.done:
        mov     rdi, rax                # exit code = sum
        mov     rax, 60                 # syscall: exit
        syscall
```

**In plain words, step-by-step:**

- `.long 10, 20, 30, 40, 50` reserves five 4-byte shelves and stamps the numbers onto them. `arr` is a sticky note on the first shelf.
- `lea rbx, [rip + arr]` asks the calculator "what's the address of `arr`?" and puts it in `rbx` *without* reading the shelf. (More on `lea` in [`03_lea_as_math.md`](03_lea_as_math.md).)
- `mov rcx, arrlen` puts the count `5` into `rcx`.
- `xor eax, eax` is the standard zero-a-register trick — it's shorter in bytes than `mov eax, 0`.
- The loop bumps `rdx` from 0 to 4. At each step, the magic line `add eax, [rbx + rdx*4]` asks the calculator for `rbx + rdx*4`, fetches the 4-byte int there, and adds it to the running total.
- After the loop, the sum (`10+20+30+40+50 = 150`) is in `rax`. We pass it to `exit` so we can read it back from the shell.

**ASCII diagram of the shelves:**

```
   address        contents
   --------       ----------
   &arr + 0       10   (4 bytes)
   &arr + 4       20
   &arr + 8       30
   &arr + 12      40
   &arr + 16      50
```

Index `i=2` and scale 4 → `&arr + 8` → shelf holding `30`. Exactly what the addressing hardware does.

## Build and run

```bash
as -o ex.o 01_the_one_formula.s
ld -o ex ex.o
./ex ; echo $?
# => 150
```

The program prints nothing; it just exits with code `150`. That's the sum.

**Gotcha.** Linux exit codes are only 8 bits — values above 255 wrap. Our sum 150 fits, but if you change the array to bigger numbers, `echo $?` may show a wrapped value. That's a shell limitation, not an assembly one.

## Try it

1. Change `arr` to `.quad 10, 20, 30, 40, 50` (8-byte elements). What scale do you need in the load? (Answer: `*8`, and use `add rax, [rbx + rdx*8]` so you read 8 bytes at a time.)
2. Add a `displacement` to skip the first element: change the magic line to `add eax, [rbx + rdx*4 + 4]`. The sum should drop by 10 and the loop should stop one short of the end. Adjust accordingly.
3. Disassemble with `objdump -d -M intel ex` and look at the magic line. You'll see the encoded scale `*4` baked into a single byte.

## What's next

The `[rip + arr]` notation snuck in twice already. That's a special, very modern flavor of the formula. Next: [`02_rip_relative.md`](02_rip_relative.md).
