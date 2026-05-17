.intel_syntax noprefix

        .section .data
msg:    .ascii  "RIP-relative works!\n"
        .equ    msglen, . - msg

counter:
        .quad   42                      # an 8-byte number named 'counter'

        .section .text
        .globl  _start
_start:
        # Print the message using RIP-relative addressing for the buffer.
        mov     rax, 1                  # syscall: write
        mov     rdi, 1                  # fd: stdout
        lea     rsi, [rip + msg]        # rsi = address of msg (RIP-relative)
        mov     rdx, msglen
        syscall

        # Load the 8-byte value at 'counter' into rdi for the exit code.
        mov     rdi, [rip + counter]    # rdi = 42

        mov     rax, 60                 # syscall: exit
        syscall
