#!/bin/sh
set -eu

OUT=${1:-./distfiles}
mkdir -p "$OUT"

fetch() {
    url=$1
    path=$2
    if command -v curl >/dev/null 2>&1; then
        curl -fL "$url" -o "$path"
    else
        wget -O "$path" "$url"
    fi
}

fetch "https://github.com/aide/aide/releases/download/v0.19.3/aide-0.19.3.tar.gz" "$OUT/aide-0.19.3.tar.gz"
fetch "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.42/pcre2-10.42.tar.bz2" "$OUT/pcre2-10.42.tar.bz2"
fetch "https://ftp.gnu.org/gnu/nettle/nettle-3.9.1.tar.gz" "$OUT/nettle-3.9.1.tar.gz"
fetch "https://ftp.gnu.org/gnu/bison/bison-3.8.2.tar.gz" "$OUT/bison-3.8.2.tar.gz"

(
    cd "$OUT"
    printf '%s  %s\n' \
      6513170bb5b8c22802dd1b72f02d8aa9f432aef2b4470522db03e755212a3f47 aide-0.19.3.tar.gz \
      8d36cd8cb6ea2a4c2bb358ff6411b0c788633a2a45dabbf1aeb4b701d1b5e840 pcre2-10.42.tar.bz2 \
      ccfeff981b0ca71bbd6fbcb054f407c60ffb644389a5be80d6716d5b550c6ce3 nettle-3.9.1.tar.gz \
      06c9e13bdf7eb24d4ceb6b59205a4f67c2c7e7213119644430fe82fbd14a0abb bison-3.8.2.tar.gz |
      shasum -a 256 -c -
)

# Repack formats that the guest's BusyBox tar could not reliably read.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
tar -xjf "$OUT/pcre2-10.42.tar.bz2" -C "$work"
tar -czf "$OUT/pcre2-10.42.busybox.tar.gz" -C "$work" pcre2-10.42
rm -rf "$work/pcre2-10.42"
tar -xzf "$OUT/bison-3.8.2.tar.gz" -C "$work"
tar -czf "$OUT/bison-3.8.2.busybox.tar.gz" -C "$work" bison-3.8.2

echo "Prepared sources in $OUT"
