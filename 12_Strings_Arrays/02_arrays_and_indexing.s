.intel_syntax noprefix

        .section .data
# An array of five 8-byte (quadword) integers. Each cell is 8 bytes wide,
# so element i lives at byte offset i*8 from the start of the array.
nums:   .quad   10, 20, 30, 7, 8
        .equ    nums_count, (. - nums) / 8      # = 5, computed at assemble time

label:  .ascii  "sum = "
        .equ    labellen, . - label

        .section .bss
# Two bytes of scratch space for "ASCII digit + newline" output.
out:    .skip   2

        .section .text
        .globl  _start

_start:
        # rax will hold the running total. Start at 0.
        xor     rax, rax
        # rcx is our index i, also starting at 0.
        xor     rcx, rcx

.loop:
        cmp     rcx, nums_count         # i < count ?
        jge     .done
        # [base + index*scale] is the array-access addressing mode.
        # rip-relative base + rcx*8 picks out the i-th 8-byte element.
        lea     rdx, [rip + nums]
        add     rax, [rdx + rcx*8]
        inc     rcx
        jmp     .loop

.done:
        # rax = 10 + 20 + 30 + 7 + 8 = 75. We want to print "75\n".
        # 75 fits in one byte; we will print it as two ASCII digits by
        # dividing by 10. (Real number-printing comes later; one digit
        # at a time is enough to see the answer.)
        # tens digit:
        mov     rbx, rax                # save total
        xor     rdx, rdx
        mov     rcx, 10
        div     rcx                     # rax = total/10, rdx = total%10
        add     al, '0'                 # tens -> ASCII
        mov     [rip + out], al
        add     dl, '0'                 # ones -> ASCII
        mov     [rip + out + 1], dl

        # print "sum = "
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + label]
        mov     rdx, labellen
        syscall

        # print the two digits
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + out]
        mov     rdx, 2
        syscall

        # print a trailing newline
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + newline]
        mov     rdx, 1
        syscall

        mov     rax, 60
        xor     rdi, rdi
        syscall

        .section .rodata
newline: .ascii "\n"
