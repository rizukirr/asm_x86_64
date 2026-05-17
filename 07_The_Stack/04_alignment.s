.intel_syntax noprefix

# 04_alignment.s
# Demonstrate the 16-byte stack-alignment rule by checking rsp & 15
# at two points:
#
#   (a) At _start, the kernel guarantees rsp is 16-byte aligned, so
#       rsp & 15 == 0.
#   (b) After a `call`, the callee sees rsp & 15 == 8, because `call`
#       pushed an 8-byte return address.
#
# We exit with status equal to (low_nibble_at_start * 16) + low_nibble_in_callee.
# Expected: 0 * 16 + 8 = 8.

        .section .text
        .globl  _start
_start:
        # --- measure low 4 bits of rsp at entry ---
        mov     rax, rsp
        and     rax, 15                 # rax = 0 (kernel aligns us to 16)
        shl     rax, 4                  # park it in the high nibble of the byte
        mov     r12, rax                # stash in a callee-saved scratch

        # --- now `call` a helper. `call` pushes 8 bytes (the return address),
        #     so inside the helper rsp will be 8 mod 16. ---
        call    measure_inside

        # rax was set by measure_inside to (rsp & 15) at its entry. Combine.
        or      rax, r12                # rax = (start_nibble << 4) | inside_nibble

        mov     rdi, rax                # exit status
        mov     rax, 60
        syscall

# ------------------------------------------------------------------
# measure_inside
#
# Returns (rsp & 15) at function entry in rax. Does not touch the stack
# beyond the return address pushed by `call`, so its measurement reflects
# exactly the alignment a real callee would see.
# ------------------------------------------------------------------
measure_inside:
        mov     rax, rsp
        and     rax, 15                 # 8 — because `call` pushed 8 bytes
        ret
