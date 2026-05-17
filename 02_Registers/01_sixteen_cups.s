.intel_syntax noprefix

        .section .data
msg:    .ascii  "16 cups on the counter\n"
        .equ    msglen, . - msg

        .section .text
        .globl  _start
_start:
        # Pretend we are a chef setting things into different cups.
        # Most cups can hold anything; we just put small test numbers in.
        mov     rbx, 2                  # callee-saved scratch cup
        mov     rcx, 3                  # counter cup
        mov     r8,  8                  # "extra" cup #8
        mov     r9,  9                  # "extra" cup #9
        mov     r12, 12                 # callee-saved cup
        mov     r15, 15                 # callee-saved cup

        # Now use the syscall cups (rax, rdi, rsi, rdx) to print our line.
        mov     rax, 1                  # write
        mov     rdi, 1                  # stdout
        lea     rsi, [rip + msg]        # buffer
        mov     rdx, msglen             # length
        syscall

        # And the standard clean exit.
        mov     rax, 60                 # exit
        xor     rdi, rdi                # status 0
        syscall
