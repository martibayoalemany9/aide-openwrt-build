#include <stdint.h>
#include <stdio.h>

int main(void) {
#if defined(__aarch64__)
    const char *architecture = "AArch64";
#elif defined(__arm__)
    const char *architecture = "ARMv7";
#else
#error "This example expects an ARM target"
#endif

    printf("language=C arch=%s pointer_bits=%zu uintptr_bits=%zu\n",
           architecture, sizeof(void *) * 8, sizeof(uintptr_t) * 8);
    return 0;
}
