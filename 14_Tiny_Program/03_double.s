.intel_syntax noprefix

# Topic 03 — Capstone: double
#
# Read a non-negative integer from stdin, double it, print the result
# followed by '\n', exit 0. With no input we just exit 0 silently.
#
# Build:
#   as -o 03_double.o 03_double.s && ld -o 03_double 03_double.o
# Run:
#   echo 21 | ./03_double          # => 42
#   echo 1234567890 | ./03_double  # => 2469135780
#   ./03_double </dev/null         # (no output, exit 0)

        .bss
inbuf:  .skip   32
outbuf: .skip   32

        .text
        .globl  _start

# --------------------------------------------------------------------
# parse_uint(buf in rdi, len in rsi) -> rax
# --------------------------------------------------------------------
parse_uint:
        xor     rax, rax
        xor     rcx, rcx
.pu_loop:
        cmp     rcx, rsi
        jge     .pu_done
        movzx   rdx, byte ptr [rdi + rcx]
        cmp     rdx, '0'
        jl      .pu_done
        cmp     rdx, '9'
        jg      .pu_done
        sub     rdx, '0'
        imul    rax, rax, 10
        add     rax, rdx
        inc     rcx
        jmp     .pu_loop
.pu_done:
        ret

# --------------------------------------------------------------------
# write_uint(value in rdi)
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
# _start
# --------------------------------------------------------------------
_start:
        # n = read(0, inbuf, 32)
        xor     rax, rax
        xor     rdi, rdi
        lea     rsi, [rip + inbuf]
        mov     rdx, 32
        syscall

        # No input at all? Just exit 0 cleanly.
        test    rax, rax
        jle     .done

        # value = parse_uint(inbuf, n)
        mov     rsi, rax
        lea     rdi, [rip + inbuf]
        call    parse_uint

        # write_uint(value * 2)
        shl     rax, 1
        mov     rdi, rax
        call    write_uint

.done:
        xor     rdi, rdi
        mov     rax, 60
        syscall
