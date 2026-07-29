#if defined(__aarch64__)
    .text
    .global processor_word_bits
    .type processor_word_bits, %function
processor_word_bits:
    mov w0, #64
    ret
#elif defined(__arm__)
    .text
    .syntax unified
    .global processor_word_bits
    .type processor_word_bits, %function
processor_word_bits:
    mov r0, #32
    bx lr
#else
#error "This example expects an ARM target"
#endif
