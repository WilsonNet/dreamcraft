#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

blender --background --python build_warrior.py
mkdir -p ../assets
cp build/warrior_blue.glb build/warrior_red.glb build/preview.png ../assets/
echo "warrior assets updated in legacy/warrior-glb/assets"
