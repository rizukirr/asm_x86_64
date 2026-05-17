.intel_syntax noprefix

# A tiny program to practice the toolchain on.
# It writes "tools\n" to the screen and exits with status 0.
# The README walks you through running `as`, `ld`, `objdump`,
# `strace`, and `gdb` on this exact file.

        .section .data
msg:    .ascii  "tools\n"
        .equ    msglen, . - msg

        .section .text
        .globl  _start
_start:
        mov     rax, 1                  # write
        mov     rdi, 1                  # stdout
        lea     rsi, [rip + msg]        # buffer address
        mov     rdx, msglen             # length
        syscall

        mov     rax, 60                 # exit
        xor     rdi, rdi                # status = 0
        syscall
