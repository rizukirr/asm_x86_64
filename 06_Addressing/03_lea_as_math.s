.intel_syntax noprefix

        .section .text
        .globl  _start
_start:
        # Pretend x = 7.  Compute  5*x + 3  in ONE instruction.
        mov     rcx, 7                  # rcx = x
        lea     rax, [rcx*4 + rcx + 3]  # rax = 4*rcx + rcx + 3 = 5*rcx + 3 = 38

        # Also demo: 3-operand add without destroying inputs.
        mov     rbx, 10
        mov     rdx, 20
        lea     rdi, [rbx + rdx]        # rdi = 30, rbx and rdx unchanged

        # Exit with rax (38) so we can verify via $?.
        mov     rdi, rax
        mov     rax, 60
        syscall
