#!/bin/sh
set -eu

ARCH=${1:?usage: build-release-binary.sh <aarch64|armv7>}
ROOT=/tmp/aide-release-build
PREFIX=$ROOT/prefix
OUT=/work/dist

case "$ARCH" in
  aarch64)
    CFLAGS="-Os -march=armv8-a -mtune=cortex-a53 -ffunction-sections -fdata-sections -fno-pie"
    OUTPUT=aide-0.19.3-aarch64-cortex-a53-musl
    ;;
  armv7)
    CFLAGS="-Os -march=armv7-a -mtune=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard -ffunction-sections -fdata-sections -fno-pie"
    OUTPUT=aide-0.19.3-armv7-cortex-a7-hardfloat-musl
    ;;
  *)
    echo "unsupported architecture: $ARCH" >&2
    exit 2
    ;;
esac

apk add --no-cache build-base bison flex m4 curl file gettext-dev linux-headers perl pkgconf rust
mkdir -p "$ROOT" "$PREFIX" "$OUT"
cd "$ROOT"

fetch_verify() {
  url=$1
  file=$2
  checksum=$3
  curl -fL --retry 3 "$url" -o "$file"
  printf '%s  %s\n' "$checksum" "$file" | sha256sum -c -
}

fetch_verify \
  https://github.com/aide/aide/releases/download/v0.19.3/aide-0.19.3.tar.gz \
  aide-0.19.3.tar.gz \
  6513170bb5b8c22802dd1b72f02d8aa9f432aef2b4470522db03e755212a3f47
fetch_verify \
  https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.42/pcre2-10.42.tar.bz2 \
  pcre2-10.42.tar.bz2 \
  8d36cd8cb6ea2a4c2bb358ff6411b0c788633a2a45dabbf1aeb4b701d1b5e840
fetch_verify \
  https://ftp.gnu.org/gnu/nettle/nettle-3.9.1.tar.gz \
  nettle-3.9.1.tar.gz \
  ccfeff981b0ca71bbd6fbcb054f407c60ffb644389a5be80d6716d5b550c6ce3

tar -xzf aide-0.19.3.tar.gz
tar -xjf pcre2-10.42.tar.bz2
tar -xzf nettle-3.9.1.tar.gz

cd "$ROOT/pcre2-10.42"
CC=gcc CFLAGS="$CFLAGS" ./configure \
  --prefix="$PREFIX" --disable-shared --enable-static \
  --disable-pcre2-16 --disable-pcre2-32 \
  --disable-pcre2grep-libz --disable-pcre2grep-libbz2
make -j2
make install

cd "$ROOT/nettle-3.9.1"
CC=gcc CFLAGS="$CFLAGS" ./configure \
  --prefix="$PREFIX" --disable-shared --enable-static \
  --disable-assembler --disable-openssl --disable-documentation --enable-mini-gmp
make -j2
make install

# AIDE enables PIE automatically. Static non-PIC libraries caused ARMv7 TEXTREL
# startup failures under musl, so release builds use a normal ET_EXEC binary.
cd "$ROOT/aide-0.19.3"
sed -i 's/if cc_supports_flag -fPIE -DPIE; then/if false; then/' configure
export CC=gcc
export CFLAGS
export CPPFLAGS="-I$PREFIX/include"
export LDFLAGS="-L$PREFIX/lib -Wl,--gc-sections -no-pie"
export PCRE2_CFLAGS="-I$PREFIX/include"
export PCRE2_LIBS="$PREFIX/lib/libpcre2-8.a"
export NETTLE_CFLAGS="-I$PREFIX/include"
export NETTLE_LIBS="$PREFIX/lib/libnettle.a"
./configure \
  --prefix=/usr --sysconfdir=/etc --localstatedir=/var \
  --without-zlib --without-gcrypt
make -j2
strip -s aide
cp aide "$OUT/$OUTPUT"
chmod 0755 "$OUT/$OUTPUT"

"$OUT/$OUTPUT" --version
file "$OUT/$OUTPUT"
if readelf -d "$OUT/$OUTPUT" | grep -q TEXTREL; then
  echo "unsafe TEXTREL found" >&2
  exit 1
fi
sha256sum "$OUT/$OUTPUT" > "$OUT/$OUTPUT.sha256"
