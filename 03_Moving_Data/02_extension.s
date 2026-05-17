.intel_syntax noprefix

        .section .data
msg:    .ascii  "extension demo done\n"
        .equ    msglen, . - msg

        .section .text
        .globl  _start
_start:
        # Start with bl = 0xFF (which is -1 signed, 255 unsigned).
        mov     rbx, 0
        mov     bl,  0xFF

        # Zero-extend bl into rcx.
        # Expect rcx = 0x00000000000000FF (= 255).
        movzx   rcx, bl

        # Sign-extend bl into rdx.
        # Expect rdx = 0xFFFFFFFFFFFFFFFF (= -1).
        movsx   rdx, bl

        # 16 -> 64 sign-extend: take bx (0x00FF, +255 as 16-bit signed)
        # The top bit of bx is 0, so sign-extend gives +255 in r8.
        movsx   r8, bx

        # 32 -> 64 sign-extend with movsxd.
        # Put 0xFFFFFFFF in eax (= -1 as 32-bit signed).
        mov     eax, 0xFFFFFFFF
        movsxd  r9, eax                 # r9 = 0xFFFFFFFFFFFFFFFF

        # The "free" zero-extend trick: writing eax clears the top of rax.
        # No movzxd needed; the CPU does it for you.
        mov     r10d, 0x7FFFFFFF        # writing r10d zero-extends r10
                                        # r10 = 0x000000007FFFFFFF

        # Print a friendly message and exit.
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + msg]
        mov     rdx, msglen
        syscall

        mov     rax, 60
        xor     rdi, rdi
        syscall
