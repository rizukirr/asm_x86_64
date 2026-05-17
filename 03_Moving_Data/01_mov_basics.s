.intel_syntax noprefix

        .section .data
val:    .quad   0x1122334455667788
out:    .ascii  "rax low byte was replaced with 0xAA\n"
        .equ    outlen, . - out

        .section .text
        .globl  _start
_start:
        # --- Demo 1: register <- immediate ---
        mov     rax, 0x1122334455667788     # 64-bit immediate (movabs form)

        # --- Demo 2: register <- memory (a load) ---
        mov     rbx, [rip + val]            # rbx = 0x1122334455667788

        # --- Demo 3: partial-register write ---
        mov     bl, 0xAA                    # only the low byte of rbx changes
                                            # rbx = 0x11223344556677AA

        # --- Demo 4: memory <- register (a store) ---
        mov     [rip + val], rbx            # val now holds 0x11223344556677AA

        # --- Demo 5: memory <- immediate (needs a size hint) ---
        mov     qword ptr [rip + val], 0    # zero the 8-byte slot

        # --- Tell the user we got here ---
        mov     rax, 1                      # write
        mov     rdi, 1                      # stdout
        lea     rsi, [rip + out]
        mov     rdx, outlen
        syscall

        # --- Exit cleanly ---
        mov     rax, 60                     # exit
        xor     rdi, rdi                    # status 0
        syscall
