.intel_syntax noprefix

        .section .rodata
greeting:
        .asciz  "Hello via PLT"

        .section .text
        .globl  say_hello
        .extern puts

# void say_hello(void);
# Calls puts("Hello via PLT").
# On a PIE build, the linker rewrites `call puts` as `call puts@PLT`.
# On a -no-pie build, the linker turns it into a direct call.
# Source is the same either way.
say_hello:
        push    rbp                     # 16-align rsp for the call
        lea     rdi, [rip + greeting]   # RIP-relative is PIE-friendly
        call    puts                    # linker decides PLT vs. direct
        pop     rbp
        ret
