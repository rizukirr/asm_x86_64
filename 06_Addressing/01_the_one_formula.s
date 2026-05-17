.intel_syntax noprefix

        .section .data
arr:    .long   10, 20, 30, 40, 50      # 5 ints, 4 bytes each
        .equ    arrlen, 5

        .section .text
        .globl  _start
_start:
        lea     rbx, [rip + arr]        # rbx = &arr[0]
        mov     rcx, arrlen             # rcx = n
        xor     eax, eax                # rax = 0  (sum accumulator)
        xor     rdx, rdx                # rdx = i  (index)
.loop:
        cmp     rdx, rcx
        jge     .done
        add     eax, [rbx + rdx*4]      # eax += arr[i]  (the magic line)
        inc     rdx
        jmp     .loop
.done:
        mov     rdi, rax                # exit code = sum (should be 150)
        mov     rax, 60                 # syscall: exit
        syscall
