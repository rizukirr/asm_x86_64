.intel_syntax noprefix

# Topic 02 — write_uint
#
# Show that we can take a 64-bit number sitting in a register and print
# its decimal characters to stdout without any libc help. This program
# hard-codes the value 12345 and prints "12345\n", then exits 0.
#
# Build:
#   as -o 02_write_uint.o 02_write_uint.s && ld -o 02_write_uint 02_write_uint.o
# Run:
#   ./02_write_uint   # => 12345

        .bss
outbuf: .skip   32

        .text
        .globl  _start

# --------------------------------------------------------------------
# write_uint(value in rdi) -> nothing
#   Repeatedly divides by 10. The remainder each iteration is the next
#   digit, starting from the rightmost. We fill outbuf from the RIGHT
#   so that when we're done, the digits are in correct left-to-right
#   order in memory. Then one write() prints them.
# --------------------------------------------------------------------
write_uint:
        mov     rax, rdi
        lea     rsi, [rip + outbuf + 32]        # one past end of buffer
        mov     byte ptr [rsi - 1], '\n'        # park the newline first
        dec     rsi                              # rsi -> '\n'
        mov     rcx, 10                          # divisor
.wu_div:
        xor     rdx, rdx                         # clear rdx before div
        div     rcx                              # rax=q, rdx=r (0..9)
        add     dl, '0'                          # digit -> ASCII char
        dec     rsi                              # walk pointer leftward
        mov     [rsi], dl                        # store the char
        test    rax, rax
        jnz     .wu_div                          # more digits? keep going

        # write(1, rsi, end - rsi)
        lea     rdx, [rip + outbuf + 32]
        sub     rdx, rsi                         # length including '\n'
        mov     rdi, 1                           # stdout
        mov     rax, 1                           # write
        syscall
        ret

# --------------------------------------------------------------------
# _start: print a fixed number
# --------------------------------------------------------------------
_start:
        mov     rdi, 12345
        call    write_uint

        xor     rdi, rdi
        mov     rax, 60
        syscall
