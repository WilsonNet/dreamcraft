# Shaders

Native client:

- `unit.vs` / `unit.fs` — painterly material shader for procedural unit meshes.
  Vertex colour carries albedo + baked AO, UV carries (metalness, glow).
  Six soft tone washes, Beer–Lambert pigment compositing, warm rim light.
- `watercolor.fs` — post-process applied when the half-resolution 3D target is
  upscaled. Wet-bleed, pigment pooling on edges, paper grain, cheap bloom,
  warm/cool split tone and a soft vignette.
- `pixelart.fs` — retired. Kept for reference; it produced the hard pixel
  outline and 12-level posterize that read as voxel art.

Run with `--no-shader` to bypass the post pass.
