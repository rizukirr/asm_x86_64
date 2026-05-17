/* Thin C driver: gcc needs a `main`, and the asm side wants to focus on
 * the libc call itself. This file just hands control to the asm. */

extern void asm_main(void);

int main(void) {
    asm_main();
    return 0;
}
