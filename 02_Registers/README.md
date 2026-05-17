# Part 02 — Registers

Registers are the CPU's hands: a tiny set of super-fast slots, right inside the chip, where almost all the actual work happens. Main memory is huge but far away; registers are small but instantaneous. In this chapter we meet x86_64's 16 general-purpose registers, learn that each one can be viewed at four different widths (with one surprising side effect on 32-bit writes), and finish with the two specials that drive every program — `rip` (the bookmark) and `rflags` (the mood ring).

Topics, in order:

- [`01_sixteen_cups.md`](01_sixteen_cups.md) — the 16 GPRs, what each is traditionally for, callee-saved vs scratch.
- [`02_register_widths.md`](02_register_widths.md) — `rax`/`eax`/`ax`/`ah`/`al` are one cup with four scales, and the 32-bit zero-extension rule.
- [`03_rip_and_rflags.md`](03_rip_and_rflags.md) — the two cups you don't address by name: the instruction pointer and the status flags.

Next: [Part 03 — Moving Data](../03_Moving_Data/README.md).
