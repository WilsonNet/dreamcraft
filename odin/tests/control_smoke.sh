#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
PORT="${1:-17990}"
BIN=./bin/headless
LOG=/tmp/dreamcraft-control-test.log

"$BIN" --serve="$PORT" --paused >"$LOG" 2>&1 &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true' EXIT

for _ in $(seq 1 50); do
  if curl -fsS --max-time 0.2 "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

health=$(curl -fsS --max-time 2 "http://127.0.0.1:$PORT/health")
echo "$health" | grep -q '"ok":true'

state=$(curl -fsS --max-time 2 "http://127.0.0.1:$PORT/state")
echo "$state" | grep -q '"valid":true'

units=$(curl -fsS --max-time 2 "http://127.0.0.1:$PORT/units")
echo "$units" | grep -q '"team":"player"'

fog=$(curl -fsS --max-time 2 "http://127.0.0.1:$PORT/fog")
echo "$fog" | grep -q 'P'

reset=$(curl -fsS --max-time 2 -X POST "http://127.0.0.1:$PORT/command" -H 'Content-Type: application/json' -d '{"cmd":"reset"}')
echo "$reset" | grep -q '"ok":true'

goto=$(curl -fsS --max-time 2 -X POST "http://127.0.0.1:$PORT/command" -H 'Content-Type: application/json' -d '{"cmd":"goto","x":10,"y":25}')
echo "$goto" | grep -q '"ok":true'

run=$(curl -fsS --max-time 2 -X POST "http://127.0.0.1:$PORT/command" -H 'Content-Type: application/json' -d '{"cmd":"run","ticks":140}')
echo "$run" | grep -q '"ok":true'

verify=$(curl -fsS --max-time 2 -X POST "http://127.0.0.1:$PORT/command" -H 'Content-Type: application/json' -d '{"cmd":"verify","verify":{"type":"player_at","x":10,"y":25}}')
echo "$verify" | grep -q '"ok":true'

valid=$(curl -fsS --max-time 2 -X POST "http://127.0.0.1:$PORT/command" -H 'Content-Type: application/json' -d '{"cmd":"verify","verify":{"type":"valid"}}')
echo "$valid" | grep -q '"ok":true'

echo "control API smoke test passed"
