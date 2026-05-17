.intel_syntax noprefix

        .section .data
msg1:   .ascii  "stdout: hello\n"
        .equ    msg1len, . - msg1
msg2:   .ascii  "stderr: also hello\n"
        .equ    msg2len, . - msg2

        .section .text
        .globl  _start
_start:
        # write(1, msg1, msg1len)  -- to stdout
        mov     rax, 1                  # syscall: write
        mov     rdi, 1                  # fd 1 = stdout
        lea     rsi, [rip + msg1]
        mov     rdx, msg1len
        syscall

        # write(2, msg2, msg2len)  -- to stderr
        mov     rax, 1                  # syscall: write
        mov     rdi, 2                  # fd 2 = stderr
        lea     rsi, [rip + msg2]
        mov     rdx, msg2len
        syscall

        # exit(0)
        mov     rax, 60
        xor     rdi, rdi
        syscall
