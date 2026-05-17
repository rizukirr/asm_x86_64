# Topic 04 — Flags: `CF`, `ZF`, `SF`, `OF`

## A story: tiny lights on the desk

**In plain words:** after almost every math instruction, the CPU flips a row of tiny yes/no lights to summarize what just happened. Was the answer zero? Did it go negative? Did it overflow? You can read those lights, and — more importantly — the jump instructions read them to decide whether to branch.

**The analogy.** Imagine the worker has a small light bar along the back of the desk. Each light has a name. After every math note, the worker glances at the answer and toggles a few lights:

- A **zero** light: lights up if the answer is exactly 0.
- A **sign** light: lights up if the answer looks negative (top bit is 1).
- A **carry** light: lights up if the answer spilled past the cup's edge, viewed as unsigned.
- An **overflow** light: lights up if the answer's sign came out *wrong*, viewed as signed.

These four lights are the conditional-branch fuel of every program ever written. They are bits inside a special register called **FLAGS** (or **RFLAGS** in 64-bit mode).

**The technical layer.** The four flags we care about now:

| Flag | Long name | Set when…                                         |
| ---- | --------- | ------------------------------------------------- |
| `ZF` | Zero      | The result was exactly 0                          |
| `SF` | Sign      | The result's top bit is 1 (negative if signed)    |
| `CF` | Carry     | Unsigned overflow (the result spilled out)        |
| `OF` | Overflow  | Signed overflow (the sign of the answer is wrong) |

## The "signed vs unsigned" double life

**In plain words:** the same bit pattern can mean two different things, depending on whether you're thinking of it as signed (can be negative) or unsigned (only positive). The CPU sets *both* a "carry" flag (for the unsigned interpretation) and an "overflow" flag (for the signed interpretation), so you can pick whichever matches the meaning of your numbers.

**The analogy.** A car's odometer that reads `99999` is "almost rolling over." If you drive 1 more mile, it becomes `00000`. To someone tracking unsigned mileage, this is dramatic — the odometer "wrapped around." To someone who never trusted the odometer to begin with, nothing remarkable happened. `CF` is the "unsigned wraparound" alarm. `OF` is a related but different alarm: it goes off when a *signed* result has the wrong sign — for example, when you add two large positive numbers and the answer comes out negative.

**The technical layer.** Consider this on a 64-bit register:

```
rax = 0xFFFFFFFFFFFFFFFF    (largest unsigned 64-bit number, or -1 if signed)
add rax, 1
```

The math wraps to 0. After this single instruction:

- `ZF = 1` — the result is 0.
- `CF = 1` — viewed as unsigned, the result "spilled" past the edge (we'd want a 65th bit to hold the full answer 2^64).
- `SF = 0` — the top bit of 0 is 0.
- `OF = 0` — viewed as signed, `-1 + 1 = 0`. That's correct, no signed surprise.

Same instruction, four different lights, each saying something different. Whether you care about `CF` or `OF` depends on whether you meant the number to be unsigned or signed.

## Reading a flag into a register: `setcc`

**In plain words:** there's a family of one-byte instructions called `setcc` ("set on condition") that read a single flag and write 0 or 1 into a byte register. They turn invisible flag-bits into visible numbers.

```asm
setc    al      # al = CF
setz    al      # al = ZF
sets    al      # al = SF
seto    al      # al = OF
```

**The technical layer.** `setcc` is normally used to convert a comparison result into a boolean — for instance, after `cmp rax, rbx`, `setl al` sets `al = 1` if `rax < rbx` (signed), 0 otherwise. Compilers use it constantly when translating C's `<`, `<=`, `==`, `!=` operators in contexts where you want the bool as a value rather than a branch.

Here we use it for an unusual purpose: peeking at the four arithmetic flags so we can print them.

**Gotcha.** `setcc` writes only the **bottom byte** of the named register. The upper bits are left alone. If you want a clean 0-or-1 in the full 64-bit register, zero it first (`xor rax, rax`) and then `setc al`.

## Math sets flags, jumps read them

**In plain words:** arithmetic instructions never branch. They just compute, and they update the flags. *Later* instructions (`jz`, `jc`, `jl`, `jg`, …) read those flags to decide whether to jump.

This separation is one of the most important ideas in assembly. It means:

```asm
add     rax, rbx
jz      handle_zero        # jumps if the add just produced 0
```

is really two steps: `add` set `ZF`, `jz` reads `ZF`. You can put many instructions between them, but watch out — most instructions modify flags. The flags only reflect the *most recent* arithmetic.

We cover the conditional jumps in detail in [Part 08](../08_Control_Flow/README.md). For now, the rule is: **math sets, jumps read**.

## A few flag-affecting instructions to know

**In plain words.** It's not just `add`, `sub`, `mul`, `div`. Many instructions set flags. Some of the most useful are deliberate no-ops *except* for flag side effects:

- `cmp a, b` — like `sub a, b` but **doesn't store the result**. It only updates flags. Used before conditional jumps.
- `test a, b` — like `and a, b` but **doesn't store the result**. Used to check whether bits are set; `test rax, rax` followed by `jz` is the canonical "jump if `rax` is zero."

`mov` does **not** affect flags. `lea` does **not** affect flags. `inc` and `dec` affect *most* flags but **not** `CF`. We'll meet more exceptions as we go.

## The runnable example

See [`04_flags_cf_zf_sf_of.s`](04_flags_cf_zf_sf_of.s). It performs `0xFFFFFFFFFFFFFFFF + 1`, captures all four flags with `setc`/`setz`/`sets`/`seto`, and prints them.

The crucial block:

```asm
mov     rax, -1                 # 0xFFFFFFFFFFFFFFFF
add     rax, 1                  # wraps to 0; sets ZF=1, CF=1, SF=0, OF=0

setc    r12b                    # r12 = CF
setz    r13b                    # r13 = ZF
sets    r14b                    # r14 = SF
seto    r15b                    # r15 = OF
```

The rest of the file just prints those four 0-or-1 values labelled with `CF=`, `ZF=`, `SF=`, `OF=`.

## Build and run

```bash
as -o /tmp/t.o 04_flags_cf_zf_sf_of.s && ld -o /tmp/t /tmp/t.o && /tmp/t
# => CF=1 ZF=1 SF=0 OF=0
```

If you flip the experiment — try `mov rax, 0x7FFFFFFFFFFFFFFF` then `add rax, 1` — you'll see `OF=1` light up instead: that's adding 1 to the largest *signed* positive number, producing the largest negative number. Classic signed overflow.

## Check yourself

1. After `xor rax, rax`, which flags are set? (Answer: `ZF=1` because the result is 0; `SF=0` because the top bit is 0; `CF=0` and `OF=0` because logical operations always clear them.)
2. After `mov rax, 5 ; sub rax, 5`, can you predict the flags? (Answer: `ZF=1`, `SF=0`, `CF=0`, `OF=0`. The subtraction produced exactly zero, no borrow, no overflow.)
3. Why is `test rax, rax` the standard way to check "is `rax` zero?" instead of `cmp rax, 0`? (Answer: shorter encoding. `cmp rax, 0` needs to encode the literal 0; `test rax, rax` only needs two register names. The flags set are identical for the zero-check.)

## Next

That's the arithmetic chapter. Up next: [Part 05 — Bitwise operations](../05_Bitwise/README.md), which covers `and`, `or`, `xor`, `not`, and the shift instructions — math's other half.
