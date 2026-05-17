.intel_syntax noprefix

# Compute  120 / 7  -- quotient 17, remainder 1 -- using signed idiv,
# then print "17 r 1\n".
#
# Key detail: idiv divides rdx:rax (a 128-bit value) by its operand.
# Before idiv, you MUST sign-extend rax into rdx using cqo; for unsigned
# div, you'd zero rdx with `xor rdx, rdx` instead.  Forget this and the
# CPU will use whatever garbage is in rdx as the top half and you'll get
# either a #DE (divide error) trap or a wrong answer.

        .section .data
sep:    .ascii  " r "
        .equ    seplen, . - sep

        .section .bss
qbuf:   .skip   32
rbuf:   .skip   32

        .section .text
        .globl  _start
_start:
        mov     rax, 120
        cqo                             # rdx:rax = sign-extended 120
        mov     rcx, 7
        idiv    rcx                     # rax = 17 (quotient), rdx = 1 (remainder)

        mov     r12, rax                # save quotient
        mov     r13, rdx                # save remainder

# ---- print quotient (no trailing newline yet) ----
        mov     rax, r12
        lea     rdi, [rip + qbuf]
        add     rdi, 31
        mov     rcx, 0
        mov     rbx, 10
.Lq:
        xor     rdx, rdx
        div     rbx
        dec     rdi
        add     dl, '0'
        mov     [rdi], dl
        inc     rcx
        test    rax, rax
        jnz     .Lq
        mov     rsi, rdi
        mov     rdx, rcx
        mov     rax, 1
        mov     rdi, 1
        syscall

# ---- print " r " ----
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + sep]
        mov     rdx, seplen
        syscall

# ---- print remainder, with trailing newline ----
        mov     rax, r13
        lea     rdi, [rip + rbuf]
        add     rdi, 31
        mov     byte ptr [rdi], 10
        mov     rcx, 1
        mov     rbx, 10
.Lr:
        xor     rdx, rdx
        div     rbx
        dec     rdi
        add     dl, '0'
        mov     [rdi], dl
        inc     rcx
        test    rax, rax
        jnz     .Lr
        mov     rsi, rdi
        mov     rdx, rcx
        mov     rax, 1
        mov     rdi, 1
        syscall

        mov     rax, 60
        xor     rdi, rdi
        syscall
