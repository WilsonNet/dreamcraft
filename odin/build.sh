#!/usr/bin/env bash
# Two-lane build:
#   ./build.sh        stable build the user plays (bin/dreamcraft, bin/headless, web)
#   ./build.sh --dev  agent-only development build (bin/dreamcraft-dev, bin/headless-dev)
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p bin

MODE="${1:-stable}"
case "$MODE" in
  --dev|dev)
    odin build client -out:bin/dreamcraft-dev -o:speed -vet -strict-style
    odin build headless -out:bin/headless-dev -o:speed -vet -strict-style
    echo "built bin/dreamcraft-dev and bin/headless-dev"
    exit 0
    ;;
  --stable|stable) ;;
  *)
    echo "usage: ./build.sh [--dev]" >&2
    exit 2
    ;;
esac

odin build client -out:bin/dreamcraft -o:speed -vet -strict-style
odin build headless -out:bin/headless -o:speed -vet -strict-style
echo "built bin/dreamcraft and bin/headless"

if ! command -v wasm-ld >/dev/null 2>&1; then
  for dir in /opt/homebrew/opt/lld@22/bin /opt/homebrew/opt/lld/bin /usr/lib/llvm-22/bin /usr/lib/llvm-21/bin /usr/lib/llvm-20/bin; do
    if [ -x "$dir/wasm-ld" ]; then
      export PATH="$dir:$PATH"
      break
    fi
  done
fi
if command -v wasm-ld >/dev/null 2>&1; then
  ./web/build.sh
else
  echo "wasm-ld not found; skipping web build"
fi
