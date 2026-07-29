#!/bin/sh
set -eu

ARCH=${1:?usage: check-architecture-examples.sh <aarch64|armv7>}
BUILD=$(mktemp -d)
trap 'rm -rf "$BUILD"' EXIT HUP INT TERM

case "$ARCH" in
  aarch64)
    expected_arch=AArch64
    expected_bits=64
    cflags="-march=armv8-a -mtune=cortex-a53"
    ;;
  armv7)
    expected_arch=ARMv7
    expected_bits=32
    cflags="-march=armv7-a -mtune=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard"
    ;;
  *)
    echo "unsupported architecture: $ARCH" >&2
    exit 2
    ;;
esac

gcc $cflags examples/processor-differences.c -o "$BUILD/c-example"
g++ $cflags examples/processor-differences.cpp -o "$BUILD/cpp-example"
rustc -C opt-level=s examples/processor-differences.rs -o "$BUILD/rust-example"
gcc $cflags \
  examples/processor-word-bits.S examples/processor-word-bits-driver.c \
  -o "$BUILD/assembly-example"

"$BUILD/c-example" | tee "$BUILD/c.out"
"$BUILD/cpp-example" | tee "$BUILD/cpp.out"
"$BUILD/rust-example" | tee "$BUILD/rust.out"
"$BUILD/assembly-example" | tee "$BUILD/assembly.out"

grep -q "arch=$expected_arch" "$BUILD/c.out"
grep -q "pointer_bits=$expected_bits" "$BUILD/c.out"
grep -q "pointer_bits=$expected_bits" "$BUILD/cpp.out"
grep -q "arch=$expected_arch" "$BUILD/rust.out"
grep -q "pointer_bits=$expected_bits" "$BUILD/rust.out"
grep -q "processor_word_bits=$expected_bits" "$BUILD/assembly.out"
echo "Architecture examples passed for $ARCH"
