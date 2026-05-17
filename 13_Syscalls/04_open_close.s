.intel_syntax noprefix

# Open /etc/hostname, read up to 256 bytes, write them to stdout,
# close the file, then exit. Demonstrates open (2), read (0),
# write (1), close (3).
#
# If open fails (returns negative), we skip the read/write and
# exit with status 1 -- but since /etc/hostname exists on every
# Linux box, that branch usually does not trigger.

        .equ    SYS_read,  0
        .equ    SYS_write, 1
        .equ    SYS_open,  2
        .equ    SYS_close, 3
        .equ    SYS_exit,  60

        .equ    O_RDONLY,  0

        .section .rodata
path:   .asciz  "/etc/hostname"         # NUL-terminated, as open() expects

        .section .bss
buf:    .skip   256

        .section .text
        .globl  _start
_start:
        # fd = open("/etc/hostname", O_RDONLY, 0);
        mov     rax, SYS_open
        lea     rdi, [rip + path]       # arg1: path
        mov     rsi, O_RDONLY           # arg2: flags
        xor     rdx, rdx                # arg3: mode (ignored without O_CREAT)
        syscall

        test    rax, rax
        js      .err                    # negative -> error

        mov     r12, rax                # save fd in callee-saved register

        # n = read(fd, buf, 256);
        mov     rax, SYS_read
        mov     rdi, r12                # fd
        lea     rsi, [rip + buf]
        mov     rdx, 256
        syscall

        test    rax, rax
        jle     .close                  # nothing to print

        # write(1, buf, n);
        mov     rdx, rax                # count = bytes read
        mov     rax, SYS_write
        mov     rdi, 1                  # stdout
        lea     rsi, [rip + buf]
        syscall

.close:
        # close(fd);
        mov     rax, SYS_close
        mov     rdi, r12
        syscall

        # exit(0)
        mov     rax, SYS_exit
        xor     rdi, rdi
        syscall

.err:
        # exit(1)
        mov     rax, SYS_exit
        mov     rdi, 1
        syscall
