package gfx

import "core:c"
import "core:math"
import "core:mem"
import "core:strings"
import sdl "vendor:sdl3"
import stbi "vendor:stb/image"

// CPU images (always RGBA8 here), textures, render textures and pixel readback.

@(private)
image_alloc :: proc(w, h: int) -> Image {
	return Image{
		data = MemAlloc(c.uint(w * h * 4)),
		width = c.int(w),
		height = c.int(h),
		mipmaps = 1,
		format = .UNCOMPRESSED_R8G8B8A8,
	}
}

@(private)
image_pixels :: proc(img: Image) -> []Color {
	if img.data == nil {
		return nil
	}
	return (cast([^]Color)img.data)[:int(img.width) * int(img.height)]
}

GenImageColor :: proc(width, height: c.int, color: Color) -> Image {
	img := image_alloc(int(width), int(height))
	for &p in image_pixels(img) {
		p = color
	}
	return img
}

GenImageGradientRadial :: proc(width, height: c.int, density: f32, inner, outer: Color) -> Image {
	img := image_alloc(int(width), int(height))
	px := image_pixels(img)
	radius := f32(min(width, height)) / 2
	cx, cy := f32(width) / 2, f32(height) / 2
	for y in 0 ..< int(height) {
		for x in 0 ..< int(width) {
			dist := math.hypot(f32(x) - cx, f32(y) - cy)
			f := clamp((dist - radius * density) / (radius * (1 - density)), 0, 1)
			px[y * int(width) + x] = Color{
				u8(f32(outer.r) * f + f32(inner.r) * (1 - f)),
				u8(f32(outer.g) * f + f32(inner.g) * (1 - f)),
				u8(f32(outer.b) * f + f32(inner.b) * (1 - f)),
				u8(f32(outer.a) * f + f32(inner.a) * (1 - f)),
			}
		}
	}
	return img
}

UnloadImage :: proc(image: Image) {
	MemFree(image.data)
}

IsImageValid :: proc(image: Image) -> bool {
	return image.data != nil && image.width > 0 && image.height > 0
}

ImageFlipVertical :: proc(image: ^Image) {
	px := image_pixels(image^)
	w, h := int(image.width), int(image.height)
	for y in 0 ..< h / 2 {
		a := px[y * w:][:w]
		b := px[(h - 1 - y) * w:][:w]
		for x in 0 ..< w {
			a[x], b[x] = b[x], a[x]
		}
	}
}

// Images are always RGBA8 in gfx: format conversion only accepts that target.
ImageFormat :: proc(image: ^Image, newFormat: PixelFormat) {
	assert(newFormat == .UNCOMPRESSED_R8G8B8A8 && image.format == .UNCOMPRESSED_R8G8B8A8, "gfx: only RGBA8 images are supported")
}

@(private)
png_writer :: proc "c" (ctx: rawptr, data: rawptr, size: c.int) {
	buf := cast(^[dynamic]u8)ctx
	context = {}
	src := ([^]u8)(data)[:size]
	append(buf, ..src)
}

ExportImage :: proc(image: Image, fileName: cstring) -> bool {
	if !IsImageValid(image) {
		return false
	}
	name := string(fileName)
	if !strings.has_suffix(strings.to_lower(name, context.temp_allocator), ".png") {
		return false
	}
	return stbi.write_png(fileName, image.width, image.height, 4, image.data, image.width * 4) != 0
}

ExportImageToMemory :: proc(image: Image, fileType: cstring, fileSize: ^c.int) -> [^]u8 {
	if !IsImageValid(image) {
		return nil
	}
	buf := make([dynamic]u8, 0, int(image.width) * int(image.height), context.temp_allocator)
	if stbi.write_png_to_func(png_writer, &buf, image.width, image.height, 4, image.data, image.width * 4) == 0 {
		return nil
	}
	out := cast([^]u8)MemAlloc(c.uint(len(buf)))
	mem.copy(out, raw_data(buf), len(buf))
	fileSize^ = c.int(len(buf))
	return out
}

// ------------------------------------------------------------------ textures

@(private)
texture_struct :: proc(id: u32) -> Texture {
	t := &G.textures[id]
	return Texture{id = c.uint(id), width = c.int(t.w), height = c.int(t.h), mipmaps = c.int(t.levels), format = .UNCOMPRESSED_R8G8B8A8}
}

LoadTextureFromImage :: proc(image: Image) -> Texture2D {
	if G.dev == nil || !IsImageValid(image) {
		return {}
	}
	px := mem.byte_slice(image.data, int(image.width) * int(image.height) * 4)
	id := texture_create(int(image.width), int(image.height), px, false)
	if id == 0 {
		return {}
	}
	return texture_struct(id)
}

IsTextureValid :: proc(texture: Texture2D) -> bool {
	id := int(texture.id)
	return id > 0 && id < len(G.textures) && G.textures[id].alive
}

UnloadTexture :: proc(texture: Texture2D) {
	id := int(texture.id)
	if id <= 0 || id >= len(G.textures) || u32(id) == G.white || !G.textures[id].alive {
		return
	}
	sdl.ReleaseGPUTexture(G.dev, G.textures[id].tex)
	G.textures[id] = {}
}

// Replaces the whole texture's pixels; the upload runs in this frame's copy pass.
UpdateTexture :: proc(texture: Texture2D, pixels: rawptr) {
	id := u32(texture.id)
	if int(id) <= 0 || int(id) >= len(G.textures) || !G.textures[id].alive || pixels == nil {
		return
	}
	t := &G.textures[id]
	off := stage(pixels, t.w * t.h * 4)
	append(&G.tex_uploads, Tex_Upload{tex = id, off = off, w = u32(t.w), h = u32(t.h), whole = true})
}

UpdateTextureRec :: proc(texture: Texture2D, rec: Rectangle, pixels: rawptr) {
	id := u32(texture.id)
	if int(id) <= 0 || int(id) >= len(G.textures) || !G.textures[id].alive || pixels == nil {
		return
	}
	w, h := u32(rec.width), u32(rec.height)
	off := stage(pixels, int(w * h * 4))
	append(&G.tex_uploads, Tex_Upload{tex = id, off = off, x = u32(rec.x), y = u32(rec.y), w = w, h = h})
}

SetTextureFilter :: proc(texture: Texture2D, filter: TextureFilter) {
	id := int(texture.id)
	if id > 0 && id < len(G.textures) && G.textures[id].alive {
		G.textures[id].filter = filter
	}
}

SetTextureWrap :: proc(texture: Texture2D, wrap: TextureWrap) {
	id := int(texture.id)
	if id > 0 && id < len(G.textures) && G.textures[id].alive {
		G.textures[id].wrap = wrap
	}
}

GenTextureMipmaps :: proc(texture: ^Texture2D) {
	id := int(texture.id)
	if id <= 0 || id >= len(G.textures) || !G.textures[id].alive {
		return
	}
	t := &G.textures[id]
	levels := u32(1)
	for (t.w >> levels) > 0 || (t.h >> levels) > 0 {
		levels += 1
	}
	if levels <= 1 || t.levels == levels {
		return
	}
	nt := make_gpu_texture(t.w, t.h, COLOR_FORMAT, {.SAMPLER, .COLOR_TARGET}, levels)
	if nt == nil {
		return
	}
	flush()
	cmd := sdl.AcquireGPUCommandBuffer(G.dev)
	cp := sdl.BeginGPUCopyPass(cmd)
	sdl.CopyGPUTextureToTexture(cp, {texture = t.tex}, {texture = nt}, u32(t.w), u32(t.h), 1, false)
	sdl.EndGPUCopyPass(cp)
	sdl.GenerateMipmapsForGPUTexture(cmd, nt)
	_ = sdl.SubmitGPUCommandBuffer(cmd)
	sdl.ReleaseGPUTexture(G.dev, t.tex)
	t.tex = nt
	t.levels = levels
	texture.mipmaps = c.int(levels)
}

// ------------------------------------------------------------------ render textures

LoadRenderTexture :: proc(width, height: c.int) -> RenderTexture2D {
	if G.dev == nil || width <= 0 || height <= 0 {
		return {}
	}
	append(&G.targets, Target{})
	idx := len(G.targets) - 1
	target_ensure(idx, int(width), int(height))
	t := &G.targets[idx]
	if !t.alive {
		return {}
	}
	G.textures[t.color].filter = .POINT
	return RenderTexture2D{id = c.uint(idx), texture = texture_struct(t.color)}
}

IsRenderTextureValid :: proc(target: RenderTexture2D) -> bool {
	id := int(target.id)
	return id > 0 && id < len(G.targets) && G.targets[id].alive
}

UnloadRenderTexture :: proc(target: RenderTexture2D) {
	id := int(target.id)
	if id <= 0 || id >= len(G.targets) || !G.targets[id].alive {
		return
	}
	_ = sdl.WaitForGPUIdle(G.dev)
	t := &G.targets[id]
	if t.color != 0 && G.textures[t.color].alive {
		sdl.ReleaseGPUTexture(G.dev, G.textures[t.color].tex)
		G.textures[t.color] = {}
	}
	if t.depth != nil {
		sdl.ReleaseGPUTexture(G.dev, t.depth)
	}
	t^ = {}
}

// ------------------------------------------------------------------ readback

@(private)
download :: proc(tex: ^sdl.GPUTexture, w, h: int) -> Image {
	size := w * h * 4
	xfer := sdl.CreateGPUTransferBuffer(G.dev, {usage = .DOWNLOAD, size = u32(size)})
	if xfer == nil {
		return {}
	}
	defer sdl.ReleaseGPUTransferBuffer(G.dev, xfer)
	cmd := sdl.AcquireGPUCommandBuffer(G.dev)
	cp := sdl.BeginGPUCopyPass(cmd)
	sdl.DownloadFromGPUTexture(cp, {texture = tex, w = u32(w), h = u32(h), d = 1}, {transfer_buffer = xfer, pixels_per_row = u32(w), rows_per_layer = u32(h)})
	sdl.EndGPUCopyPass(cp)
	fence := sdl.SubmitGPUCommandBufferAndAcquireFence(cmd)
	if fence != nil {
		_ = sdl.WaitForGPUFences(G.dev, true, &fence, 1)
		sdl.ReleaseGPUFence(G.dev, fence)
	} else {
		_ = sdl.WaitForGPUIdle(G.dev)
	}
	src := sdl.MapGPUTransferBuffer(G.dev, xfer, false)
	if src == nil {
		return {}
	}
	img := image_alloc(w, h)
	mem.copy(img.data, src, size)
	sdl.UnmapGPUTransferBuffer(G.dev, xfer)
	return img
}

// Render textures come back bottom-up, as with raylib on OpenGL.
LoadImageFromTexture :: proc(texture: Texture2D) -> Image {
	id := int(texture.id)
	if G.dev == nil || id <= 0 || id >= len(G.textures) || !G.textures[id].alive {
		return {}
	}
	flush()
	t := &G.textures[id]
	return download(t.tex, t.w, t.h)
}

// The last presented frame, top-down, in physical pixels.
LoadImageFromScreen :: proc() -> Image {
	if G.dev == nil {
		return {}
	}
	if len(G.passes) > 0 {
		flush()
	}
	_ = sdl.WaitForGPUIdle(G.dev)
	back := &G.targets[0]
	if !back.alive {
		return {}
	}
	img := download(G.textures[back.color].tex, back.w, back.h)
	// the window is opaque: report what it shows, like raylib
	for &p in image_pixels(img) {
		p.a = 255
	}
	return img
}
