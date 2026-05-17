# Part 03 — Moving Data

## A story: a photocopier, not a shipping truck

Imagine you have a sheet of paper on your desk with a number written on it. You want that same number on a different piece of paper.

You don't pick up the original and *carry* it to the other paper — that would leave the first spot empty. Instead, you put the original on a **photocopier**, press the button, and stick the copy onto the second sheet. Now both sheets have the number. Nothing was destroyed; the original is untouched.

That's the spirit of every "move" instruction in this chapter. The name is misleading — none of them *move* anything in the strict sense. They **copy**. The source is unchanged; the destination becomes a duplicate.

If assembly had a favorite verb, it would be `mov`. Roughly half the instructions in a real program are `mov` (or one of its close cousins). Getting comfortable with this family is most of what it takes to read assembly fluently.

## Topics in this part

- [03.1 — `mov`: the photocopier](01_mov_basics.md) — the three operand kinds (register, immediate, memory), the allowed combinations, operand sizes, and size hints like `qword ptr`.
- [03.2 — `movzx` and `movsx`: widening with intent](02_extension.md) — copying a small value into a bigger register, choosing between zero-padding and sign-padding, plus the free 32-to-64 zero-extend.
- [03.3 — `lea`: addresses without fetching](03_lea_address.md) — taking the address of a label, and the famous trick of using `lea` as a free calculator.

Each topic has a small, runnable companion program (`NN_topic_slug.s`) you can build with `as` and `ld`.

## What's next

Once you can copy and widen bits, it's time to do real arithmetic on them. Continue to [Part 04 — Arithmetic](../04_Arithmetic/README.md).
