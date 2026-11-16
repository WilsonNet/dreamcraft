#!/usr/bin/env bash
# Close-out step: restart the stable build the user plays, without rebuilding.
# Run ./build.sh first.
set -euo pipefail
cd "$(dirname "$0")"
PORT="${1:-7777}"
SESSION="${DREAMCRAFT_SESSION:-dreamcraft}"
WINDOW="${DREAMCRAFT_WINDOW:-game}"

if ! command -v tmux >/dev/null 2>&1; then
  exec ./bin/dreamcraft "--control=$PORT"
fi

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux new-session -d -s "$SESSION" -n "$WINDOW" -c "$PWD"
fi
if ! tmux list-windows -t "$SESSION" -F '#{window_name}' | grep -qx "$WINDOW"; then
  tmux new-window -t "$SESSION" -n "$WINDOW" -c "$PWD"
fi

tmux send-keys -t "$SESSION:$WINDOW" C-c 2>/dev/null || true
sleep 0.5
tmux send-keys -t "$SESSION:$WINDOW" "./bin/dreamcraft --control=$PORT" Enter

for _ in $(seq 1 50); do
  if curl -fsS --max-time 0.2 "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done
curl -fsS --max-time 2 "http://127.0.0.1:$PORT/state" >/dev/null

if command -v osascript >/dev/null 2>&1; then
  osascript -e 'tell application "System Events" to tell process "dreamcraft" to set frontmost to true' >/dev/null 2>&1 || true
fi
echo "stable build running in tmux $SESSION:$WINDOW on :$PORT"
