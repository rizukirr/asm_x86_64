.intel_syntax noprefix

# Demonstrates the three forms of imul.
#   1-operand:  imul rcx        -> rdx:rax = rax * rcx  (full 128-bit result)
#   2-operand:  imul rax, rcx   -> rax     = rax * rcx  (low 64 bits only)
#   3-operand:  imul rax, rcx,K -> rax     = rcx * K
#
# We compute  ((6 * 7) using 2-operand)  then  multiply by 3 using 3-operand,
# producing 126.  Expected output: "126\n".

        .section .bss
buf:    .skip   32

        .section .text
        .globl  _start
_start:
        mov     rax, 6
        mov     rcx, 7
        imul    rax, rcx                # rax = 42

        imul    rax, rax, 3             # rax = 126

# ---- Also exercise the 1-operand form just so the assembler emits it.
# rdx will be clobbered, so do this before we need rdx for our itoa routine.
        mov     r8,  rax                # save 126
        mov     rax, 1000000000         # 1e9
        mov     rcx, 1000000000         # 1e9
        imul    rcx                     # rdx:rax = 1e18 -- doesn't fit in 64 bits
        mov     rax, r8                 # restore 126 for printing

# ---- itoa ----
        lea     rdi, [rip + buf]
        add     rdi, 31
        mov     byte ptr [rdi], 10
        mov     rcx, 1
        mov     rbx, 10
.Lconv:
        xor     rdx, rdx
        div     rbx
        dec     rdi
        add     dl, '0'
        mov     [rdi], dl
        inc     rcx
        test    rax, rax
        jnz     .Lconv

        mov     rsi, rdi
        mov     rdx, rcx
        mov     rax, 1
        mov     rdi, 1
        syscall

        mov     rax, 60
        xor     rdi, rdi
        syscall
