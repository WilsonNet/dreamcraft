#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p bin
odin build client -out:bin/dreamcraft -o:speed
exec ./bin/dreamcraft "$@"
