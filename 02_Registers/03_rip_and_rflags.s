.intel_syntax noprefix

        .section .data
zmsg:   .ascii  "ZF was set: result was zero\n"
        .equ    zlen, . - zmsg
nmsg:   .ascii  "ZF was clear: result was nonzero\n"
        .equ    nlen, . - nmsg

        .section .text
        .globl  _start
_start:
        # Subtracting a number from itself always yields 0,
        # which flips on the Zero Flag (ZF) in rflags.
        mov     rax, 7
        sub     rax, 7                  # rax is now 0, ZF=1

        # `jz` ("jump if zero") looks at ZF and jumps when ZF=1.
        jz      print_zero

        # If we didn't jump, ZF must have been 0 -> different message.
        lea     rsi, [rip + nmsg]
        mov     rdx, nlen
        jmp     do_print

print_zero:
        lea     rsi, [rip + zmsg]
        mov     rdx, zlen

do_print:
        mov     rax, 1                  # write
        mov     rdi, 1                  # stdout
        syscall

        # rip is the instruction pointer cup. We never write to it
        # directly; instead `call`, `jmp`, `jz`, `ret`, and `syscall`
        # change it for us. RIP-relative addressing -- the `[rip + zmsg]`
        # trick above -- is how modern code refers to data by label.
        mov     rax, 60                 # exit
        xor     rdi, rdi                # status 0
        syscall
