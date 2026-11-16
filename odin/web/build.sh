#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v wasm-ld >/dev/null 2>&1; then
  for dir in /opt/homebrew/opt/lld@22/bin /opt/homebrew/opt/lld/bin /usr/lib/llvm-22/bin /usr/lib/llvm-21/bin /usr/lib/llvm-20/bin; do
    if [ -x "$dir/wasm-ld" ]; then
      export PATH="$dir:$PATH"
      break
    fi
  done
fi

if ! command -v wasm-ld >/dev/null 2>&1; then
  echo "wasm-ld not found. Install Odin with LLVM/lld, or add wasm-ld to PATH." >&2
  exit 2
fi

odin build . -target:js_wasm32 -out:main.wasm -o:speed -vet -strict-style
echo "built $(pwd)/main.wasm"
