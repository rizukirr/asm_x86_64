.intel_syntax noprefix

# 01_cmp_and_test.s
# Demonstrates `cmp` and `test` setting RFLAGS without changing operands.
# We compare 7 vs 7 (equal), then test whether rax is zero, and print
# a message describing which flags were set. Exits with status 0.

        .section .data
msg1:   .ascii  "cmp 7,7 -> ZF=1 (equal)\n"
        .equ    msg1len, . - msg1
msg2:   .ascii  "test rax,rax -> ZF=1 (rax was zero)\n"
        .equ    msg2len, . - msg2
msg3:   .ascii  "values are unchanged: rax still 7\n"
        .equ    msg3len, . - msg3

        .section .text
        .globl  _start
_start:
        # --- cmp: subtract-and-discard, only flags survive ---
        mov     rax, 7
        mov     rbx, 7
        cmp     rax, rbx                # 7 - 7 = 0  -> ZF=1
        jne     .skip1                  # if not equal, skip the print
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + msg1]
        mov     rdx, msg1len
        syscall
.skip1:

        # --- test: bitwise AND, discard, only flags survive ---
        # test rax,rax asks "is rax zero?" -> we set rax = 0 first
        xor     rax, rax                # rax = 0
        test    rax, rax                # 0 & 0 = 0 -> ZF=1
        jnz     .skip2                  # if nonzero, skip
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + msg2]
        mov     rdx, msg2len
        syscall
.skip2:

        # --- prove cmp did not change rax: put 7 back, cmp with 9, then verify ---
        mov     rax, 7
        cmp     rax, 9                  # rax stays 7 even after cmp
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + msg3]
        mov     rdx, msg3len
        syscall

        # exit 0
        mov     rax, 60
        xor     rdi, rdi
        syscall
