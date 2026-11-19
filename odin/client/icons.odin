// Runtime SVG icon loader and HiDPI GPU texture atlas using package svg.
package main

import "core:os"
import "core:strings"
import rl "vendor:raylib"
import svg "./svg"

ICON_TEX_PX :: 48

Icon_Id :: enum u8 {
	None,
	Tool_Select,
	Tool_Box,
	Tool_Grab,
	Tool_Rotate,
	Tool_Scale,
	Tool_Extrude,
	Tool_Inset,
	Tool_Loop_Cut,
	Tool_Knife,
	Tool_Fill,
	Tool_Merge,
	Tool_Delete,
	Mode_Vert,
	Mode_Edge,
	Mode_Face,
	Undo,
	Redo,
	Mirror_X,
	Wireframe,
	XRay,
	Floor_Y,
	Pose,
	Team_Palette,
	Shader_WC,
	Models,
	Reset,
	Save,
	Game,
	Cmd_Move,
	Cmd_Attack,
	Cmd_Patrol,
	Cmd_Stop,
	Hero_Crest,
	Enemy_Alert,
	Cat_Units,
	Cat_Trees,
	Cat_Props,
	COUNT,
}

@(private)
Icon_Spec :: struct {
	file:     string,
	embedded: string,
}

@(private)
ICON_SPECS := [Icon_Id]Icon_Spec{
	.None          = {},
	.Tool_Select   = {"tool_select.svg",   #load("../assets/icons/tool_select.svg", string)},
	.Tool_Box      = {"tool_box.svg",      #load("../assets/icons/tool_box.svg", string)},
	.Tool_Grab     = {"tool_grab.svg",     #load("../assets/icons/tool_grab.svg", string)},
	.Tool_Rotate   = {"tool_rotate.svg",   #load("../assets/icons/tool_rotate.svg", string)},
	.Tool_Scale    = {"tool_scale.svg",    #load("../assets/icons/tool_scale.svg", string)},
	.Tool_Extrude  = {"tool_extrude.svg",  #load("../assets/icons/tool_extrude.svg", string)},
	.Tool_Inset    = {"tool_inset.svg",    #load("../assets/icons/tool_inset.svg", string)},
	.Tool_Loop_Cut = {"tool_loop_cut.svg", #load("../assets/icons/tool_loop_cut.svg", string)},
	.Tool_Knife    = {"tool_knife.svg",    #load("../assets/icons/tool_knife.svg", string)},
	.Tool_Fill     = {"tool_fill.svg",     #load("../assets/icons/tool_fill.svg", string)},
	.Tool_Merge    = {"tool_merge.svg",    #load("../assets/icons/tool_merge.svg", string)},
	.Tool_Delete   = {"tool_delete.svg",   #load("../assets/icons/tool_delete.svg", string)},
	.Mode_Vert     = {"mode_vert.svg",     #load("../assets/icons/mode_vert.svg", string)},
	.Mode_Edge     = {"mode_edge.svg",     #load("../assets/icons/mode_edge.svg", string)},
	.Mode_Face     = {"mode_face.svg",     #load("../assets/icons/mode_face.svg", string)},
	.Undo          = {"undo.svg",          #load("../assets/icons/undo.svg", string)},
	.Redo          = {"redo.svg",          #load("../assets/icons/redo.svg", string)},
	.Mirror_X      = {"mirror_x.svg",      #load("../assets/icons/mirror_x.svg", string)},
	.Wireframe     = {"wireframe.svg",     #load("../assets/icons/wireframe.svg", string)},
	.XRay          = {"xray.svg",          #load("../assets/icons/xray.svg", string)},
	.Floor_Y       = {"floor_y.svg",       #load("../assets/icons/floor_y.svg", string)},
	.Pose          = {"pose.svg",          #load("../assets/icons/pose.svg", string)},
	.Team_Palette  = {"team_palette.svg",  #load("../assets/icons/team_palette.svg", string)},
	.Shader_WC     = {"shader_wc.svg",     #load("../assets/icons/shader_wc.svg", string)},
	.Models        = {"models.svg",        #load("../assets/icons/models.svg", string)},
	.Reset         = {"reset.svg",         #load("../assets/icons/reset.svg", string)},
	.Save          = {"save.svg",          #load("../assets/icons/save.svg", string)},
	.Game          = {"game.svg",          #load("../assets/icons/game.svg", string)},
	.Cmd_Move      = {"cmd_move.svg",      #load("../assets/icons/cmd_move.svg", string)},
	.Cmd_Attack    = {"cmd_attack.svg",    #load("../assets/icons/cmd_attack.svg", string)},
	.Cmd_Patrol    = {"cmd_patrol.svg",    #load("../assets/icons/cmd_patrol.svg", string)},
	.Cmd_Stop      = {"cmd_stop.svg",      #load("../assets/icons/cmd_stop.svg", string)},
	.Hero_Crest    = {"hero_crest.svg",    #load("../assets/icons/hero_crest.svg", string)},
	.Enemy_Alert   = {"enemy_alert.svg",   #load("../assets/icons/enemy_alert.svg", string)},
	.Cat_Units     = {"cat_units.svg",     #load("../assets/icons/cat_units.svg", string)},
	.Cat_Trees     = {"cat_trees.svg",     #load("../assets/icons/cat_trees.svg", string)},
	.Cat_Props     = {"cat_props.svg",     #load("../assets/icons/cat_props.svg", string)},
	.COUNT         = {},
}

Icon_Atlas :: struct {
	textures: [Icon_Id]rl.Texture2D,
	ready:    bool,
}

init_icons :: proc() {
	if app.icons.ready {
		unload_icons()
	}
	for id_int in 1..<int(Icon_Id.COUNT) {
		id := Icon_Id(id_int)
		app.icons.textures[id] = upload_svg_icon(ICON_SPECS[id])
	}
	app.icons.ready = true
}

unload_icons :: proc() {
	for id_int in 1..<int(Icon_Id.COUNT) {
		id := Icon_Id(id_int)
		tex := app.icons.textures[id]
		if tex.id > 0 {
			rl.UnloadTexture(tex)
			app.icons.textures[id] = {}
		}
	}
	app.icons.ready = false
}

draw_icon_centered :: proc(id: Icon_Id, cx, cy, size: f32, tint := rl.WHITE) {
	if id == .None || id == .COUNT {
		return
	}
	tex := app.icons.textures[id]
	if tex.id == 0 {
		return
	}
	src := rl.Rectangle{0, 0, f32(tex.width), f32(tex.height)}
	dst := rl.Rectangle{cx - size * 0.5, cy - size * 0.5, size, size}
	rl.DrawTexturePro(tex, src, dst, {0, 0}, 0, tint)
}

@(private)
upload_svg_icon :: proc(spec: Icon_Spec) -> rl.Texture2D {
	src, owned := load_svg_source(spec)
	defer if owned { delete(src) }
	if len(src) == 0 {
		return {}
	}
	doc, ok := svg.parse_svg(src)
	defer svg.document_delete(&doc)
	if !ok {
		return {}
	}
	rgba := svg.render_svg_rgba(&doc, ICON_TEX_PX, ICON_TEX_PX, {236, 240, 232, 255})
	defer delete(rgba)
	if len(rgba) != ICON_TEX_PX * ICON_TEX_PX * 4 {
		return {}
	}
	img := rl.Image{
		data    = raw_data(rgba),
		width   = ICON_TEX_PX,
		height  = ICON_TEX_PX,
		mipmaps = 1,
		format  = .UNCOMPRESSED_R8G8B8A8,
	}
	tex := rl.LoadTextureFromImage(img)
	rl.SetTextureFilter(tex, .BILINEAR)
	return tex
}

@(private)
load_svg_source :: proc(spec: Icon_Spec) -> (string, bool) {
	if len(spec.file) > 0 {
		prefixes := [2]string{"assets/icons/", "odin/assets/icons/"}
		for prefix in prefixes {
			path := strings.concatenate({prefix, spec.file}, context.temp_allocator)
			if os.exists(path) {
				if data, err := os.read_entire_file(path, context.allocator); err == nil {
					return string(data), true
				}
			}
		}
	}
	return spec.embedded, false
}
