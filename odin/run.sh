#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p bin
if [ "${1:-}" = "--dev" ]; then
  shift
  odin build client -collection:vinland="${VINLAND_UI:-../../vinland-ui}" -out:bin/dreamcraft-dev -o:speed -define:DREAMCRAFT_DEV=true
  exec ./bin/dreamcraft-dev "$@"
fi
odin build client -collection:vinland="${VINLAND_UI:-../../vinland-ui}" -out:bin/dreamcraft -o:speed
exec ./bin/dreamcraft "$@"
