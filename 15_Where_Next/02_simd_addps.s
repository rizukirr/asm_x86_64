.intel_syntax noprefix

        .section .rodata
        .align  16
a:      .float  1.0, 2.0, 3.0, 4.0
b:      .float  10.0, 20.0, 30.0, 40.0

        .section .text
        .globl  _start
_start:
        movaps  xmm0, [rip + a]         # load 4 floats:  1, 2, 3, 4
        movaps  xmm1, [rip + b]         # load 4 floats: 10,20,30,40
        addps   xmm0, xmm1              # parallel add: 11,22,33,44

        # take lane 0 (= 11.0) and use it as the exit code.
        cvttss2si edi, xmm0             # rdi = (int)11.0 = 11

        mov     rax, 60                 # syscall: exit
        syscall
