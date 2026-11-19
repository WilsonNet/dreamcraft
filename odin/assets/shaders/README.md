# Shaders

Native client:

- `unit.vs` / `unit.fs` — painterly material shader for procedural unit meshes and
  environment props (`u_tint`, `u_fog_vis`). Vertex colour carries albedo + baked AO;
  UV carries `(metalness, glow)`. Four crisp tone washes, Beer–Lambert pigment
  compositing, specular metal, warm rim light.
- `ground.vs` / `ground.fs` — terrain & fog shader combining the `1280×800` procedural
  albedo wash with the `80×50` fog state texture, bilinear FBM mist edges, and
  world-border vignette fade.
- `watercolor.fs` — post-process applied over the full-resolution bilinear scene
  target. Wet-bleed wash, pigment pooling on edges, paper grain, subtle bloom,
  warm/cool split tone and a soft vignette.
- `pixelart.fs` — retired. Kept for reference; it produced the hard pixel
  outline and 12-level posterize that read as voxel art.
- `ui_sdf.vs` / `ui_sdf.fs` — batched 1-draw-call Quickshell-style UI SDF card/pill
  shader (4-corner rounding, soft shadows, top glass rim, click ripples, progress pills).
- `ui_clip_tex.fs` — rounded `ClipRRect` shader for clipped textures such as the minimap
  and model turntable preview.

UI typography renders via dual-resolution anti-aliased TTF atlases (`client/ui/font.odin`)
so small stems and headings remain crisp at both Retina and 1x DPI.

Run with `--no-shader` to bypass the post pass.
