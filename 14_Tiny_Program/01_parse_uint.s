.intel_syntax noprefix

# Topic 01 — parse_uint
#
# Read up to 32 bytes from stdin, turn the digit characters into a
# non-negative 64-bit integer, then print that integer back out as
# decimal followed by '\n'. If stdin is empty, print "0\n" and exit 0.
#
# Build:
#   as -o 01_parse_uint.o 01_parse_uint.s && ld -o 01_parse_uint 01_parse_uint.o
# Run:
#   echo 21 | ./01_parse_uint     # => 21
#   ./01_parse_uint </dev/null    # => 0

        .bss
inbuf:  .skip   32
outbuf: .skip   32

        .text
        .globl  _start

# --------------------------------------------------------------------
# parse_uint(buf in rdi, len in rsi) -> rax
#   Walks bytes left to right. For each ASCII digit, multiplies the
#   running accumulator by 10 and adds the digit's numeric value.
#   Stops at end of buffer or first non-digit (e.g. '\n').
# --------------------------------------------------------------------
parse_uint:
        xor     rax, rax                # acc  = 0
        xor     rcx, rcx                # i    = 0
.pu_loop:
        cmp     rcx, rsi
        jge     .pu_done
        movzx   rdx, byte ptr [rdi + rcx]
        cmp     rdx, '0'
        jl      .pu_done
        cmp     rdx, '9'
        jg      .pu_done
        sub     rdx, '0'                # digit value 0..9
        imul    rax, rax, 10
        add     rax, rdx
        inc     rcx
        jmp     .pu_loop
.pu_done:
        ret

# --------------------------------------------------------------------
# write_uint(value in rdi) -> nothing
#   Bare-bones printer so this file is runnable on its own.
#   See topic 02 for the full explanation.
# --------------------------------------------------------------------
write_uint:
        mov     rax, rdi
        lea     rsi, [rip + outbuf + 32]
        mov     byte ptr [rsi - 1], '\n'
        dec     rsi
        mov     rcx, 10
.wu_div:
        xor     rdx, rdx
        div     rcx
        add     dl, '0'
        dec     rsi
        mov     [rsi], dl
        test    rax, rax
        jnz     .wu_div

        lea     rdx, [rip + outbuf + 32]
        sub     rdx, rsi
        mov     rdi, 1
        mov     rax, 1
        syscall
        ret

# --------------------------------------------------------------------
# _start: read stdin, parse, print
# --------------------------------------------------------------------
_start:
        # n = read(0, inbuf, 32)
        xor     rax, rax
        xor     rdi, rdi
        lea     rsi, [rip + inbuf]
        mov     rdx, 32
        syscall

        # If nothing came in, treat the value as 0 and still print "0\n".
        test    rax, rax
        jg      .have_input
        xor     rax, rax                # value = 0
        jmp     .print

.have_input:
        mov     rsi, rax                # len
        lea     rdi, [rip + inbuf]
        call    parse_uint

.print:
        mov     rdi, rax
        call    write_uint

        # exit(0)
        xor     rdi, rdi
        mov     rax, 60
        syscall
