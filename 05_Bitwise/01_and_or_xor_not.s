.intel_syntax noprefix

# Demonstrates AND (mask), OR (set), XOR (toggle), NOT (flip).
# Builds a result byte step by step and prints a labeled hex line per step.

        .section .data
hdr:    .ascii  "and/or/xor/not demo\n"
        .equ    hdrlen, . - hdr

# Each line we print has the form: "LABEL = 0xHH\n"  (13 bytes total)
# We allocate one line buffer per step in .bss-style writable data.
line_and: .ascii "AND = 0x00\n"
line_or:  .ascii "OR  = 0x00\n"
line_xor: .ascii "XOR = 0x00\n"
line_not: .ascii "NOT = 0x00\n"
        .equ linelen, 11        # length of one line in bytes ("XXX = 0xHH\n")

hexchars: .ascii "0123456789ABCDEF"

        .section .text
        .globl  _start

# byte_to_hex(value_in_al, dest_addr_in_rdi)
# Writes two ASCII hex digits at [rdi] and [rdi+1].
byte_to_hex:
        mov     rsi, rax        # save value
        shr     al, 4           # high nibble
        and     al, 0x0F
        movzx   rax, al
        lea     rdx, [rip + hexchars]
        mov     al, byte ptr [rdx + rax]
        mov     byte ptr [rdi], al
        mov     rax, rsi        # restore value
        and     al, 0x0F        # low nibble
        movzx   rax, al
        lea     rdx, [rip + hexchars]
        mov     al, byte ptr [rdx + rax]
        mov     byte ptr [rdi + 1], al
        ret

_start:
        # Print header.
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + hdr]
        mov     rdx, hdrlen
        syscall

        # AND: 0b11001100 & 0b10101010 = 0b10001000 = 0x88 (mask demo)
        mov     al, 0xCC
        and     al, 0xAA
        movzx   rax, al
        lea     rdi, [rip + line_and + 8]   # position of "HH" in "AND = 0xHH\n"
        call    byte_to_hex

        # OR:  0xF0 | 0x0F = 0xFF (set demo)
        mov     al, 0xF0
        or      al, 0x0F
        movzx   rax, al
        lea     rdi, [rip + line_or + 8]
        call    byte_to_hex

        # XOR: 0xFF ^ 0x0F = 0xF0 (toggle demo)
        mov     al, 0xFF
        xor     al, 0x0F
        movzx   rax, al
        lea     rdi, [rip + line_xor + 8]
        call    byte_to_hex

        # NOT: ~0x00 = 0xFF (flip demo, single operand)
        mov     al, 0x00
        not     al
        movzx   rax, al
        lea     rdi, [rip + line_not + 8]
        call    byte_to_hex

        # Print all four lines as one 44-byte block.
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + line_and]
        mov     rdx, 44
        syscall

        # Exit 0.
        mov     rax, 60
        xor     rdi, rdi
        syscall
