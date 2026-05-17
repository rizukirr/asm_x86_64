.intel_syntax noprefix

        .section .data
msg:    .ascii  "one cup, four rulers\n"
        .equ    msglen, . - msg

        .section .text
        .globl  _start
_start:
        # Stuff a recognizable 64-bit pattern into rax.
        mov     rax, 0x1122334455667788

        # Poke the low byte. Only the bottom 8 bits change.
        # rax becomes 0x11223344556677AA
        mov     al,  0xAA

        # Poke the low word (16 bits). Top 48 bits unchanged.
        # rax becomes 0x112233445566BBCC
        mov     ax,  0xBBCC

        # Poke the low dword (32 bits). SURPRISE: top 32 bits wiped to 0.
        # rax becomes 0x00000000DDEEFF00
        mov     eax, 0xDDEEFF00

        # Print a short banner so you know it ran.
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + msg]
        mov     rdx, msglen
        syscall

        # Exit 0.
        mov     rax, 60
        xor     rdi, rdi
        syscall
