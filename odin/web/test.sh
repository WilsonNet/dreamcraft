#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

./build.sh
if ! command -v node >/dev/null 2>&1; then
  echo "node not found; skipping web wasm smoke test" >&2
  exit 0
fi
node test_wasm.mjs
