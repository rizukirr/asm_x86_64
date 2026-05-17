.intel_syntax noprefix

# 04_cmov.s
# Demonstrates `cmov`: a conditional move that does NOT branch.
# We compute min(a, b) without any jumps in the hot path.
# Result is printed: "min(7, 3) = 3" and the program exits 0.

        .section .data
prefix: .ascii  "min(7, 3) = "
        .equ    prefixlen, . - prefix
out:    .ascii  "X\n"                    # placeholder digit; we overwrite 'X'
        .equ    outlen, . - out

        .section .text
        .globl  _start
_start:
        # rax = a, rbx = b; we want rax = min(a, b) branchlessly.
        mov     rax, 7                  # a
        mov     rbx, 3                  # b
        cmp     rax, rbx                # compare a, b
        cmovg   rax, rbx                # if a > b (signed), rax = b
                                        # now rax holds min(a, b) = 3

        # convert single-digit result to ASCII and store into `out`
        add     al, '0'                 # '0' + 3 = '3'
        lea     rcx, [rip + out]
        mov     [rcx], al               # write the digit byte

        # print "min(7, 3) = "
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + prefix]
        mov     rdx, prefixlen
        syscall

        # print "3\n"
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + out]
        mov     rdx, outlen
        syscall

        # exit 0
        mov     rax, 60
        xor     rdi, rdi
        syscall
