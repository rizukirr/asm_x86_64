.intel_syntax noprefix

# Demonstrates shl/shr/sar by printing one decimal-ish hex result per case.
# We compute four interesting things and exit with a checksum.
#
#   1) shl rax, 3   on 5         -> 40   (5 * 8)
#   2) shr rax, 1   on 16        -> 8    (16 / 2, unsigned)
#   3) shr rax, 1   on -8 (u64)  -> 0x7FFFFFFFFFFFFFFC  (huge positive)
#   4) sar rax, 1   on -8        -> -4   (signed divide by 2)
#
# Each result is printed as 16 hex digits + newline.

        .section .data
hdr1: .ascii "shl 5, 3       = 0x"
        .equ hdr1len, . - hdr1
hdr2: .ascii "\nshr 16, 1      = 0x"
        .equ hdr2len, . - hdr2
hdr3: .ascii "\nshr -8, 1 (u)  = 0x"
        .equ hdr3len, . - hdr3
hdr4: .ascii "\nsar -8, 1 (s)  = 0x"
        .equ hdr4len, . - hdr4
nl:   .ascii "\n"

# 16-byte scratch buffer for one hex value.
        .section .bss
buf:    .skip 16

        .section .rodata
hexchars: .ascii "0123456789ABCDEF"

        .section .text
        .globl  _start

# print_hex64(rax = value)
# Fills `buf` with 16 hex chars (most significant first) and writes it.
print_hex64:
        lea     rdi, [rip + buf]
        lea     rdx, [rip + hexchars]
        mov     rcx, 16
.Lph_loop:
        mov     rsi, rax
        and     rsi, 0x0F               # low nibble of rax
        mov     sil, byte ptr [rdx + rsi]
        mov     byte ptr [rdi + rcx - 1], sil
        shr     rax, 4
        dec     rcx
        jnz     .Lph_loop

        mov     rax, 1                  # write
        mov     rdi, 1
        lea     rsi, [rip + buf]
        mov     rdx, 16
        syscall
        ret

# print(rsi=addr, rdx=len)
print:
        mov     rax, 1
        mov     rdi, 1
        syscall
        ret

_start:
        # Case 1: shl
        lea     rsi, [rip + hdr1]
        mov     rdx, hdr1len
        call    print
        mov     rax, 5
        shl     rax, 3                  # 5 << 3 = 40
        call    print_hex64

        # Case 2: shr (unsigned divide)
        lea     rsi, [rip + hdr2]
        mov     rdx, hdr2len
        call    print
        mov     rax, 16
        shr     rax, 1                  # 16 >> 1 = 8
        call    print_hex64

        # Case 3: shr on -8 (the gotcha)
        lea     rsi, [rip + hdr3]
        mov     rdx, hdr3len
        call    print
        mov     rax, -8                 # 0xFFFFFFFFFFFFFFF8
        shr     rax, 1                  # -> 0x7FFFFFFFFFFFFFFC
        call    print_hex64

        # Case 4: sar on -8 (the fix)
        lea     rsi, [rip + hdr4]
        mov     rdx, hdr4len
        call    print
        mov     rax, -8
        sar     rax, 1                  # -> 0xFFFFFFFFFFFFFFFC (= -4)
        call    print_hex64

        # Trailing newline.
        lea     rsi, [rip + nl]
        mov     rdx, 1
        call    print

        mov     rax, 60
        xor     rdi, rdi
        syscall
