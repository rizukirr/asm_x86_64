.intel_syntax noprefix

        .section .data
banner: .ascii  "square_plus(6, 6) = 42\n"
        .equ    blen, . - banner

        .section .text
        .globl  _start

# long square_plus(long x, long y) {
#     long sq = x * x;       // a real local on the stack
#     return sq + y;
# }
square_plus:
        push    rbp                     # save caller's rbp (callee-saved)
        mov     rbp, rsp                # rbp = stable anchor for this frame
        sub     rsp, 16                 # 16 bytes of locals (8 used, 8 padding)

        mov     rax, rdi
        imul    rax, rdi                # rax = x * x
        mov     [rbp - 8], rax          # store local `sq`

        mov     rax, [rbp - 8]          # reload sq
        add     rax, rsi                # + y

        mov     rsp, rbp                # tear down frame
        pop     rbp                     # restore caller's rbp
        ret

_start:
        # Print banner.
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + banner]
        mov     rdx, blen
        syscall

        mov     rdi, 6                  # x
        mov     rsi, 6                  # y
        call    square_plus             # rax <- 36 + 6 = 42

        mov     rdi, rax
        mov     rax, 60
        syscall
