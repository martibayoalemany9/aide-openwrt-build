#!/bin/sh
set -eu

BINARY=${1:-./aide-0.19.3-aarch64-musl}
EXPECTED=2d8f8f1171cfbec1bfc6ea66a3f7d4732b8f0152d54a00637760b3c750a3cf8d

printf '%s  %s\n' "$EXPECTED" "$BINARY" | sha256sum -c -
cp "$BINARY" /usr/bin/aide
chmod 0755 /usr/bin/aide

aide --version
ldd /usr/bin/aide

mkdir -p /etc/aide
cp ./config/aide.conf /etc/aide.conf
chmod 0644 /etc/aide.conf
aide --config=/etc/aide.conf --init
mv /etc/aide/aide.db.new /etc/aide/aide.db
aide --config=/etc/aide.conf --check
