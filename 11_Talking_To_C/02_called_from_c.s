.intel_syntax noprefix

        .section .text
        .globl  sum3

# long sum3(long a, long b, long c);
# args:   rdi = a, rsi = b, rdx = c
# return: rax = a + b + c
sum3:
        mov     rax, rdi
        add     rax, rsi
        add     rax, rdx
        ret
