#!/bin/sh
set -eu

BINARY=${1:?usage: check-release-binary.sh <binary>}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

cat > "$WORK/aide.conf" <<EOF
database_in=file:$WORK/aide.db
database_out=file:$WORK/aide.db.new
database_new=file:$WORK/aide.db.new
Checks = p+n+u+g+s+m+c+sha256
$WORK/fixture Checks
EOF

printf 'known content\n' > "$WORK/fixture"
"$BINARY" --config "$WORK/aide.conf" --init --no-progress --no-color
mv "$WORK/aide.db.new" "$WORK/aide.db"
"$BINARY" --config "$WORK/aide.conf" --check --no-progress --no-color
printf 'changed content\n' > "$WORK/fixture"
set +e
"$BINARY" --config "$WORK/aide.conf" --check --no-progress --no-color
result=$?
set -e
test "$result" -eq 4
echo "AIDE smoke test passed: clean=0 changed=4"
