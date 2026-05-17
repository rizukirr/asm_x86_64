.intel_syntax noprefix

# Use the legacy `loop` instruction to print 'A' 'B' 'C' 'D' 'E' then a newline.
# Lesson: it works fine, it is short to type, but it is slower than
# `dec rcx ; jnz` on modern CPUs. Treat it as a museum piece.

        .section .data
digit:     .byte   'A'
nl:     .byte   '\n'

        .section .text
        .globl  _start
_start:
        mov     rcx, 5                  # `loop` always uses rcx
        mov     bl, 'A'

.body:
        lea     rsi, [rip + digit]
        mov     [rsi], bl

        # write(1, &digit, 1)
        # Save rcx around the syscall: kernel may clobber it via rcx/r11.
        push    rcx
        mov     rax, 1
        mov     rdi, 1
        mov     rdx, 1
        syscall
        pop     rcx

        inc     bl
        loop    .body                   # rcx-- ; if rcx != 0 jump .body

        # newline
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + nl]
        mov     rdx, 1
        syscall

        mov     rax, 60
        xor     rdi, rdi
        syscall
