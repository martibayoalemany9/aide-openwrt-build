#include <stdio.h>

extern int processor_word_bits(void);

int main(void) {
    printf("language=assembly processor_word_bits=%d\n",
           processor_word_bits());
    return 0;
}
