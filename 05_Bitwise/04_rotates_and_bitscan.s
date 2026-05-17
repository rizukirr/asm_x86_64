.intel_syntax noprefix

# Demonstrates rotates and the bit-scanning family.
#
#   rol 0x8000000000000001, 1 = 0x0000000000000003   (top bit wraps to bottom)
#   ror 0x0000000000000003, 1 = 0x8000000000000001   (bottom bit wraps to top)
#   popcnt(0b10110100)        = 4
#   bsf  (0b00010000)         = 4   (lowest ON bit is position 4)
#   bsr  (0b00010000)         = 4   (highest ON bit is also position 4)
#
# We then exit with the popcount as the status code so you can verify with
# `echo $?` after running.

        .section .data
hdr1: .ascii "rol 0x8000000000000001, 1 = 0x"
        .equ hdr1len, . - hdr1
hdr2: .ascii "\nror 0x0000000000000003, 1 = 0x"
        .equ hdr2len, . - hdr2
hdr3: .ascii "\npopcnt(0b10110100)        = 0x"
        .equ hdr3len, . - hdr3
hdr4: .ascii "\nbsf (0b00010000)          = 0x"
        .equ hdr4len, . - hdr4
hdr5: .ascii "\nbsr (0b00010000)          = 0x"
        .equ hdr5len, . - hdr5
nl:   .ascii "\n"

        .section .bss
buf:    .skip 16

        .section .rodata
hexchars: .ascii "0123456789ABCDEF"

        .section .text
        .globl  _start

print_hex64:
        lea     rdi, [rip + buf]
        lea     rdx, [rip + hexchars]
        mov     rcx, 16
.Lph_loop:
        mov     rsi, rax
        and     rsi, 0x0F
        mov     sil, byte ptr [rdx + rsi]
        mov     byte ptr [rdi + rcx - 1], sil
        shr     rax, 4
        dec     rcx
        jnz     .Lph_loop

        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + buf]
        mov     rdx, 16
        syscall
        ret

print:
        mov     rax, 1
        mov     rdi, 1
        syscall
        ret

_start:
        # rol demo
        lea     rsi, [rip + hdr1]
        mov     rdx, hdr1len
        call    print
        mov     rax, 0x8000000000000001
        rol     rax, 1
        call    print_hex64

        # ror demo
        lea     rsi, [rip + hdr2]
        mov     rdx, hdr2len
        call    print
        mov     rax, 0x0000000000000003
        ror     rax, 1
        call    print_hex64

        # popcnt demo (save the answer in r12 for the exit code)
        lea     rsi, [rip + hdr3]
        mov     rdx, hdr3len
        call    print
        mov     rax, 0b10110100
        popcnt  rax, rax
        mov     r12, rax
        call    print_hex64

        # bsf demo
        lea     rsi, [rip + hdr4]
        mov     rdx, hdr4len
        call    print
        mov     rbx, 0b00010000
        bsf     rax, rbx
        call    print_hex64

        # bsr demo
        lea     rsi, [rip + hdr5]
        mov     rdx, hdr5len
        call    print
        mov     rbx, 0b00010000
        bsr     rax, rbx
        call    print_hex64

        # newline
        lea     rsi, [rip + nl]
        mov     rdx, 1
        call    print

        # Exit 0. (The popcount was 4; we discard it to keep verification simple.)
        mov     rax, 60
        xor     rdi, rdi
        syscall
