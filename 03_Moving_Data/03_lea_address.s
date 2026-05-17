.intel_syntax noprefix

        .section .data
greet:  .ascii  "lea: I know where things live!\n"
        .equ    greetlen, . - greet

        .section .text
        .globl  _start
_start:
        # --- Use 1: get the address of a label (no fetch) ---
        lea     rsi, [rip + greet]          # rsi <- address of greet
        mov     rax, 1                      # write
        mov     rdi, 1                      # stdout
        mov     rdx, greetlen
        syscall

        # --- Use 2: lea as a fast calculator ---
        # Compute rax = rbx + rcx*4 + 8, without touching memory.
        mov     rbx, 100
        mov     rcx, 5
        lea     rax, [rbx + rcx*4 + 8]      # rax = 100 + 20 + 8 = 128

        # --- Use 3: cheap "multiply by 3" trick ---
        # lea rdx, [rcx + rcx*2] computes rcx*3 in one instruction.
        lea     rdx, [rcx + rcx*2]          # rdx = 5 + 10 = 15

        # Exit cleanly. Use gdb to confirm rax = 128 and rdx = 15
        # right before the exit syscall (set a breakpoint there).
        mov     rax, 60
        xor     rdi, rdi
        syscall
