.intel_syntax noprefix

        .section .data
msg:    .ascii  "Hello, CPU!\n"
        .equ    msglen, . - msg

        .section .text
        .globl  _start
_start:
        mov     rax, 1          # syscall number: write
        mov     rdi, 1          # fd: stdout
        lea     rsi, [rip + msg]# buffer pointer
        mov     rdx, msglen     # length
        syscall

        mov     rax, 60         # syscall number: exit
        xor     rdi, rdi        # status = 0
        syscall
