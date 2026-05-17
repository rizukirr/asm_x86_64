.intel_syntax noprefix

        .section .data
# We will print the digits 1, 2, 3, 4, 5 followed by a newline.
# One byte of memory holds the ASCII code of the current digit.
digit:  .byte   '0'
nl:     .byte   '\n'

        .section .text
        .globl  _start
_start:
        # The kernel clobbers rcx and r11 on every `syscall`. So we keep the
        # loop counter in a callee-saved register (r12) instead of rcx.
        mov     r12, 5                  # counter: print 5 digits
        mov     bl, '1'                 # bl holds the current ASCII digit

.loop:
        lea     rsi, [rip + digit]      # rsi -> digit
        mov     [rsi], bl               # store current digit into the byte
        # write(1, &digit, 1)
        mov     rax, 1
        mov     rdi, 1
        mov     rdx, 1
        syscall

        inc     bl                      # next ASCII digit
        dec     r12                     # tick the counter down
        jnz     .loop                   # if r12 != 0, go round again

        # write a single newline
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + nl]
        mov     rdx, 1
        syscall

        mov     rax, 60                 # exit(0)
        xor     rdi, rdi
        syscall
