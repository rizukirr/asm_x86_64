.intel_syntax noprefix

# 01_stack_basics.s
# Print rsp's value (as hex) at program start, then exit cleanly.
# This is the value the Linux kernel handed us — the top of our stack.

        .section .bss
buf:    .skip   32                      # scratch space for the printed string

        .section .data
prefix: .ascii  "rsp = 0x"
        .equ    prefix_len, . - prefix
nl:     .ascii  "\n"

        .section .text
        .globl  _start

# ------------------------------------------------------------------
# _start
#
# 1. Save rsp into rax.
# 2. Convert rax (an 8-byte value) into 16 hex digits at `buf`.
# 3. write(stdout, "rsp = 0x", 8); write(stdout, buf, 16); write(stdout, "\n", 1).
# 4. exit(0).
# ------------------------------------------------------------------
_start:
        mov     rax, rsp                # snapshot the stack pointer

        # --- convert rax to 16 hex characters, written into buf[0..16] ---
        lea     rdi, [rip + buf]        # rdi -> write cursor (start of buf)
        mov     rcx, 16                 # 16 nibbles in a 64-bit value
.Lhex:
        rol     rax, 4                  # rotate top nibble down to bits 0..3
        mov     rdx, rax
        and     rdx, 0xf                # isolate that nibble
        cmp     rdx, 9
        jbe     .Ldigit
        add     rdx, 'a' - 10 - '0'     # 'a'..'f' adjustment
.Ldigit:
        add     rdx, '0'
        mov     [rdi], dl
        inc     rdi
        dec     rcx
        jnz     .Lhex

        # --- write "rsp = 0x" ---
        mov     rax, 1                  # write
        mov     rdi, 1                  # stdout
        lea     rsi, [rip + prefix]
        mov     rdx, prefix_len
        syscall

        # --- write the 16 hex digits ---
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + buf]
        mov     rdx, 16
        syscall

        # --- write newline ---
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + nl]
        mov     rdx, 1
        syscall

        # --- exit(0) ---
        mov     rax, 60
        xor     rdi, rdi
        syscall
