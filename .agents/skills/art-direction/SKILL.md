---
name: art-direction
description: DreamCraft visual direction - Akira Toriyama / Dragon Quest character art, Diablo 2 isometric framing, watercolour shading. Use when modelling units, picking palettes, tuning shaders, or reviewing renders.
---

# Art Direction

## Target look

- **Characters: Akira Toriyama / Dragon Quest × Age of Empires.** 5.36-head
  heroic athletic humans (`WARRIOR_SCALE = 0.74`), clean silhouettes, crisp
  facial features (`.Iris`), simple layered armour. Heroic, not cute, not grimdark.
- **World Scale (Age of Empires):** Towering pines & broad oaks (~2.65–3.45
  world units, 1.8–2.3× infantry), mossy boulders, ferns, octagon stone
  waypoints, bannered goals.
- **Framing: Isometric 2:1 ground plane, orthographic (`DEFAULT_ZOOM = 0.55`)**,
  soft contact shadow. The model must still read cleanly at gameplay scale.
- **Paint: watercolour.** Soft washes, pigment pooling, Catmull-Rom dirt trail,
  and bilinear FBM mist fog — not posterised pixel/voxel bands.

## Non-negotiables

- Humans read as humans: long legs, narrow waist, visible face with eyes,
  nose and mouth, hands with thumbs, boots with toes.
- Three values per material (shadow / mid / highlight). No pure black shadows,
  no neon accents, no chrome-blown highlights.
- Palette: warm skin `226,176,136`, linen `198,186,158`, aged brass
  `178,140,82`, blue-grey steel `164,168,176`, indigo cloth `64,84,144`,
  warm leather `124,84,52`.
- Silhouette first: turban, round shield and curved shamshir must be
  recognisable as shapes before any detail.
- Tech is trim, not a light show: thin brass conduits, one glowing lens,
  a rune inlay in the blade. Glow exists to draw the eye, not to light the scene.

## Avoid

- Chibi proportions, oversized heads, balloon trousers, chrome-sphere pauldrons.
- Gold confetti: rivets and stars must sit flat on a surface, never float.
- Busy chest straps and clipped-on ornaments that break the read.
- Saturated primary blue/red, clipped white highlights, hard 8-bit outlines,
  heavy Bayer dithering.
- Mushroom turbans: the wrap sits above the brow, never over the eyes.

## Workflow

1. `./bin/dreamcraft-dev --sheet` renders 12 `build/sheet/*.png` views: front, 3/4,
   side, back, walk, attack, head/helm closeups, enemy, and walk contact/pass profiles.
2. Judge at gameplay scale as well:
   `./bin/dreamcraft-dev --control=7778`, then `GET /screenshot`.
3. Change one thing (proportions, palette, timing, or shading), re-render, compare.

## Animation Rules Discovered (`MatrixRotateXYZ` = `Rx*Ry*Rz`)

- Sign conventions (model `+Y` up, `+Z` forward): `+rx` pitches torso forward / swings
  legs-arms *backward*; `+ry` turns `+Z -> +X` (sword side); `+rz` leans upper body toward `-X`.
- Avoid raw single-frequency `cos(t)` locks: use asymmetric ~58/42 stance/swing timing,
  Richard Williams `Down < Contact < Passing < Up` pelvis wave (`root_offset.y`), and
  progressive kinetic-chain phase lags down spine -> head -> shoulders -> elbows -> wrists.
- Chained cloth (`Cape_1..3`) must let `Cape_2`/`Cape_3` curl negatively against `Cape_1`
  using cumulative angle bounds so the cape S-waves instead of sticking out as a board.

## Code map

| File | Responsibility |
|------|----------------|
| `odin/client/art/mamluk_model.odin` | body, armour, shield, shamshir |
| `odin/client/art/mamluk_head.odin` | face, helm, turban, cape, plume |
| `odin/client/art/{palette,mesh,prims,loft}.odin` | materials, builder, AO, primitives |
| `odin/client/art/rig.odin` | 26 joints, pose matrices, rigid skinning |
| `odin/client/art/anim.odin` | kinetic-chain idle / walk / attack / secondary motion |
| `odin/client/art/{trees,props}.odin` | AoE pine/oak trees, rocks, ferns, waypoints, goal |
| `odin/client/unit_visuals.odin` | runtime blending, coast-to-plant, turn banking, stop settle |
| `odin/client/{ground_tex,env_render,slash_vfx}.odin` | terrain trail, forest/prop instancing, cleave VFX |
| `odin/assets/shaders/{unit,ground}.{vs,fs}` | painterly units/props & terrain fog shaders |
| `odin/assets/shaders/watercolor.fs` | full-res post-process wash, grain, bloom |
