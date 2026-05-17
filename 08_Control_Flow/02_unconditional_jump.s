.intel_syntax noprefix

# 02_unconditional_jump.s
# Demonstrates `jmp`: an instruction that always moves the bookmark.
# We jump over a block that would print "BAD" and land at a block that
# prints "GOOD jump landed here". Exits 0.

        .section .data
good:   .ascii  "GOOD: jmp landed here\n"
        .equ    goodlen, . - good
bad:    .ascii  "BAD: should never print\n"
        .equ    badlen, . - bad

        .section .text
        .globl  _start
_start:
        jmp     .target                 # always taken, no condition

        # --- this block is skipped over ---
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + bad]
        mov     rdx, badlen
        syscall

.target:
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + good]
        mov     rdx, goodlen
        syscall

        # exit 0
        mov     rax, 60
        xor     rdi, rdi
        syscall
