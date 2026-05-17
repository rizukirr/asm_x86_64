.intel_syntax noprefix

        .section .data
banner: .ascii  "aligned call returned 7\n"
        .equ    blen, . - banner

        .section .text
        .globl  _start

# A leaf that just returns 7.
seven:
        mov     rax, 7
        ret

# A non-leaf: it calls `seven` from inside.
# Because we call something, we MUST keep rsp 16-aligned at the `call`.
#
# On entry, rsp is 8 mod 16 (the parent's `call` pushed 8 bytes).
# `push rbp` pushes another 8 -> rsp is back to 16-aligned. Good.
# No locals, so we call straight through.
wrapper:
        push    rbp             # 1) save callee-saved, 2) re-align to 16
        mov     rbp, rsp
        call    seven           # rsp is 16-aligned here — SIMD-safe
        # rax now holds 7
        mov     rsp, rbp
        pop     rbp
        ret

_start:
        # Print banner.
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + banner]
        mov     rdx, blen
        syscall

        # At program entry, the kernel hands us a 16-aligned rsp.
        # `call wrapper` will push 8 bytes -> wrapper sees rsp = 8 mod 16,
        # which is the documented entry state.
        call    wrapper

        mov     rdi, rax        # rdi = 7
        mov     rax, 60
        syscall
