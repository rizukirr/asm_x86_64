.intel_syntax noprefix

        .section .data
banner: .ascii  "sum6(1,2,3,4,5,6) = 21\n"
        .equ    blen, . - banner

        .section .text
        .globl  _start

# unsigned long sum6(unsigned long a, unsigned long b, unsigned long c,
#                    unsigned long d, unsigned long e, unsigned long f)
# args: rdi, rsi, rdx, rcx, r8, r9        return: rax
sum6:
        mov     rax, rdi        # rax = a
        add     rax, rsi        # + b
        add     rax, rdx        # + c
        add     rax, rcx        # + d
        add     rax, r8         # + e
        add     rax, r9         # + f
        ret                     # 21 is in rax

_start:
        # Print the banner so the result is visible.
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + banner]
        mov     rdx, blen
        syscall

        # Load all six arg registers, per the SysV AMD64 rulebook.
        mov     rdi, 1          # 1st: rdi
        mov     rsi, 2          # 2nd: rsi
        mov     rdx, 3          # 3rd: rdx
        mov     rcx, 4          # 4th: rcx
        mov     r8,  5          # 5th: r8
        mov     r9,  6          # 6th: r9
        call    sum6
        # rax now holds 21.

        mov     rdi, rax
        mov     rax, 60
        syscall
