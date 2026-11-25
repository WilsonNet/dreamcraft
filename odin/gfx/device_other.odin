#+build !darwin
package gfx

import sdl "vendor:sdl3"

// Vulkan (SPIR-V shaders) on Linux and Windows.
@(private)
create_device :: proc() -> ^sdl.GPUDevice {
	return sdl.CreateGPUDevice({.SPIRV}, false, nil)
}

@(private)
platform_after_claim :: proc(window: ^sdl.Window) {}

@(private)
platform_activate :: proc() {}
