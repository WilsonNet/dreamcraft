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

The HUD and editor chrome are drawn by vinland-ui (`vinland:vui/gl`), not by shaders here.

Run with `--no-shader` to bypass the post pass.
