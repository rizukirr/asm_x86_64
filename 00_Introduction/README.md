# Part 00 — Introduction

> "The CPU is a stupid machine that does one tiny thing extremely fast, billions of times per second. Assembly is the list of those tiny things."

Welcome. This chapter is the prologue — three short topics that set up the picture, the tools, and the way the rest of the course is laid out. Read them in order; the total is shorter than a single later chapter, and everything afterwards rests on it.

Each topic has a small `.s` program you can build and run, just to keep your hands on the keyboard from minute one.

## Topics

- [01 — What is assembly, and why bother?](01_what_is_assembly.md) — the warehouse mental model, what "x86_64" really means, and the world's smallest program ([`01_what_is_assembly.s`](01_what_is_assembly.s)).
- [02 — The toolchain](02_the_toolchain.md) — `as`, `ld`, `objdump`, `strace`, `gdb`, and AT&T vs Intel, walked through on a real file ([`02_the_toolchain.s`](02_the_toolchain.s)).
- [03 — How to read this course](03_how_to_read_this_course.md) — the Feynman 4-beat pattern, scope and non-scope, the chapter map, and a sanity-check program ([`03_how_to_read_this_course.s`](03_how_to_read_this_course.s)).

## Next

Once you've worked through all three topics and your toolchain is happy, continue to [Part 01 — Hello, CPU](../01_Hello_CPU/README.md).
