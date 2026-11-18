#!/usr/bin/env bash
# Close-out step: restart the stable build the user plays, without rebuilding.
# Run ./build.sh first. Uses Herdr when HERDR_ENV=1.
set -euo pipefail
cd "$(dirname "$0")"
PORT="${1:-7777}"
LABEL="${DREAMCRAFT_PANE:-game}"
SELF_PANE="${HERDR_PANE_ID:-}"
WS="${HERDR_WORKSPACE_ID:-}"

if [ "${HERDR_ENV:-}" != "1" ] || ! command -v herdr >/dev/null 2>&1 || [ -z "$WS" ]; then
  exec ./bin/dreamcraft "--control=$PORT"
fi

PANE_ID=$(herdr pane list --workspace "$WS" | python3 -c '
import json, sys
label, self_id = sys.argv[1], sys.argv[2]
for p in json.load(sys.stdin)["result"]["panes"]:
    if p.get("pane_id") == self_id:
        continue
    if p.get("label") == label:
        print(p["pane_id"])
        break
' "$LABEL" "$SELF_PANE")

if [ -z "$PANE_ID" ]; then
  PANE_ID=$(herdr tab create --workspace "$WS" --cwd "$PWD" --label "$LABEL" --no-focus | python3 -c '
import json, sys
print(json.load(sys.stdin)["result"]["root_pane"]["pane_id"])
')
  herdr pane rename "$PANE_ID" "$LABEL" >/dev/null
fi

NEEDS_INT=$(herdr pane process-info --pane "$PANE_ID" | python3 -c '
import json, os, sys
shells = {"zsh", "bash", "sh", "fish"}
procs = json.load(sys.stdin)["result"]["process_info"].get("foreground_processes", [])
print("1" if any(os.path.basename(p.get("name", "")) not in shells for p in procs) else "0")
')
if [ "$NEEDS_INT" = "1" ]; then
  herdr pane send-keys "$PANE_ID" ctrl+c >/dev/null 2>&1 || true
  sleep 0.5
fi

RUN_CMD=$(python3 -c '
import shlex, sys
print(f"cd {shlex.quote(sys.argv[1])} && ./bin/dreamcraft --control={sys.argv[2]}")
' "$PWD" "$PORT")
herdr pane run "$PANE_ID" "$RUN_CMD" >/dev/null

for _ in $(seq 1 50); do
  if curl -fsS --max-time 0.2 "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done
curl -fsS --max-time 2 "http://127.0.0.1:$PORT/state" >/dev/null
echo "stable build running in herdr pane $PANE_ID ($WS:$LABEL) on :$PORT"
