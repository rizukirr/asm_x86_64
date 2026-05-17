.intel_syntax noprefix

# 02_push_pop.s
# Push 1, 2, 3 onto the stack, then pop them back.
# Because the stack is LIFO, they come out reversed:
#   first pop  -> 3
#   second pop -> 2
#   third pop  -> 1
# Exit with the FIRST pop as the status, so `echo $?` should print 3.

        .section .text
        .globl  _start
_start:
        mov     rax, 1
        mov     rbx, 2
        mov     rcx, 3

        push    rax                     # rsp -= 8; [rsp] = 1
        push    rbx                     # rsp -= 8; [rsp] = 2
        push    rcx                     # rsp -= 8; [rsp] = 3

        pop     r10                     # r10 = 3 (last pushed comes off first)
        pop     r11                     # r11 = 2
        pop     r12                     # r12 = 1

        mov     rdi, r10                # exit status = 3
        mov     rax, 60
        syscall
