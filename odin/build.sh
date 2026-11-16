#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p bin

odin build client -out:bin/dreamcraft -o:speed -vet -strict-style
odin build headless -out:bin/headless -o:speed -vet -strict-style
echo "built bin/dreamcraft and bin/headless"
