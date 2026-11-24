// Model Editor Quickshell UI chrome: Topbar, Tool Rail, Inspector cards, Statusbar, and Popups.
package main

import "core:fmt"
import "core:strings"

@(private)
editor_modal_status_text :: proc() -> cstring {
	ed := &app.editor
	if !ed.modal_active { return "" }
	num := ed.num_len > 0 ? string(ed.num_buf[:ed.num_len]) : ""
	axis := ed.axis_lock != .None ? fmt.tprintf(" [%v]", ed.axis_lock) : ""
	switch ed.modal_op {
	case .Grab:     return cstring_t(fmt.tprintf("Grab%s (%.3f %.3f %.3f) %s | LMB confirm, RMB/Esc cancel", axis, ed.modal_delta[0], ed.modal_delta[1], ed.modal_delta[2], num))
	case .Rotate:   return cstring_t(fmt.tprintf("Rotate%s %.1f deg %s | LMB confirm, RMB/Esc cancel", axis, ed.modal_angle * 57.2958, num))
	case .Scale:    return cstring_t(fmt.tprintf("Scale%s %.3fx %s | LMB confirm, RMB/Esc cancel", axis, ed.modal_scale, num))
	case .Inset:    return cstring_t("Inset face | Move mouse / LMB confirm")
	case .Loop_Cut: return cstring_t(fmt.tprintf("Loop Cut (%d cuts) | Wheel cuts, LMB apply, Esc cancel", ed.loop_cuts))
	case .Knife:    return cstring_t(fmt.tprintf("Knife (%d nodes) | LMB point, Enter/Space cut, Esc cancel", len(ed.knife_nodes)))
	case .Select, .Box, .Extrude, .Fill, .Merge:
	}
	return ""
}

@(private)
editor_pose_label :: proc(p: Pose_Preview_Kind) -> cstring {
	switch p {
	case .Rest:   return "Pose:Rest"
	case .Idle:   return "Pose:Idle"
	case .Walk:   return "Pose:Walk"
	case .Attack: return "Pose:Atk"
	}
	return "Pose:Rest"
}

@(private)
editor_team_label :: proc(t: Unit_Preview_Palette) -> cstring {
	switch t {
	case .Hero:   return "Hero"
	case .Player: return "Unit"
	case .Enemy:  return "Enemy"
	}
	return "Hero"
}

@(private)
cstring_t :: proc(s: string) -> cstring {
	return strings.clone_to_cstring(s, context.temp_allocator)
}
