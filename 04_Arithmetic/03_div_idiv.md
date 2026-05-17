# Topic 03 — `div` and `idiv`

## A story: division's awkward setup

**In plain words:** division on x86_64 is weird because the CPU insists the *dividend* (the number being divided) is twice as wide as the *divisor*. So before you divide a 64-bit number, you have to "stretch" it across two cups.

**The analogy.** Picture the worker about to do long division on paper. Long division traditionally starts with a *big* number on top and a *smaller* number underneath. The x86 division instruction reflects that habit literally: it always reads the top number from a 128-bit pair of cups, and the bottom number from a single cup. If your top number is only 64 bits, you have to pad it out — fill the extra space with copies of the sign bit (for signed division) or with zeros (for unsigned).

**The technical layer.** Both `div` (unsigned) and `idiv` (signed) take **one operand**, the divisor. They implicitly use `rdx:rax` as the dividend:

```
quotient  = rdx:rax  /  operand    -> stored in rax
remainder = rdx:rax  %  operand    -> stored in rdx
```

Two outputs from one instruction. The quotient lands in `rax`. The remainder lands in `rdx`. Both are written; you can't pick one.

## The setup: sign-extend or zero-extend

**In plain words:** before you call `idiv` or `div`, you must explicitly fill `rdx` with the right thing. The right thing depends on whether you're doing signed or unsigned division.

### Signed: `cqo`

For **signed** division, use `cqo` (Convert Quadword to Octword). It copies the sign bit of `rax` (the top bit, i.e. bit 63) into *every* bit of `rdx`:

- If `rax` is positive (top bit 0), `rdx` becomes `0x0000000000000000`.
- If `rax` is negative (top bit 1), `rdx` becomes `0xFFFFFFFFFFFFFFFF`.

That makes `rdx:rax` represent the same signed value as `rax` alone — just in 128 bits instead of 64. Now `idiv` will do the right thing.

```asm
mov     rax, 120
cqo                             # rdx = 0  (because 120 is positive)
mov     rcx, 7
idiv    rcx                     # rax = 17, rdx = 1
```

**The technical layer.** Why is it called "octword"? Intel sizes things in words (16 bits): word = 16, doubleword = 32, quadword = 64, octoword = 128. So `cqo` literally means "extend a 64-bit quad into a 128-bit oct." The shorter friends are `cdq` (extend `eax` into `edx:eax`, 32 → 64) and `cwd` (`ax` into `dx:ax`, 16 → 32).

### Unsigned: `xor rdx, rdx`

For **unsigned** division, there are no sign bits to worry about — you just zero `rdx`:

```asm
xor     rdx, rdx                # rdx = 0
mov     rcx, 7
div     rcx                     # rax = rax/7, rdx = rax%7
```

This is what our itoa routine in the examples uses: it treats `rax` as an unsigned positive number, so a plain `xor rdx, rdx` is correct and slightly cheaper than `cqo`.

## The "Did You Forget?" trap

**In plain words:** if you forget to set up `rdx`, the CPU has no idea, and it cheerfully uses whatever leftover garbage is sitting in `rdx` as the top half of your dividend. Your answer will be wildly wrong — or the CPU will trap with a **divide error**.

```asm
;  BUG: rdx still has 0xDEADBEEF from earlier
mov     rax, 120
mov     rcx, 7
idiv    rcx                     # rdx:rax is now 0xDEADBEEF...0078, way too big
```

**Gotcha.** If the quotient would not fit in 64 bits, `idiv`/`div` raises **#DE** (divide error) and your program dies with `SIGFPE`. This happens both for division by zero *and* for "quotient overflow." Most beginners hit it because they forgot `cqo`, not because their math was actually overflow-prone.

## Two answers in one instruction

**In plain words:** every `div` or `idiv` gives you both `q` and `r`. If you only want one of them, the other is still written; just ignore it.

This is why integer-to-ASCII conversion uses `div`: in one shot you get `q = number / 10` (the digits above the current one) and `r = number % 10` (the next digit). You write the digit from `r`, replace the number with `q`, and loop.

## A worked walkthrough: `120 / 7`

By hand: `120 = 7 * 17 + 1`. Quotient 17, remainder 1.

```asm
mov     rax, 120                # dividend
cqo                             # rdx:rax = 120 (sign-extended)
mov     rcx, 7                  # divisor
idiv    rcx                     # rax = 17, rdx = 1
```

After this runs:

- `rax = 17` (the quotient — how many times 7 goes into 120)
- `rdx = 1` (the remainder — what's left after taking out 7 * 17 = 119)

The example program saves these into two callee-saved registers (`r12` and `r13`), prints them as decimal with three `write` syscalls separated by `" r "`, and exits.

## The runnable example

See [`03_div_idiv.s`](03_div_idiv.s). Output:

```
17 r 1
```

The key block:

```asm
mov     rax, 120
cqo
mov     rcx, 7
idiv    rcx                     # rax = 17 (quotient), rdx = 1 (remainder)
mov     r12, rax
mov     r13, rdx
```

We then print `r12`, then the literal string `" r "`, then `r13`, then a newline.

## Build and run

```bash
as -o /tmp/t.o 03_div_idiv.s && ld -o /tmp/t /tmp/t.o && /tmp/t
# => 17 r 1
```

## Check yourself

1. To compute `-7 % 3` with `idiv`, what do you do? (Answer: `mov rax, -7`, `cqo` — which sets `rdx = 0xFFFFFFFFFFFFFFFF` because -7 is negative — then `mov rcx, 3`, then `idiv rcx`. Quotient is -2, remainder is -1, in C's truncated-toward-zero sense.)
2. Why is `xor rdx, rdx` not the right setup for signed `idiv`? (Answer: if `rax` is negative, `rdx = 0` would make `rdx:rax` look like a huge *positive* 128-bit number. The division would either produce the wrong answer or overflow.)
3. After `idiv`, which register holds the remainder? (Answer: `rdx`. Always. People constantly forget which is which — quotient in `rax`, remainder in `rdx`. Pronounce them as Q-A-X and R-D-X if it helps.)

## Next

[Topic 04 — Flags: `CF`, `ZF`, `SF`, `OF`](04_flags_cf_zf_sf_of.md): every arithmetic instruction also flips a few yes/no lights on the desk. Those lights are how the CPU later decides whether to branch.
