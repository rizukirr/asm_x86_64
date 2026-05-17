.intel_syntax noprefix

# A "ritual" program — your sanity check that the whole course
# environment works. If this assembles, links, runs, and exits 0,
# you are ready for Part 01.
#
# The program does nothing visible. It just returns 0 to the shell.
# Run it like:
#     as -o check.o 03_how_to_read_this_course.s
#     ld -o check check.o
#     ./check && echo "ready"

        .section .text
        .globl  _start
_start:
        xor     rdi, rdi        # status = 0 ("everything fine")
        mov     rax, 60         # exit
        syscall
