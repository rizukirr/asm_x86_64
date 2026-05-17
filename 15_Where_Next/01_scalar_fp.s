.intel_syntax noprefix

        .section .rodata
        .align  8
two:    .double 2.0
three:  .double 3.0

        .section .text
        .globl  _start
_start:
        movsd   xmm0, [rip + two]       # xmm0 = 2.0
        movsd   xmm1, [rip + three]     # xmm1 = 3.0
        addsd   xmm0, xmm1              # xmm0 = 5.0
        cvttsd2si edi, xmm0             # rdi = (int)5.0 = 5

        mov     rax, 60                 # syscall: exit
        syscall
