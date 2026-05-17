.intel_syntax noprefix

        .section .data
bytebuf:
        .byte   0                       # 1 reserved byte
wordbuf:
        .word   0                       # 2 reserved bytes
dwordbuf:
        .long   0                       # 4 reserved bytes
qwordbuf:
        .quad   0                       # 8 reserved bytes

        .section .text
        .globl  _start
_start:
        # Write different widths to memory.  The PTR keyword tells the
        # assembler how many bytes to touch when the size isn't obvious.
        mov     BYTE PTR  [rip + bytebuf],  0x7F
        mov     WORD PTR  [rip + wordbuf],  0x1234
        mov     DWORD PTR [rip + dwordbuf], 0xDEADBEEF
        mov     QWORD PTR [rip + qwordbuf], 0x11

        # Load them back into different-width register views.
        movzx   eax, BYTE PTR  [rip + bytebuf]   # eax = 0x7F
        movzx   ecx, WORD PTR  [rip + wordbuf]   # ecx = 0x1234
        mov     edx,           [rip + dwordbuf]  # edx = 0xDEADBEEF (size from reg)
        mov     rsi, QWORD PTR [rip + qwordbuf]  # rsi = 0x11

        # Exit with rsi (0x11 = 17) so we can verify via $?.
        mov     rdi, rsi
        mov     rax, 60
        syscall
