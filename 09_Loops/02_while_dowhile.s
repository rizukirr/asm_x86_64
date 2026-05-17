.intel_syntax noprefix

# Demonstrate while and do-while shapes by computing 1+2+...+10 = 55,
# converting that to ASCII, and printing it.
#
# Both loop shapes are present:
#   - a do-while accumulating the sum
#   - a while loop converting the number to decimal digits

        .section .bss
buf:    .skip   32                      # 32-byte scratch for digits

        .section .data
nl:     .byte   '\n'

        .section .text
        .globl  _start
_start:
        # ---- do-while: sum = 0; i = 1; do { sum += i; i++; } while (i <= 10) ----
        xor     rax, rax                # sum  = 0
        mov     rcx, 1                  # i    = 1
.sum_loop:
        add     rax, rcx                # sum += i
        inc     rcx                     # i++
        cmp     rcx, 10
        jle     .sum_loop               # keep going while i <= 10

        # rax now holds 55. Convert to decimal text in buf (right-to-left).
        lea     rdi, [rip + buf + 32]   # rdi = one past end of buf
        mov     rbx, 10                 # divisor

        # ---- while: while (rax != 0) { *--rdi = '0' + rax%10; rax /= 10; } ----
.cvt_test:
        test    rax, rax
        jz      .cvt_done               # exit when rax == 0
        xor     rdx, rdx
        div     rbx                     # rax = rax/10, rdx = rax%10
        add     dl, '0'
        dec     rdi
        mov     [rdi], dl
        jmp     .cvt_test
.cvt_done:
        # rdi points at the first digit; length = (buf+32) - rdi
        lea     rsi, [rip + buf + 32]
        mov     rdx, rsi
        sub     rdx, rdi                # rdx = number of digits
        mov     rsi, rdi

        mov     rax, 1                  # write(1, digits, rdx)
        mov     rdi, 1
        syscall

        mov     rax, 1                  # newline
        mov     rdi, 1
        lea     rsi, [rip + nl]
        mov     rdx, 1
        syscall

        mov     rax, 60
        xor     rdi, rdi
        syscall
