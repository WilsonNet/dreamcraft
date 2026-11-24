#!/usr/bin/env bash
# Start the agent's dev client without touching the stable build.
#   ./run-dev.sh --control=7778
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p bin
odin build client -collection:vinland="${VINLAND_UI:-../../vinland-ui}" -out:bin/dreamcraft-dev -o:speed -vet -strict-style -define:DREAMCRAFT_DEV=true
exec ./bin/dreamcraft-dev "$@"
