.intel_syntax noprefix

# 03_conditional_jumps.s
# Demonstrates signed vs unsigned conditional jumps.
# Compares -1 with 1 using both interpretations and prints which branch ran.
#
# Signed view:   -1 < 1   (jl is taken)
# Unsigned view: -1 is 0xFFFFFFFFFFFFFFFF, which is > 1 (ja is taken)
# Same bits, different question, different jump. This is the classic trap.

        .section .data
sig:    .ascii  "signed: -1 < 1  -> jl taken\n"
        .equ    siglen, . - sig
uns:    .ascii  "unsigned: -1 (as bits) > 1 -> ja taken\n"
        .equ    unslen, . - uns
eqm:    .ascii  "equality: 42 == 42 -> je taken\n"
        .equ    eqlen, . - eqm

        .section .text
        .globl  _start
_start:
        # --- signed comparison: rax = -1, rbx = 1 ---
        mov     rax, -1
        mov     rbx, 1
        cmp     rax, rbx                # signed: -1 < 1 -> SF != OF, jl taken
        jnl     .not_signed_less        # jnl == jge: skip if NOT less
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + sig]
        mov     rdx, siglen
        syscall
.not_signed_less:

        # --- unsigned comparison: same bits, different question ---
        mov     rax, -1                 # bits: 0xFFFFFFFFFFFFFFFF (huge unsigned)
        mov     rbx, 1
        cmp     rax, rbx                # unsigned: huge > 1 -> CF=0, ZF=0, ja taken
        jna     .not_unsigned_above     # jna: skip if NOT above
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + uns]
        mov     rdx, unslen
        syscall
.not_unsigned_above:

        # --- equality (works for both signed and unsigned) ---
        mov     rax, 42
        mov     rbx, 42
        cmp     rax, rbx                # equal -> ZF=1
        jne     .not_equal
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + eqm]
        mov     rdx, eqlen
        syscall
.not_equal:

        # exit 0
        mov     rax, 60
        xor     rdi, rdi
        syscall
