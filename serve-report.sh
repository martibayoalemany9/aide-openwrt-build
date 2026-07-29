#!/bin/sh
set -eu
cd "$(dirname "$0")/web"
echo "AIDE build report: http://127.0.0.1:8080"
python3 -m http.server 8080 --bind 127.0.0.1
