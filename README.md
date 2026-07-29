# AIDE 0.19.3 for GL.iNet/OpenWrt (AArch64 and ARMv7 musl)

This repository documents and automates two compact `aide` binaries:

- AArch64 Cortex-A53 for the NordNet Fiber router
- ARMv7 Cortex-A7 EABI5 hard-float for the Movistar E554 VPN router

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

| Target | Size | SHA-256 | Baseline |
|---|---:|---|---:|
| AArch64 Cortex-A53 | 599,720 bytes | `2d8f8f1171cfbec1bfc6ea66a3f7d4732b8f0152d54a00637760b3c750a3cf8d` | 9,000 entries |
| ARMv7 Cortex-A7 hard-float | 522,084 bytes | `6bd027ff8fc4d21cec7993af9cab4eab2c31055164dd3efd5b716802a4ffc8e9` | 4,850 entries |

These binaries are architecture-specific and are not interchangeable.

The tested binary was installed as `/usr/bin/aide`.

## Repository contents

- `scripts/build-aide-openwrt.sh` — complete guest-side dependency and AIDE build
- `scripts/prepare-sources.sh` — downloads, verifies, and repacks source archives
  for BusyBox `tar`
- `scripts/install-and-test.sh` — target installation and smoke-test commands
- `scripts/build-release-binary.sh` — container-native AArch64/ARMv7 release build
- `scripts/check-release-binary.sh` — clean/changed runtime integrity test
- `scripts/check-architecture-examples.sh` — runs C, C++, Rust, and assembly target checks
- `docs/architecture-behavior.md` — processor-dependent code and expected output
- `examples/` — runnable AArch64/ARMv7 source examples
- `.github/workflows/daily-build-release.yml` — guarded daily builds and releases
- `config/aide.conf` — overlayfs-safe integrity policy used on the router
- `web/` — local web report
- `security-report/` — Nmap exposure, vulnerability triage, GitHub scan, and raw evidence
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

## Repository and workspace map

| Name | Location | Purpose |
|---|---|---|
| Published project | `martibayoalemany9/aide-openwrt-build` | Reproduction scripts, configuration, and report |
| AIDE upstream | `aide/aide` | AIDE 0.19.3 source release |
| PCRE2 upstream | `PCRE2Project/pcre2` | Mandatory regular-expression dependency |
| Nettle upstream | `https://ftp.gnu.org/gnu/nettle/` | Cryptographic hash implementation |
| Bison upstream | `https://ftp.gnu.org/gnu/bison/` | Parser generator and missing skeleton data |
| Local QEMU workspace | `/Users/username/openwrt-qemu-aarch64-overlay` | Router clone, boot tooling, and build output |
| Local documentation checkout | `/Users/username/Desktop/aide-openwrt-build` | Git checkout published by this repository |

The target router address and all credentials are intentionally absent from the
repository.

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
5. Run a clean check: 9,000 entries, no differences, exit code `0`.

The Movistar ARMv7 deployment was also initialized with 4,850 entries. Its
controlled added-file test returned exit code `5`; after removing the fixture and
refreshing the baseline, the live check returned `0`.

## Daily GitHub release

GitHub Actions checks once per UTC day whether the date-keyed AIDE release already
exists. Only when it does not exist does it:

1. emulate the AArch64 and ARMv7 platforms;
2. verify pinned upstream source checksums;
3. compile PCRE2, Nettle, and AIDE;
4. reject ELF binaries containing `TEXTREL`;
5. test a clean database check (`0`) and changed-file detection (`4`);
6. publish both stripped binaries and their SHA-256 files.

The release tag is `aide-0.19.3-YYYYMMDD`. The daily gate plus workflow
concurrency prevents more than one build-and-release set per UTC day, including
manual dispatches.

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

### Active router configuration

```text
database_in=file:/etc/aide/aide.db
database_out=file:/etc/aide/aide.db.new
database_new=file:/etc/aide/aide.db.new
log_level=notice
Checks = p+n+u+g+s+m+c+sha256
!/etc/aide(/.*)?$
!/etc/AdGuardHome/data(/.*)?$
!/etc/netifyd(/.*)?$
!/etc/oui-tertf(/.*)?$
!/tmp
!/var/run
!/run
!/proc
!/sys
!/dev
/bin Checks
/sbin Checks
/etc Checks
/lib Checks
/usr Checks
/www Checks
/root Checks
```

The three GL.iNet service-data exclusions prevent expected hourly writes from
AdGuard Home, Netify, and the client statistics service from obscuring meaningful
integrity alerts. The `$`-anchored AIDE exclusion avoids accidentally excluding
similarly named paths.

### Attribute rule

`Checks = p+n+u+g+s+m+c+sha256` records:

| Letter | Meaning |
|---|---|
| `p` | permissions and file mode |
| `n` | hard-link count |
| `u` | owner user ID |
| `g` | owner group ID |
| `s` | file size |
| `m` | modification time |
| `c` | inode/status change time |
| `sha256` | SHA-256 content digest |

Inode number (`i`) is deliberately omitted because overlayfs directory inode
numbers changed between otherwise identical scans and caused 196 false positives.

### AIDE commands and options available on the router

| Command/option | Purpose |
|---|---|
| `--init`, `-i` | create a new database |
| `--dry-init`, `-n` | traverse paths and show rule matching without writing a database |
| `--check`, `-C` | compare the filesystem with the baseline |
| `--update`, `-u` | check and write an updated database |
| `--compare`, `-E` | compare two databases |
| `--list` | list database entries in human-readable form |
| `--config-check`, `-D` | validate the configuration |
| `--path-check=TYPE:PATH`, `-p` | show how one path matches the rule tree |
| `--config=FILE`, `-c` | select the configuration file |
| `--limit=REGEX`, `-l` | restrict a command to matching paths |
| `--workers=N`, `-W` | select hash-processing worker threads |
| `--no-progress` | suppress the progress display |
| `--no-color` | suppress ANSI color output |
| `--version`, `-v` | show version and compiled features |

### Verified added-file demonstration

The live test created a harmless file under the monitored `/etc` tree:

```sh
printf '%s\n' 'AIDE live integrity test 2026-07-29' > /etc/integrity-demo.txt
sha256sum /etc/integrity-demo.txt
aide --config=/etc/aide.conf --check --no-progress --no-color
```

Observed result:

```text
Summary:
  Total number of entries: 9001
  Added entries:           1
  Removed entries:         0
  Changed entries:         1

Added entries:
f+++++++++++++: /etc/integrity-demo.txt

AIDE_CHECK_EXIT=5
```

Exit `5` is the bitwise combination of `1` (an added file) and `4` (the `/etc`
directory metadata changed when the file was created). The test file was then
removed and a clean check was run to restore the router to its baseline state.

## Local report

```sh
./serve-report.sh
```

Open `http://127.0.0.1:8080`.
