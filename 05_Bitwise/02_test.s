.intel_syntax noprefix

# Demonstrates `test` — bitwise AND that throws the result away
# and just sets flags. We probe two bits in a byte and print
# whether each one is ON or OFF.

        .section .data
value:  .byte   0b10100101              # bits 0, 2, 5, 7 are ON
msg_b0_on:  .ascii "bit 0: ON\n"
msg_b0_off: .ascii "bit 0: OFF\n"
msg_b3_on:  .ascii "bit 3: ON\n"
msg_b3_off: .ascii "bit 3: OFF\n"
msg_zero:   .ascii "value & 0 -> ZF=1 (any number AND zero is zero)\n"


        .equ b0_on_len,  10
        .equ b0_off_len, 11
        .equ b3_on_len,  10
        .equ b3_off_len, 11
        .equ zero_len,   48

        .section .text
        .globl  _start

# print(rsi=addr, rdx=len)
print:
        mov     rax, 1
        mov     rdi, 1
        syscall
        ret

_start:
        # Check bit 0 (mask 0x01).
        mov     al, byte ptr [rip + value]
        test    al, 0x01                # ZF=1 iff bit 0 is OFF
        jz      .Lb0_off
        lea     rsi, [rip + msg_b0_on]
        mov     rdx, b0_on_len
        call    print
        jmp     .Lb3
.Lb0_off:
        lea     rsi, [rip + msg_b0_off]
        mov     rdx, b0_off_len
        call    print

.Lb3:
        # Check bit 3 (mask 0x08). value = 0b10100101, so bit 3 is OFF.
        mov     al, byte ptr [rip + value]
        test    al, 0x08
        jz      .Lb3_off
        lea     rsi, [rip + msg_b3_on]
        mov     rdx, b3_on_len
        call    print
        jmp     .Lzero
.Lb3_off:
        lea     rsi, [rip + msg_b3_off]
        mov     rdx, b3_off_len
        call    print

.Lzero:
        # Classic flag-light demo: test rax, 0 always sets ZF.
        mov     rax, 0xDEADBEEF
        test    rax, 0                  # ZF=1 (result is 0), rax unchanged
        jnz     .Lend                   # not taken
        lea     rsi, [rip + msg_zero]
        mov     rdx, zero_len
        call    print

.Lend:
        mov     rax, 60
        xor     rdi, rdi
        syscall
