#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

echo "== unit tests: game =="
odin test game -vet -strict-style

echo "== unit tests: control =="
odin test control -vet -strict-style

echo "== build =="
mkdir -p bin
odin build headless -out:bin/headless -o:speed
odin build client -out:bin/dreamcraft -o:speed

echo "== headless script test =="
./bin/headless --script tests/smoke.jsonl >/dev/null

echo "== replay test =="
./bin/headless --replay tests/replay.jsonl >/dev/null
RECORD="${TMPDIR:-/tmp}/dreamcraft-record.jsonl"
./bin/headless --script tests/smoke.jsonl --record "$RECORD" >/dev/null
./bin/headless --replay "$RECORD" >/dev/null

echo "== web wasm test =="
if command -v node >/dev/null 2>&1; then
  ./web/test.sh
else
  echo "node not found; skipping web test"
fi

echo "== HTTP control test =="
./tests/control_smoke.sh

echo "all tests passed"
