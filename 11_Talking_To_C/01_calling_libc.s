.intel_syntax noprefix

        .section .rodata
fmt:    .asciz  "Hello from asm, x = %d\n"

        .section .text
        .globl  asm_main
        .extern printf

# void asm_main(void);
# Called by a tiny C `main` that exists only so gcc can link this for us.
asm_main:
        push    rbp                     # save caller's rbp; also realigns rsp to 16
        lea     rdi, [rip + fmt]        # arg 1: format string
        mov     rsi, 42                 # arg 2: x
        xor     eax, eax                # 0 vector regs used for varargs
        call    printf
        pop     rbp
        ret
