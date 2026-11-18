---
name: art-direction
description: DreamCraft visual direction - Akira Toriyama / Dragon Quest character art, Diablo 2 isometric framing, watercolour shading. Use when modelling units, picking palettes, tuning shaders, or reviewing renders.
---

# Art Direction

## Target look

- **Characters: Akira Toriyama / Dragon Quest / Chrono Trigger.** Lean,
  athletic humans (~6.5–7 heads), clean silhouettes, crisp facial features,
  simple layered armour. Heroic, not cute, not grimdark.
- **Framing: Diablo 2 pre-rendered isometric.** 2:1 ground plane, orthographic
  camera, unit ≈15 % of screen height, soft contact shadow. The model must
  still read at 64 px.
- **Paint: watercolour.** Soft washes and pigment pooling, not posterised
  pixel/voxel bands. Warm key light, cool shadow, paper grain.

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

1. `./bin/dreamcraft-dev --sheet` renders `build/sheet/*.png`: front, 3/4,
   side, back, walk, attack, head and helm close-ups, all through the real
   shader stack.
2. Judge at gameplay scale as well:
   `./bin/dreamcraft-dev --control=7778 --zoom=0.65`, then `GET /screenshot`.
3. Change one thing (proportions, palette, or shading), re-render, compare.
   Never tune geometry and shading in the same look.

## Code map

| File | Responsibility |
|------|----------------|
| `odin/client/mamluk_model.odin` | body, armour, shield, shamshir |
| `odin/client/mamluk_head.odin` | face, helm, turban, cape |
| `odin/client/unit_mesh.odin` | primitives, palette, AO, bone remap |
| `odin/client/unit_rig.odin` | joints, pose matrices, skinning |
| `odin/client/unit_anim.odin` | idle / walk / attack / secondary motion |
| `odin/assets/shaders/unit.fs` | painterly material shading |
| `odin/assets/shaders/watercolor.fs` | post-process wash, grain, bloom |
