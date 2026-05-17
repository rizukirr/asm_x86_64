.intel_syntax noprefix

# Two demos in one program:
#   1. Nested loop printing a 3x3 grid of '*' characters.
#   2. Sum a small array of 8-byte integers and print the total.
# Final printed output:
#   ***
#   ***
#   ***
#   sum=21

        .section .data
arr:    .quad   1, 2, 3, 4, 5, 6        # 6 quadwords; sum = 21
        .equ    arrlen, (. - arr) / 8   # element count

star:   .byte   '*'
nl:     .byte   '\n'
lbl:    .ascii  "sum="
        .equ    lbllen, . - lbl

        .section .bss
numbuf: .skip   32                      # scratch for decimal digits

        .section .text
        .globl  _start
_start:
        # ---- nested loop: 3 rows of 3 stars ----
        mov     r12, 3                  # outer counter (rows)
.row:
        mov     r13, 3                  # inner counter (cols)
.col:
        mov     rax, 1                  # write(1, &star, 1)
        mov     rdi, 1
        lea     rsi, [rip + star]
        mov     rdx, 1
        syscall
        dec     r13
        jnz     .col

        mov     rax, 1                  # write(1, &nl, 1)
        mov     rdi, 1
        lea     rsi, [rip + nl]
        mov     rdx, 1
        syscall

        dec     r12
        jnz     .row

        # ---- array sum: rax = sum(arr[0..arrlen]) ----
        xor     rax, rax                # running sum
        xor     rcx, rcx                # i = 0
        lea     r14, [rip + arr]        # base pointer
.sum:
        cmp     rcx, arrlen
        jge     .sum_done
        add     rax, [r14 + rcx*8]      # sum += arr[i]
        inc     rcx
        jmp     .sum
.sum_done:

        # print "sum="
        mov     r15, rax                # save sum in callee-saved r15
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + lbl]
        mov     rdx, lbllen
        syscall

        # convert r15 to decimal digits in numbuf (right-to-left)
        mov     rax, r15
        lea     rdi, [rip + numbuf + 32]
        mov     rbx, 10
.cvt:
        test    rax, rax
        jz      .cvt_done
        xor     rdx, rdx
        div     rbx
        add     dl, '0'
        dec     rdi
        mov     [rdi], dl
        jmp     .cvt
.cvt_done:
        lea     rsi, [rip + numbuf + 32]
        mov     rdx, rsi
        sub     rdx, rdi
        mov     rsi, rdi
        mov     rax, 1
        mov     rdi, 1
        syscall

        # trailing newline
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + nl]
        mov     rdx, 1
        syscall

        mov     rax, 60
        xor     rdi, rdi
        syscall
