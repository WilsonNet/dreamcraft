#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
PORT="${1:-8080}"
echo "DreamCraft web: http://localhost:$PORT/"
exec python3 -m http.server "$PORT" --bind 127.0.0.1
