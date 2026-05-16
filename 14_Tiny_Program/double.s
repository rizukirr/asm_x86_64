.intel_syntax noprefix

# A tiny program: read a non-negative integer from stdin, double it,
# print it followed by a newline, exit 0.
#
# No libc; only the Linux syscalls read(0,..), write(1,..), exit.

        .bss
inbuf:  .skip   32              # input buffer
outbuf: .skip   32              # output buffer (we fill from the end)

        .text
        .globl  _start

# --------------------------------------------------------------------
# parse_uint(buf in rdi, len in rsi) -> rax
#   Parses up to `len` decimal digits from buf, stops at the first
#   non-digit (e.g., '\n'). Returns the value in rax.
# --------------------------------------------------------------------
parse_uint:
        xor     rax, rax                # accumulator = 0
        xor     rcx, rcx                # index = 0
.pu_loop:
        cmp     rcx, rsi
        jge     .pu_done
        movzx   rdx, byte ptr [rdi + rcx]
        cmp     rdx, '0'
        jl      .pu_done
        cmp     rdx, '9'
        jg      .pu_done
        sub     rdx, '0'                # digit value
        imul    rax, rax, 10
        add     rax, rdx
        inc     rcx
        jmp     .pu_loop
.pu_done:
        ret

# --------------------------------------------------------------------
# write_uint(value in rdi) -> nothing
#   Writes `value` as decimal ASCII + '\n' to stdout.
#   Fills outbuf from the tail backwards.
# --------------------------------------------------------------------
write_uint:
        mov     rax, rdi
        lea     rsi, [rip + outbuf + 32]        # one past end of buffer
        mov     byte ptr [rsi - 1], '\n'
        dec     rsi                              # rsi -> the '\n'
        mov     rcx, 10
.wu_div:
        xor     rdx, rdx
        div     rcx                              # rax = q, rdx = r
        add     dl, '0'
        dec     rsi
        mov     [rsi], dl
        test    rax, rax
        jnz     .wu_div

        # write(1, rsi, end - rsi)
        lea     rdx, [rip + outbuf + 32]
        sub     rdx, rsi                         # length including '\n'
        mov     rdi, 1                           # stdout
        mov     rax, 1                           # write
        # rsi already points to first digit
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

        # if (n <= 0) exit(1)
        test    rax, rax
        jle     .err

        # value = parse_uint(inbuf, n)
        mov     rsi, rax                         # len
        lea     rdi, [rip + inbuf]
        call    parse_uint

        # write_uint(value * 2)
        shl     rax, 1
        mov     rdi, rax
        call    write_uint

        # exit(0)
        xor     rdi, rdi
        mov     rax, 60
        syscall

.err:
        mov     rdi, 1
        mov     rax, 60
        syscall
