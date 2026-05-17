.intel_syntax noprefix

        .section .data
msg:    .ascii  "double(21) = 42\n"
        .equ    msglen, . - msg

        .section .text
        .globl  _start

# A tiny "specialist": doubles whatever number you give it in rdi.
# Returns the answer in rax. No stack tricks — pure leaf.
double:
        mov     rax, rdi        # copy input into rax
        add     rax, rax        # rax = rax + rax  (i.e. 2 * input)
        ret                     # pop the return address, jump back

_start:
        # Print a banner so you can SEE the program ran.
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + msg]
        mov     rdx, msglen
        syscall

        # Make the phone call: double(21).
        mov     rdi, 21         # 1st arg goes in rdi (we'll meet this rule next chapter)
        call    double          # pushes return address, jumps to `double`
                                # `double` runs, leaves 42 in rax, ret jumps back here.

        # Move the answer into the exit-status slot and exit.
        mov     rdi, rax        # rdi = 42
        mov     rax, 60         # syscall: exit
        syscall
