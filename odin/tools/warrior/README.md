# Warrior Model Pipeline

Low-poly melee warrior for the native 3D client.

```bash
./build.sh
```

Runs Blender headless and writes:

- `../../assets/warrior/warrior_blue.glb`
- `../../assets/warrior/warrior_red.glb`
- `../../assets/warrior/preview.png`

The GLBs contain:

- a skinned 8-bone rig,
- `idle` action (33 keyed frames at 24 fps),
- `walk` action (17 keyed frames),
- `attack` action (11 keyed frames).

The raylib client loads one model instance per unit, so units can play
different animations independently. `idle`/`walk` loop; `attack` is one-shot
and is triggered when the simulation cooldown resets.

Requires Blender 4+ (tested with 5.3). No Blender MCP is needed; the pipeline is
deterministic and headless.
