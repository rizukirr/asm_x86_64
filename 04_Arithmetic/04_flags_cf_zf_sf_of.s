.intel_syntax noprefix

# Demonstrate the flags arithmetic sets.  We perform an unsigned overflow:
#   rax = 0xFFFFFFFFFFFFFFFF  (largest unsigned 64-bit value)
#   rax += 1
# The result wraps to 0.  After the add:
#   ZF = 1  (result is zero)
#   CF = 1  (unsigned overflow: a 65th bit was produced)
#   SF = 0  (top bit of result is 0)
#   OF = 0  (as signed, that's -1 + 1 = 0, no signed overflow)
#
# We use `setc`, `setz`, `sets`, `seto` -- one-byte instructions that read
# a single flag and store 0 or 1 into a register -- then print
# "CF=1 ZF=1 SF=0 OF=0\n".

        .section .data
prefix: .ascii  "CF="
        .equ    prefixlen, . - prefix
spzf:   .ascii  " ZF="
        .equ    spzflen, . - spzf
spsf:   .ascii  " SF="
        .equ    spsflen, . - spsf
spof:   .ascii  " OF="
        .equ    spsoflen, . - spof
nl:     .ascii  "\n"

        .section .text
        .globl  _start
_start:
        mov     rax, -1                 # 0xFFFFFFFFFFFFFFFF
        add     rax, 1                  # wraps to 0, sets CF and ZF

        setc    r12b                    # r12 = CF
        setz    r13b                    # r13 = ZF
        sets    r14b                    # r14 = SF
        seto    r15b                    # r15 = OF

# Each flag is now 0 or 1 in the low byte of r12..r15.  Add '0' to make ASCII
# and print one flag at a time, interleaved with the label strings.

        add     r12b, '0'
        add     r13b, '0'
        add     r14b, '0'
        add     r15b, '0'

# write "CF="
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + prefix]
        mov     rdx, prefixlen
        syscall

# write the CF digit:  push r12 byte onto stack and write 1 byte from rsp
        sub     rsp, 8
        mov     [rsp], r12b
        mov     rax, 1
        mov     rdi, 1
        mov     rsi, rsp
        mov     rdx, 1
        syscall
        add     rsp, 8

        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + spzf]
        mov     rdx, spzflen
        syscall
        sub     rsp, 8
        mov     [rsp], r13b
        mov     rax, 1
        mov     rdi, 1
        mov     rsi, rsp
        mov     rdx, 1
        syscall
        add     rsp, 8

        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + spsf]
        mov     rdx, spsflen
        syscall
        sub     rsp, 8
        mov     [rsp], r14b
        mov     rax, 1
        mov     rdi, 1
        mov     rsi, rsp
        mov     rdx, 1
        syscall
        add     rsp, 8

        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + spof]
        mov     rdx, spsoflen
        syscall
        sub     rsp, 8
        mov     [rsp], r15b
        mov     rax, 1
        mov     rdi, 1
        mov     rsi, rsp
        mov     rdx, 1
        syscall
        add     rsp, 8

        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + nl]
        mov     rdx, 1
        syscall

        mov     rax, 60
        xor     rdi, rdi
        syscall
