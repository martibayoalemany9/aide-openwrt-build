# Processor-dependent code: AArch64 versus ARMv7

The repository builds for two processor contracts:

| Property | AArch64 Cortex-A53 | ARMv7 Cortex-A7 hard-float |
|---|---|---|
| ISA | ARMv8-A, 64-bit | ARMv7-A, 32-bit |
| C/C++ predefined macro | `__aarch64__` | `__arm__` and `__ARM_PCS_VFP` |
| Rust target architecture | `aarch64` | `arm` |
| Pointer/`usize` width | 64 bits | 32 bits |
| Integer return register | `w0`/`x0` | `r0` |
| Function return instruction | `ret` | `bx lr` |
| Floating-point ABI | AArch64 ABI | EABI5 hard-float, VFP registers |

These are target/ABI differences, not benchmark claims. Cortex-A53 and Cortex-A7
performance also depends on clock, cache, memory, kernel, and workload.

## C

[`examples/processor-differences.c`](../examples/processor-differences.c) selects
the architecture using compiler-defined macros and prints pointer width.

Expected output:

```text
language=C arch=AArch64 pointer_bits=64 uintptr_bits=64
language=C arch=ARMv7 pointer_bits=32 uintptr_bits=32
```

## C++

[`examples/processor-differences.cpp`](../examples/processor-differences.cpp)
also checks `__ARM_PCS_VFP`, which identifies the ARMv7 hard-float procedure-call
standard used by the Movistar build.

```text
language=C++ arch=AArch64 pointer_bits=64 uint64_alignment=8
language=C++ arch=ARMv7-hard-float pointer_bits=32 uint64_alignment=8
```

## Rust

[`examples/processor-differences.rs`](../examples/processor-differences.rs) uses
Rust `cfg(target_arch)` and `usize::BITS`. `usize::MAX` is consequently
`18446744073709551615` on AArch64 and `4294967295` on ARMv7.

```text
language=Rust arch=AArch64 pointer_bits=64 usize_max=18446744073709551615
language=Rust arch=ARMv7 pointer_bits=32 usize_max=4294967295
```

## ARM assembly

[`examples/processor-word-bits.S`](../examples/processor-word-bits.S) is
preprocessed assembly. The AArch64 branch returns `64` through `w0` and uses
`ret`; the ARMv7 branch returns `32` through `r0` and uses `bx lr`.

```asm
/* AArch64 */
mov w0, #64
ret

/* ARMv7 */
mov r0, #32
bx lr
```

The C driver is
[`examples/processor-word-bits-driver.c`](../examples/processor-word-bits-driver.c).

## Automated check

The daily GitHub Actions matrix runs
[`scripts/check-architecture-examples.sh`](../scripts/check-architecture-examples.sh)
inside the matching emulated architecture. It compiles all four examples,
executes them, and asserts the architecture and word-size output before a release
can be created.
