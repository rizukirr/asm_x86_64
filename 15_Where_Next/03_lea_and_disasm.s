.intel_syntax noprefix

        .section .text
        .globl  _start
_start:
        mov     edi, 7                  # x = 7
        # Compute y = 3*x + 5 using a single LEA.
        # [rdi + rdi*2 + 5]  ==  x + 2*x + 5  ==  3*x + 5  ==  26.
        lea     edi, [rdi + rdi*2 + 5]  # edi = 26

        mov     rax, 60                 # syscall: exit
        syscall
