.intel_syntax noprefix

        .section .rodata
fmt:    .asciz  "sscanf returned %d items, doubled = %ld\n"
in_fmt: .asciz  "%ld"
default_input:
        .asciz  "21"

        .section .text
        .globl  align_demo
        .extern printf
        .extern sscanf

# void align_demo(void);
#
# Demonstrates a function that allocates a stack frame, calls sscanf
# (variadic), then calls printf (variadic) -- two libc calls in a row,
# both requiring 16-byte stack alignment at the call site.
#
# Stack layout after the sub:
#   [rsp + 0]  : 8-byte slot for the parsed long  ("slot")
#   [rsp + 8]  : 4 bytes of items count + 4 bytes padding
#
# Entry:        rsp % 16 == 8   (caller's `call` pushed 8 bytes)
# push rbp:     rsp % 16 == 0
# sub rsp, 16:  rsp % 16 == 0   <- aligned for `call`
align_demo:
        push    rbp
        sub     rsp, 16

        # sscanf("21", "%ld", &slot)
        lea     rdi, [rip + default_input]
        lea     rsi, [rip + in_fmt]
        lea     rdx, [rsp]                      # &slot
        xor     eax, eax                        # 0 xmm regs for varargs
        call    sscanf
        mov     dword ptr [rsp + 8], eax        # stash items count on the stack

        # printf(fmt, items, slot * 2)
        lea     rdi, [rip + fmt]
        mov     esi, dword ptr [rsp + 8]        # arg2: items count
        mov     rdx, qword ptr [rsp]            # arg3: slot
        shl     rdx, 1                          # ... * 2
        xor     eax, eax
        call    printf

        add     rsp, 16
        pop     rbp
        ret
