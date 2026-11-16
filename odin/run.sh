#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p bin
if [ "${1:-}" = "--dev" ]; then
  shift
  odin build client -out:bin/dreamcraft-dev -o:speed
  exec ./bin/dreamcraft-dev "$@"
fi
odin build client -out:bin/dreamcraft -o:speed
exec ./bin/dreamcraft "$@"
