#!/bin/sh
set -eu

DISTFILES=${1:-/tmp/distfiles}
TOOLCHAIN=/tmp/toolchain
PREFIX=/tmp/prefix
FEED=https://fw.gl-inet.com/releases/qsdk_v12.5/packages-4.x/ipq53xx/be9300/packages

mkdir -p "$TOOLCHAIN" "$PREFIX" /tmp/ipks

fetch() {
    url=$1
    dest=$2
    wget -O "$dest" "$url"
}

unpack_ipk() {
    ipk=$1
    dest=$2
    stage=$(mktemp -d)
    (cd "$stage" && ar x "$ipk" && tar -xzf data.tar.gz -C "$dest")
    rm -rf "$stage"
}

# Versions are pinned to the packages used in the successful build.
for spec in \
  gcc_12.3.0-5_aarch64_cortex-a53_neon-vfpv4.ipk \
  make_4.3-1_aarch64_cortex-a53_neon-vfpv4.ipk \
  zlib-dev_1.2.13-1_aarch64_cortex-a53_neon-vfpv4.ipk \
  grep_3.8-2_aarch64_cortex-a53_neon-vfpv4.ipk \
  libpcre2_10.42-1_aarch64_cortex-a53_neon-vfpv4.ipk \
  bison_3.8.2-1_aarch64_cortex-a53_neon-vfpv4.ipk \
  flex_2.6.4-4_aarch64_cortex-a53_neon-vfpv4.ipk \
  m4_1.4.19-1_aarch64_cortex-a53_neon-vfpv4.ipk \
  pkgconf_1.8.0-2_aarch64_cortex-a53_neon-vfpv4.ipk \
  libpkgconf_1.8.0-2_aarch64_cortex-a53_neon-vfpv4.ipk
do
    fetch "$FEED/$spec" "/tmp/ipks/$spec"
    case "$spec" in gcc_*) dest="$TOOLCHAIN/x-gcc" ;; *) dest="$TOOLCHAIN" ;; esac
    mkdir -p "$dest"
    unpack_ipk "/tmp/ipks/$spec" "$dest"
done

fetch \
  "https://downloads.openwrt.org/releases/23.05.5/targets/ipq807x/generic/packages/libstdcpp6_12.3.0-4_aarch64_cortex-a53.ipk" \
  /tmp/ipks/libstdcpp6.ipk
unpack_ipk /tmp/ipks/libstdcpp6.ipk "$TOOLCHAIN"

export PATH="$TOOLCHAIN/usr/bin:$TOOLCHAIN/bin:$PATH"
export LD_LIBRARY_PATH="$TOOLCHAIN/usr/lib"
CC="$TOOLCHAIN/x-gcc/usr/bin/aarch64-openwrt-linux-musl-gcc"
MAKE="$TOOLCHAIN/make"
M4="$TOOLCHAIN/m4"

cd /tmp
tar -xzf "$DISTFILES/pcre2-10.42.busybox.tar.gz"
tar -xzf "$DISTFILES/nettle-3.9.1.tar.gz"
tar -xzf "$DISTFILES/bison-3.8.2.busybox.tar.gz"
tar -xzf "$DISTFILES/aide-0.19.3.tar.gz"

cd /tmp/pcre2-10.42
GREP="$TOOLCHAIN/usr/bin/grep" CC="$CC" ./configure \
  --prefix="$PREFIX" --disable-shared --enable-static \
  --disable-pcre2-16 --disable-pcre2-32 \
  --disable-pcre2grep-libz --disable-pcre2grep-libbz2
"$MAKE" -j2
"$MAKE" install

cd /tmp/nettle-3.9.1
CC="$CC" ./configure \
  --prefix="$PREFIX" --disable-shared --enable-static \
  --disable-assembler --disable-openssl --disable-documentation --enable-mini-gmp
"$MAKE" -j2
"$MAKE" install

# musl keeps pthread symbols in libc; satisfy GCC's compatibility -lpthread flag.
mkdir -p "$PREFIX/lib"
/usr/bin/ar rcs "$PREFIX/lib/libpthread.a"

ZLIB_INCLUDE=$(find "$TOOLCHAIN" -type f -name zlib.h -exec dirname {} \; | head -n 1)

cd /tmp/aide-0.19.3
export CC CFLAGS="-Os -ffunction-sections -fdata-sections"
export CPPFLAGS="-I$ZLIB_INCLUDE"
export LDFLAGS="-L$PREFIX/lib -Wl,--gc-sections"
export PCRE2_CFLAGS="-I$PREFIX/include"
export PCRE2_LIBS="$PREFIX/lib/libpcre2-8.a"
export NETTLE_CFLAGS="-I$PREFIX/include"
export NETTLE_LIBS="$PREFIX/lib/libnettle.a"
export BISON="$TOOLCHAIN/usr/bin/bison"
export BISON_PKGDATADIR=/tmp/bison-3.8.2/data
export FLEX="$TOOLCHAIN/usr/bin/flex"
export M4

./configure \
  --prefix=/usr --sysconfdir=/etc --localstatedir=/var \
  --without-zlib --without-gcrypt
"$MAKE" -j2
/usr/bin/strip -s ./aide

./aide --version
ldd ./aide
sha256sum ./aide
