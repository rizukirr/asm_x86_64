.intel_syntax noprefix

        .section .text
        .globl  _start
_start:
        # Demonstrate the syscall ABI by calling getpid (syscall 39).
        # getpid takes no arguments and returns the process id in rax.
        mov     rax, 39                 # syscall number: getpid
        syscall
        # rax now holds our PID. We won't print it -- just exit cleanly.

        # exit(0): syscall number 60, status in rdi.
        mov     rax, 60
        xor     rdi, rdi
        syscall
