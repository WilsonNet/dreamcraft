#!/usr/bin/env bash
# Test lane. Builds only dev binaries, never overwrites the stable build.
set -euo pipefail
cd "$(dirname "$0")"

echo "== unit tests: game =="
odin test game -vet -strict-style

echo "== unit tests: control =="
odin test control -vet -strict-style

echo "== unit tests: art =="
odin test client/art -vet -strict-style

echo "== unit tests: art/edit =="
odin test client/art/edit -vet -strict-style

echo "== unit tests: art/anim_edit =="
odin test client/art/anim_edit -vet -strict-style

echo "== unit tests: art/anim_rig =="
odin test client/art/anim_rig -vet -strict-style

echo "== unit tests: svg =="
odin test client/svg -vet -strict-style

echo "== unit tests: mesh_cli =="
odin test tools/mesh_cli -vet -strict-style

echo "== unit tests: client projection =="
odin test client -collection:vinland="${VINLAND_UI:-../../vinland-ui}" -vet -strict-style

echo "== build: dev lane =="
mkdir -p bin
odin build headless -out:bin/headless-dev -o:speed
odin build client -collection:vinland="${VINLAND_UI:-../../vinland-ui}" -out:bin/dreamcraft-dev -o:speed -define:DREAMCRAFT_DEV=true
odin build tools/mesh_cli -out:bin/dreamcraft-mesh-dev -o:speed

echo "== headless script test =="
./bin/headless-dev --script tests/smoke.jsonl >/dev/null

echo "== level 1 playthrough (army attack-moves along the road to the goal) =="
./bin/headless-dev --script tests/level1_playthrough.jsonl >/dev/null

echo "== replay test =="
./bin/headless-dev --replay tests/replay.jsonl >/dev/null
RECORD="${TMPDIR:-/tmp}/dreamcraft-record.jsonl"
./bin/headless-dev --script tests/smoke.jsonl --record "$RECORD" >/dev/null
./bin/headless-dev --replay "$RECORD" >/dev/null

echo "== web wasm test =="
if command -v node >/dev/null 2>&1; then
  ./web/test.sh
else
  echo "node not found; skipping web test"
fi

echo "== HTTP control test =="
DREAMCRAFT_BIN=./bin/headless-dev ./tests/control_smoke.sh

echo "all tests passed"
