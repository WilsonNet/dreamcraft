# Product

<!-- impeccable:product-schema 1 -->

## Platform

desktop (native Odin + raylib, with secondary js_wasm32 canvas web build)

## Users

Solo game developer / creator-player tuning DreamCraft RTS 3D character, tree, and prop meshes directly during gameplay without context-switching to external heavyweight DCC tools.

## Product Purpose

DreamCraft is a fantasy RTS (spiritual successor to StarCraft: Brood War) written in Odin with a deterministic Q16.16 fixed-point simulation and a native full-3D Akira Toriyama x Age of Empires watercolour renderer. The in-game Model Editor lets the creator press `Esc -> Model Editor`, pick any live unit or environment mesh, adjust geometry/materials/bones using familiar Blender Edit Mode shortcuts, hit `Save`, and `Resume Game` with the updated 3D mesh live in the world and persisted as git-friendly `.odin` asset modules.

## Positioning

Code-first two-way procedural asset pipeline (`Odin <-> Edit Mesh <-> Live GPU`): instead of opaque binary `.fbx`/`.glb` blobs that break Git diffs or require offline export-reimport loops, DreamCraft stores editable meshes as deterministic, human-readable, sub-part-split `.odin` modules orchestrated by a root `.odin` manifest (`odin/client/art/models/`) that both compile directly into release builds and hot-reload inside the running game client.

## Operating Context

- In-game pause loop: `Esc` -> `Model Editor` -> choose model (`Mamluk Base [Hero/Player/Enemy preview & optional variant fork]`, `Pine Tall`, `Pine Mid`, `Oak Broad`, `Oak Elder`, `Boulder Moss`, `Shrub Fern`, `Waypoint Disc`, `Goal Banner`, `Selection Ring`) -> edit mesh -> `Save` -> `Resume Game`.
- Dev workflow runs on the Dev lane (`./bin/dreamcraft-dev --control=7778` with `DEV - ` window title), then promotes via `./build.sh` and `./restart-build.sh` (`:7777`).
- Future extensibility: structured around clean `Poly_Mesh` geometry, `Mat_Kind` vertex palettes, `Bone_Id` rigid-skinning assignments, and pose preview so future rigging, animation keyframes, and custom prop authoring plug into the same pipeline.

## Capabilities and Constraints

- **Determinism & Layering:** Simulation (`odin/game/`) stays 100% pure integer/Q16.16 and untouched by rendering/editor code.
- **Blender Edit Mode Core:** `1`/`2`/`3` (Vertex/Edge/Face), `G`/`R`/`S` + `X`/`Y`/`Z` axis lock + 3D gizmo, `E` (Extrude), `I` (Inset), `Ctrl+R` (Loop Cut), `K` (Knife/Split), `F` (Fill), `X` (Delete menu), `M` (Merge), `B` (Box Select), `A`/`Alt+A` (Select All/None), `L` (Select Linked/Bone), `Alt+Z` (Wireframe/X-Ray), `Ctrl+Z`/`Ctrl+Shift+Z` (Undo/Redo), plus `X-Mirror`.
- **DreamCraft Specialized Pipeline:** Assign `Mat_Kind` palette materials and `Bone_Id` weights (no UV unwrap/BSDF nodes/sculpt brushes required), toggle Hero (`Liiroy`) / Player / Enemy (`Luk Soldier`) team palettes, toggle watercolour post-shader vs clean edit shading, and preview live Idle/Walk/Attack poses while editing.
- **Git-Friendly Odin Format:** Deterministic `%.4f` fixed formatting, canonical element order (1-line diffs for vertex edits), split cleanly under the repo's 420-line file limit and 50-line function limit, orchestrated via `manifest.odin`.

## Brand Commitments

- **Visual Direction (`.agents/skills/art-direction/SKILL.md`):** Akira Toriyama x Dragon Quest heroic silhouettes (`5.36`-head proportions), AoE-scale vegetation, warm olive/brass/gold watercolour aesthetic (`#0f180f` forest-slate surfaces, `#5a965a` sage borders, `#ebd778` burnished gold accents).
- **Raylib Native Desktop UI:** Clean immediate-mode raylib tool panels, crisp legible ASCII labels (no broken UTF-8 glyphs in default bitmap font), zero cluttering animations or modal walls during viewport modeling.

## Evidence on Hand

- Existing procedural builders & shaders in `odin/client/art/` (`mamluk_model.odin`, `mamluk_head.odin`, `trees.odin`, `props.odin`, `rig.odin`, `anim.odin`, `palette.odin`, `mesh.odin`), runtime GPU wrappers in `odin/client/` (`unit_visuals.odin`, `env_assets.odin`, `render_hud.odin`), and HTTP control API (`odin/control/`).

## Product Principles

1. **Instant Round-Trip:** `Esc -> Model Editor -> Save -> Resume Game` updates the live battlefield with zero restart.
2. **Git Diff Clarity:** Editing one vertex, face, material, or bone produces tiny, localized, reviewable diffs in `.odin` source files.
3. **Muscle-Memory Fidelity:** Respect Blender's core Edit Mode keystrokes (`G/R/S+X/Y/Z`, `1/2/3`, `E/I/Ctrl+R/K/F/X/M/B/A/L/Ctrl+Z`) while stripping non-game complexity.
4. **Future Pipeline Spine:** Every model is an inspectable, serializable `Asset_Mesh` + manifest entry ready for future rig, clip, and prop workflows.
