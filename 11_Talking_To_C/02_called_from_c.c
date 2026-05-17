#include <stdio.h>

extern long sum3(long a, long b, long c);

int main(void) {
    long r = sum3(10, 20, 30);
    printf("%ld\n", r);
    return r == 60 ? 0 : 1;
}
