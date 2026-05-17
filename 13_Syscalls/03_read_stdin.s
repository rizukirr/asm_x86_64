.intel_syntax noprefix

# Read up to 128 bytes from stdin and echo them back to stdout.
# If stdin is empty (read returns 0) or read fails, we print a
# friendly note to stderr and exit cleanly. This means the program
# is safe to run with </dev/null -- it will not hang.

        .section .data
empty:  .ascii  "(no input on stdin)\n"
        .equ    emptylen, . - empty

        .section .bss
buf:    .skip   128

        .section .text
        .globl  _start
_start:
        # n = read(0, buf, 128);
        xor     rax, rax                # 0 = read
        xor     rdi, rdi                # fd 0 = stdin
        lea     rsi, [rip + buf]
        mov     rdx, 128
        syscall

        # if (n <= 0) goto .empty
        test    rax, rax
        jle     .empty

        # write(1, buf, n);
        mov     rdx, rax                # count = bytes read
        mov     rax, 1                  # write
        mov     rdi, 1                  # stdout
        lea     rsi, [rip + buf]
        syscall
        jmp     .done

.empty:
        # write(2, empty, emptylen);
        mov     rax, 1
        mov     rdi, 2
        lea     rsi, [rip + empty]
        mov     rdx, emptylen
        syscall

.done:
        # exit(0)
        mov     rax, 60
        xor     rdi, rdi
        syscall
