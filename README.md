# AIDE 0.19.3 for GL.iNet/OpenWrt (AArch64 musl)

This repository documents and automates the source build used to produce a compact
`aide` binary for a GL.iNet BE3600 router.

The binary was compiled and tested in an isolated local QEMU clone before being
copied to the target. No router credentials are stored here.

## Result

| Item | Value |
|---|---|
| AIDE | 0.19.3 |
| Target | AArch64 Cortex-A53, musl |
| Size | 599,720 bytes |
| SHA-256 | `2d8f8f1171cfbec1bfc6ea66a3f7d4732b8f0152d54a00637760b3c750a3cf8d` |
| Runtime dependencies | musl loader/libc and `libgcc_s.so.1` |
| Static libraries | PCRE2 10.42 and Nettle 3.9.1 |

The tested binary was installed as `/usr/bin/aide`.

## Repository contents

- `scripts/build-aide-openwrt.sh` — complete guest-side dependency and AIDE build
- `scripts/prepare-sources.sh` — downloads, verifies, and repacks source archives
  for BusyBox `tar`
- `scripts/install-and-test.sh` — target installation and smoke-test commands
- `config/aide.conf` — overlayfs-safe integrity policy used on the router
- `web/` — local web report
- `serve-report.sh` — serves the report at `http://127.0.0.1:8080`

## Build environment

Target router:

- GL.iNet BE3600 / Qualcomm IPQ5332
- OpenWrt 23.05 snapshot
- Linux 5.4.213
- package architecture `aarch64_cortex-a53_neon-vfpv4`
- musl 1.2.4

Local build guest:

- QEMU AArch64 clone
- OpenWrt 24.10.4
- Linux 6.6.110

The QEMU clone used a small 98.3 MB root filesystem. Toolchain IPKs were therefore
unpacked into `/tmp/toolchain` (tmpfs) instead of being installed into the guest
root filesystem.

## Source archives and checksums

```text
6513170bb5b8c22802dd1b72f02d8aa9f432aef2b4470522db03e755212a3f47  aide-0.19.3.tar.gz
8d36cd8cb6ea2a4c2bb358ff6411b0c788633a2a45dabbf1aeb4b701d1b5e840  pcre2-10.42.tar.bz2
ccfeff981b0ca71bbd6fbcb054f407c60ffb644389a5be80d6716d5b550c6ce3  nettle-3.9.1.tar.gz
06c9e13bdf7eb24d4ceb6b59205a4f67c2c7e7213119644430fe82fbd14a0abb  bison-3.8.2.tar.gz
```

## Reproduce the build

On the host:

```sh
./scripts/prepare-sources.sh ./distfiles
```

Copy `distfiles/` and `scripts/build-aide-openwrt.sh` into the QEMU guest, then run:

```sh
chmod +x /tmp/build-aide-openwrt.sh
/tmp/build-aide-openwrt.sh /tmp/distfiles
```

The stripped result is `/tmp/aide-0.19.3/aide`. Verify it:

```sh
/tmp/aide-0.19.3/aide --version
ldd /tmp/aide-0.19.3/aide
sha256sum /tmp/aide-0.19.3/aide
```

## Why the workarounds are necessary

- The QEMU manager's default host network was `192.168.8.0/24`, while the cloned
  guest used `192.168.1.5`. The working launch values were
  `HOST_NET=192.168.1.0/24`, `QEMU_HOST=192.168.1.2`, and
  `GUEST_IP=192.168.1.5`.
- The UEFI shell required `fs0:` followed by `efi\boot\bootaa64.efi`.
- BusyBox `tar` could not unpack some upstream archive formats, so the host script
  verifies and repacks them as gzip tar archives.
- AIDE's configure stage requires Bison, Flex, pkg-config, and GNU grep.
- The OpenWrt Bison package did not contain its skeleton data. The build uses
  `BISON_PKGDATADIR=/tmp/bison-3.8.2/data`.
- Bison needs GNU M4 explicitly: `M4=/tmp/toolchain/m4`.
- musl provides pthread functions in libc, but the compiler still adds
  `-lpthread`. An empty compatibility archive at
  `/tmp/prefix/lib/libpthread.a` satisfies that link flag.
- AIDE 0.19.3 includes `zlib.h` during compilation even with `--without-zlib`.
  The zlib development headers are supplied, while zlib support remains disabled
  to avoid a runtime dependency.
- Nettle is configured with `--disable-assembler` and mini-gmp.
- PCRE2 and Nettle are statically linked to keep the deployed binary self-contained.

## Compile-time feature selection

Enabled:

- PCRE2 (mandatory)
- pthread (mandatory)
- Nettle

Disabled:

- zlib runtime support
- libgcrypt
- POSIX ACL
- SELinux
- xattrs
- capabilities
- e2fs attributes
- curl
- Linux audit
- locale

## Tests performed

In QEMU:

1. Initialize a database for `/tmp/aide-fixture/sample.txt`.
2. Run an unchanged check and confirm exit code `0`.
3. Modify the file and confirm AIDE reports a difference with exit code `4`.

On the target:

1. Verify the copied SHA-256.
2. Run `aide --version`.
3. Inspect runtime libraries with `ldd`.
4. Initialize the router integrity database.
5. Run a clean check: 9,052 entries, no differences, exit code `0`.

## Router integrity database

The database is a signed-text-style AIDE inventory, not a SQL database. It records
the selected metadata and SHA-256 digest for each matched filesystem object.

Files on the router:

```text
/usr/bin/aide
/etc/aide.conf
/etc/aide/aide.db
```

Check for changes:

```sh
aide --config=/etc/aide.conf --check
echo $?
```

Common exit codes:

- `0`: no differences
- `1`: files added
- `2`: files removed
- `4`: files changed

The values are bit flags and can be combined. Review the report before accepting
changes.

After an intentional system change:

```sh
aide --config=/etc/aide.conf --init
aide --config=/etc/aide.conf --check --database-in=file:/etc/aide/aide.db.new
mv /etc/aide/aide.db.new /etc/aide/aide.db
```

Keep trusted off-router copies of both `/etc/aide/aide.db` and
`/etc/aide.conf`. If an attacker can alter the router and its on-device baseline,
an on-router-only database cannot establish trust. Store the backup read-only and
record its SHA-256 separately.

`/etc/aide` is deliberate: on OpenWrt, `/var` points into volatile `/tmp`, so the
usual `/var/lib/aide` location would not survive a reboot.

## Local report

```sh
./serve-report.sh
```

Open `http://127.0.0.1:8080`.
