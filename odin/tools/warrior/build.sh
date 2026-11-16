#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

blender --background --python build_warrior.py
mkdir -p ../../assets/warrior
cp build/warrior_blue.glb build/warrior_red.glb build/preview.png ../../assets/warrior/
echo "warrior assets updated in odin/assets/warrior"
