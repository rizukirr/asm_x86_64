.intel_syntax noprefix

# Computes  ((10 + 5) - 1) ; then increments to 15, decrements to 14, negates to -14,
# and finally prints the *absolute* result.  Expected output: "15\n".
#
# After the work is done, rax holds 15.  We turn that small integer into ASCII
# digits and write them with the write syscall.

        .section .bss
buf:    .skip   32                      # scratch space for digit characters

        .section .text
        .globl  _start
_start:
        mov     rax, 10                 # rax = 10
        mov     rbx, 5                  # rbx = 5
        add     rax, rbx                # rax = 15
        sub     rax, 1                  # rax = 14
        inc     rax                     # rax = 15
        dec     rax                     # rax = 14
        neg     rax                     # rax = -14
        neg     rax                     # rax = 14
        inc     rax                     # rax = 15  (final value to print)

# ---- itoa: convert rax (assumed >= 0, fits in 64 bits) to decimal in buf ----
# Strategy: repeatedly divide by 10, write the remainder digit from the back
# of the buffer toward the front.  rsi will point at the first character;
# rdx (after) holds the count of bytes to write.

        lea     rdi, [rip + buf]
        add     rdi, 31                 # rdi -> one past end of buffer
        mov     byte ptr [rdi], 10      # trailing newline
        mov     rcx, 1                  # length so far (just the newline)
        mov     rbx, 10                 # divisor

.Lconv:
        xor     rdx, rdx                # clear rdx for unsigned div
        div     rbx                     # rax = rax/10, rdx = rax%10
        dec     rdi                     # move write pointer left
        add     dl, '0'                 # digit -> ascii
        mov     [rdi], dl               # store it
        inc     rcx                     # one more byte to write
        test    rax, rax
        jnz     .Lconv

# ---- write(1, rdi, rcx) ----
        mov     rsi, rdi                # buf start
        mov     rdx, rcx                # length
        mov     rax, 1                  # write
        mov     rdi, 1                  # stdout
        syscall

        mov     rax, 60                 # exit
        xor     rdi, rdi                # status 0
        syscall
