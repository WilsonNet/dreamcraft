#+build darwin
package gfx

import "base:intrinsics"
import "core:fmt"
import NS "core:sys/darwin/Foundation"
import CA "vendor:darwin/QuartzCore"
import sdl "vendor:sdl3"

foreign import coregraphics "system:CoreGraphics.framework"

@(private, default_calling_convention = "c")
foreign coregraphics {
	CGDisplayCopyColorSpace :: proc(display: u32) -> rawptr ---
}

// Metal (MSL shaders).
@(private)
create_device :: proc() -> ^sdl.GPUDevice {
	return sdl.CreateGPUDevice({.MSL}, false, "metal")
}

// SDL tags its CAMetalLayer kCGColorSpaceSRGB (SDL_gpu_metal.m: at claim and in
// SetGPUSwapchainParameters), so Core Animation colour-matches sRGB to the display profile.
// OpenGL surfaces are not colour-matched (pixels reach the display as-is) and the game's
// palette was tuned under OpenGL; on a display whose profile is not sRGB the Metal frame
// read ~10% darker. Tagging the layer with the screen's own profile makes the match an
// identity. Call after SetGPUSwapchainParameters and when the window changes display.
@(private)
platform_after_claim :: proc(window: ^sdl.Window) {
	props := sdl.GetWindowProperties(window)
	nswin := cast(^NS.Object)sdl.GetPointerProperty(props, sdl.PROP_WINDOW_COCOA_WINDOW_POINTER, nil)
	if nswin == nil {
		return
	}
	screen := intrinsics.objc_send(^NS.Object, nswin, "screen")
	if screen == nil {
		return
	}
	desc := intrinsics.objc_send(^NS.Dictionary, screen, "deviceDescription")
	num := cast(^NS.Number)desc->objectForKey(cast(^NS.Object)NS.AT("NSScreenNumber"))
	if num == nil {
		return
	}
	cs := CGDisplayCopyColorSpace(u32(num->u32Value()))
	content := intrinsics.objc_send(^NS.Object, nswin, "contentView")
	if cs != nil && content != nil {
		tag_layers(content, 0, cs)
	}
}

@(private)
tag_layers :: proc(view: ^NS.Object, depth: int, cs: rawptr) {
	if view == nil || depth > 4 {
		return
	}
	layer := intrinsics.objc_send(^NS.Object, view, "layer")
	if layer != nil && intrinsics.objc_send(bool, layer, "isKindOfClass:", intrinsics.objc_find_class("CAMetalLayer")) {
		CA.MetalLayer_setColorspace(cast(^CA.MetalLayer)layer, auto_cast cs)
	}
	subs := intrinsics.objc_send(^NS.Array, view, "subviews")
	if subs == nil {
		return
	}
	for i in 0 ..< subs->count() {
		tag_layers(cast(^NS.Object)subs->objectAtIndex(i), depth + 1, cs)
	}
}

// macOS 26+ often leaves apps launched from a terminal inactive (no key window, so no
// mouse-moved or keyboard events). GLFW activates the app at startup; do the same.
@(private)
platform_activate :: proc() {
	app := intrinsics.objc_send(^NS.Object, cast(^NS.Object)intrinsics.objc_find_class("NSApplication"), "sharedApplication")
	if app != nil {
		intrinsics.objc_send(nil, app, "activateIgnoringOtherApps:", NS.BOOL(true))
	}
}

// GFX_TRACE diagnostics: application activation and key-window state.
app_state_debug :: proc() -> string {
	app := intrinsics.objc_send(^NS.Object, cast(^NS.Object)intrinsics.objc_find_class("NSApplication"), "sharedApplication")
	props := sdl.GetWindowProperties(W.window)
	nswin := cast(^NS.Object)sdl.GetPointerProperty(props, sdl.PROP_WINDOW_COCOA_WINDOW_POINTER, nil)
	key := intrinsics.objc_send(^NS.Object, app, "keyWindow")
	return fmt.tprintf("active=%v policy=%v keyWindow=%p ours=%p canBecomeKey=%v isKey=%v visible=%v flags=%v",
		intrinsics.objc_send(NS.BOOL, app, "isActive"), intrinsics.objc_send(int, app, "activationPolicy"),
		key, nswin, intrinsics.objc_send(NS.BOOL, nswin, "canBecomeKeyWindow"), intrinsics.objc_send(NS.BOOL, nswin, "isKeyWindow"),
		intrinsics.objc_send(NS.BOOL, nswin, "isVisible"), sdl.GetWindowFlags(W.window))
}
