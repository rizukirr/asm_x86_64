.intel_syntax noprefix

# The world's smallest x86_64 program.
# Three instructions. No printing, no data — it just returns
# an exit code so you can see it ran. After ./prog, run:
#     echo $?
# and you'll see 42 (the number we chose).

        .section .text
        .globl  _start
_start:
        mov     rax, 60         # syscall number 60 = exit
        mov     rdi, 42         # exit status (the value $? will show)
        syscall
