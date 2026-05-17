.intel_syntax noprefix

        .section .data
src:    .ascii  "copied with rep movsb\n"
        .equ    srclen, . - src

        .section .bss
dst:    .skip   64                      # destination buffer for the copy
fill:   .skip   8                       # eight bytes we will paint with stosb

        .section .text
        .globl  _start

_start:
        # ---- rep movsb: copy srclen bytes from src to dst ---------------
        cld                             # DF = 0 -> walk forward
        lea     rsi, [rip + src]        # source pointer (S = source)
        lea     rdi, [rip + dst]        # destination pointer (D = destination)
        mov     rcx, srclen             # how many bytes to copy
        rep     movsb                   # while (rcx--) *rdi++ = *rsi++

        # Print the copied buffer to prove the copy worked.
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + dst]
        mov     rdx, srclen
        syscall

        # ---- rep stosb: paint eight '*' bytes plus a newline ------------
        cld
        lea     rdi, [rip + fill]
        mov     al, '*'                 # the byte to repeat
        mov     rcx, 7
        rep     stosb                   # while (rcx--) *rdi++ = al
        mov     byte ptr [rip + fill + 7], '\n'

        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + fill]
        mov     rdx, 8
        syscall

        mov     rax, 60
        xor     rdi, rdi
        syscall
