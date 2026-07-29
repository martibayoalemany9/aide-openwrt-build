#include <cstdint>
#include <iostream>

int main() {
#if defined(__aarch64__)
    constexpr const char *architecture = "AArch64";
#elif defined(__arm__) && defined(__ARM_PCS_VFP)
    constexpr const char *architecture = "ARMv7-hard-float";
#else
#error "This example expects AArch64 or ARMv7 hard-float"
#endif

    std::cout << "language=C++ arch=" << architecture
              << " pointer_bits=" << sizeof(void *) * 8
              << " uint64_alignment=" << alignof(std::uint64_t) << '\n';
}
