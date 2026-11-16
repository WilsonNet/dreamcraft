# Shaders

`pixelart.fs` is the native post-process shader:

- one-texel dark outline on luminance edges,
- 12-level posterization,
- subtle 4×4 Bayer dithering, skipped on near-black fog.

It runs when the half-resolution 3D render target is upscaled to the window.
HUD text stays full-resolution and unshaded.
