# DreamCraft Design System (`odin/ui/`)

DreamCraft's native UI is a standalone, zero-dependency Odin declarative reactive UI framework (`odin/ui/`, see [`specs/09-ui-framework.md`](specs/09-ui-framework.md)) styled after the **Al-Dor Chivalric × Levantine** world ([`specs/10-lore.md`](specs/10-lore.md): *The Lord of the Rings* mythic chivalry × *Ali Baba / One Thousand and One Nights* brass filigree & lapis silk × *Historical Mamluk / Crusader Warriors*). It combines **Quickshell** floating islands and beveled rims, **Jetpack Compose** builders and value `Mod` modifiers, **Flutter** single-pass `BoxConstraints` layout and `Display_List` rendering, and **Elm / Iced** unidirectional `UI_Msg` dispatch.

---

## 1. Architecture (`odin/ui/` + `odin/client/ui_app.odin`)

| Stage | Module(s) | Responsibility |
|-------|-----------|----------------|
| **Declarative Tree & Modifiers** | `types.odin`, `builder.odin`, `widgets.odin` | Compose-style `open_*`/`close` containers, `ornament_divider`, leaf widgets, and chainable value `Mod` builders (`m_size`, `m_fill`, `m_weight`, `m_pad*`, `m_gap`, `m_surface`, `m_click`, `m_blocks`, `m_layer`). |
| **Single-Pass Layout** | `layout.odin` | Flutter `BoxConstraints` `measure_node` -> `place_node` solver for `.Root`, `.Box`, `.Row`, `.Column`, weighted `.Spacer`, `.Text`, `.Icon`, `.Clipped_Tex`, `.Progress`, and `.Divider`. |
| **Elm Dispatch & Memory** | `hit.odin`, `memory.odin`, `ui_app.odin` | Reverse z-layer hit testing (`collect_hits` / `find_top_hit`), pointer blocking (`blocks_pointer`), typed `UI_Event` / `UI_Msg` queue (`MAX_UI_EVENTS = 64`), and fixed open-addressed `[512]Widget_Slot` table driving hover, press, active, appear, and InkWell ripple springs. |
| **Display List & GPU Render** | `display_list.odin`, `render.odin`, `font.odin` | Z-sorted `0..<MAX_LAYERS` (`4`) `Draw_Cmd` compilation (`build_display_list`) with HiDPI scissor push/pop (`begin_hi_dpi_scissor`), 1-draw-call OpenGL 330 SDF batching, and `--no-shader` fallback. |

---

## 2. Arab / European Medieval Visual Tokens (`odin/ui/theme.odin`)

- **Surfaces**: Torchlit Damascus obsidian, oiled walnut, and recessed velvet-slate grounds (`COL_SURFACE_0 = #110e0c`, `COL_SURFACE_1 = #191511`, `COL_SURFACE_2 = #231d17`, `COL_SURFACE_3 = #2e261e`, recessed `COL_SURFACE_WELL = #0c0a08`, modal backdrop `COL_SCRIM`).
- **Architectural Radii**: `RAD_XS` (`4`), `RAD_SM` (`6`), `RAD_MD` (`8`), `RAD_LG` (`12`), `RAD_XL` (`14`), and capsule `rad_pill()`.
- **Borders & Typography Hierarchy**:
  - Borders: Burnished Sovereign Brass (`COL_BORDER_SUBTLE`, `COL_BORDER_DEFAULT`, `COL_BORDER_HOVER`, `COL_BORDER_GOLD`), Oasis Emerald (`COL_BORDER_PRIMARY`), and Carbuncle Crimson (`COL_BORDER_DANGER`).
  - Text: Illuminated Vellum Parchment (`COL_TEXT_PRIMARY = #f8f1e4`, `COL_TEXT_SECONDARY = #daccb4`, `COL_TEXT_MUTED = #ac9c84`, `COL_TEXT_GOLD = #f8d87c`, `COL_TEXT_ACTIVE = #fffaea`) and RTS semantic gem tones (`COL_TEXT_MOVE`, `COL_TEXT_ATTACK`, `COL_TEXT_PATROL`, `COL_TEXT_DANGER`).
- **Surface Factories**: `style_island`, `style_modal`, `style_card`, `style_well`, `style_bar`, `style_pill_track`, `style_keycap`, `style_swatch`, `style_progress`.
- **High-Level Widgets (`widgets.odin`, `builder.odin`)**:
  - `button` (`Button_Opts`): 8 `Button_Variant` styles (`Secondary` tooled leather & brass, `Primary` oasis emerald & gold, `Tonal` royal lapis lazuli & Damascus steel, `Ghost`, `Danger` carbuncle crimson, `Tool`, `Compact`, `Bone`), optional SVG icon, hover/press/active transitions, InkWell ripple, and right-aligned (`fill_w`/`width`/`weight`) or compact inline `keycap`.
  - `badge` (`Badge_Tone`: `Neutral`, `Gold`, `Emerald`, `Crimson`, `Cyan`, `Amber`), `keycap`, `segmented_tab`, `swatch`, `progress_bar`, `ornament_divider`, `draw_raw_bar`, and `draw_raw_pill`.

---

## 3. GPU Rendering, Smooth Font Engine & Icons

- **1-Draw-Call SDF Batcher & Medieval Filigree (`assets/shaders/ui_sdf.{vs,fs}`)**:
  - Packs up to `MAX_DRAW_CMDS` (`512`) `.SDF_Box` commands into a `512×8` RGBA8 `POINT`-filtered parameter texture (`texelFetch`) per batch, passing each quad's slot index in `vertexPosition.z` and local pixel coordinates in `vertexTexCoord` (rebinding `data_tex.id` on `rlgl.CheckRenderBatchLimit`).
  - Evaluates analytical 4-corner rounded SDFs (`sd_rounded_box`), Retina-safe border AA (`max(fwidth(d), 0.45)`), soft outer shadow, **torchlit gold-leaf top specular rim**, **inner antique-brass filigree double-rule** (`2.6px` inset), **45° Mamluk/Elven corner diamond studs**, InkWell click ripple, and rounded progress fill in a single pass.
- **Rounded Viewport Clip (`assets/shaders/ui_clip_tex.fs`)**:
  - Renders `ui.clipped_texture` panels such as the battlefield minimap (`minimap.odin`) and Model Picker 3D turntable (`editor_picker.odin`) with Y-flip support, rounded border, and specular top rim.
- **Exact-Pixel Baked, sRGB-Gamma-Corrected Font Engine (`odin/ui/font.odin`, `odin/assets/fonts/`)**:
  - Embeds static SIL-OFL `ChronicleSerif-Bold.ttf` (`.Heading` chivalric display serif), `Lato-Regular.ttf` (`.Body`/`.Label` plus morphological horizontal stem-boldened `.Sans_Bold` for `.Medium`/`.Bold`), `SourceCodePro-Regular.ttf` (`.Mono`), and `SourceCodePro-Bold.ttf` (`.Mono_Bold`).
  - Bakes every face across a 7-step discrete physical-pixel ladder (`FONT_STEP_PX = {11, 12, 13, 14, 16, 18, 24}` × `dpi_scale`) so `scaleFactor == 1.0 / dpi_scale` (**1:1 texel-to-physical-pixel mapping**, zero downsampling distortion).
  - Post-processes each atlas in `smooth_atlas_pixels` to normalize all pixels to pure-white `RGB = (255,255,255)` (eliminating dark `(0,0,0,0)` bilinear halos) and apply perceptual sRGB dark-surface coverage gamma (`pow(val, 0.62..0.70)`).
  - Uses integer character spacing (`0.0` for body/mono, `1.0` for `>= 16px` headings), physical-pixel origin snapping, and a 1px `(0, +1)` dark obsidian ink drop-shadow.
- **Vector Icon Atlas (`client/icons.odin`, `client/svg/`, `odin/assets/icons/`)**:
  - Renders all 37 `.svg` icons via 4×4 SSAA (`ICON_TEX_PX = 96`) in pure white `currentColor` with transparent RGB bleed dilation, mipmaps, `.TRILINEAR` filtering, and runtime tinting.
