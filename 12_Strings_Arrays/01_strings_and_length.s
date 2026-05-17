.intel_syntax noprefix

        .section .data
greet:  .ascii  "Hello, strings!\n"
        .equ    greetlen, . - greet

name:   .asciz  "Ada"                   # NUL-terminated: 'A','d','a',0

prefix: .ascii  "length of \"Ada\" is "
        .equ    prefixlen, . - prefix

        .section .bss
digit:  .skip   2                       # one ASCII digit + newline

        .section .text
        .globl  _start

# --- print the fixed greeting --------------------------------------------
_start:
        mov     rax, 1                  # write
        mov     rdi, 1                  # stdout
        lea     rsi, [rip + greet]
        mov     rdx, greetlen
        syscall

# --- compute strlen("Ada") by scanning until the NUL --------------------
        lea     rsi, [rip + name]       # rsi walks the string
        xor     rcx, rcx                # rcx = count
.scan:
        mov     al, [rsi + rcx]         # peek byte at offset rcx
        test    al, al                  # is it the NUL?
        jz      .done                   # yes -> stop
        inc     rcx                     # no  -> count it and continue
        jmp     .scan
.done:
        # rcx now holds the length (3 for "Ada").
        # Turn it into one ASCII digit by adding '0' (0x30).
        add     rcx, '0'
        mov     [rip + digit], cl
        mov     byte ptr [rip + digit + 1], '\n'

# --- print the prefix ----------------------------------------------------
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + prefix]
        mov     rdx, prefixlen
        syscall

# --- print the digit + newline ------------------------------------------
        mov     rax, 1
        mov     rdi, 1
        lea     rsi, [rip + digit]
        mov     rdx, 2
        syscall

# --- exit cleanly --------------------------------------------------------
        mov     rax, 60
        xor     rdi, rdi
        syscall
