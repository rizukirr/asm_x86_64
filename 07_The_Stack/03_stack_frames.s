.intel_syntax noprefix

# 03_stack_frames.s
# Build a manual stack frame: carve 32 bytes of scratch, store four values,
# then read them back out and exit with their sum.
#
# 1 + 2 + 3 + 4 = 10. The program exits with status 10.

        .section .text
        .globl  _start
_start:
        # --- prologue: anchor rbp and carve 32 bytes of locals ---
        push    rbp                     # save caller's rbp (the kernel's, here)
        mov     rbp, rsp                # rbp now points at our frame anchor
        sub     rsp, 32                 # 32 bytes of scratch below rbp

        # --- store four 8-byte locals at fixed offsets from rbp ---
        mov     qword ptr [rbp - 8],  1
        mov     qword ptr [rbp - 16], 2
        mov     qword ptr [rbp - 24], 3
        mov     qword ptr [rbp - 32], 4

        # --- read them back and sum into rax ---
        xor     rax, rax
        add     rax, [rbp - 8]
        add     rax, [rbp - 16]
        add     rax, [rbp - 24]
        add     rax, [rbp - 32]         # rax = 10

        # --- epilogue: undo the prologue exactly ---
        mov     rsp, rbp                # discard the 32-byte local area
        pop     rbp                     # restore caller's rbp

        # --- exit(rax) ---
        mov     rdi, rax
        mov     rax, 60
        syscall
