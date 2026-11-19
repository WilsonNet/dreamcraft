# Surface Brief: In-Game Model Editor

- **Target**: `odin/client/` (`Pause Menu -> Model Picker -> 3D Model Editor -> Save -> Resume Game`)
- **Mode**: `Operate`

## Direction contract

- **THESIS**: Keep the full 3D mesh viewport unobstructed inside a disciplined dark-woodland studio frame so Blender-fluent Edit Mode shortcuts (`1/2/3`, `G/R/S+X/Y/Z`, `E`, `I`, `Ctrl+R`, `K`, `F`, `X`, `M`, `Ctrl+Z`, `Ctrl+S`) drive direct mesh tuning without external tools.
- **OWN-WORLD**: Extend DreamCraft's native obsidian-forest panel shell (`#0d130e`), muted sage `1px` rules (`#3a5a3c`), ivory parchment text (`#dce2d5`), and burnished brass/gold active selection highlights (`#ebd778`), paired with universal `R/G/B = X/Y/Z` spatial gizmo cues and live `1x1` RTS ground cell scale guides.
- **STORY**: Press `Esc` during battle -> select `Model Editor` -> preview and choose a unit, tree, or prop -> shape vertices/edges/faces, materials (`Mat_Kind`), and rigid bones (`Bone_Id`) -> hit `Save` (`Ctrl+S`) to write git-friendly `.odin` modules and hot-swap live GPU meshes -> click `Resume Game` and see it immediately on the battlefield.
- **FIRST VIEWPORT**: Top header bar (`44px`: Resume, Model switcher pill, Vert/Edge/Face `1/2/3` pills, Wire/X-Ray, X-Mirror, Pose, Team palette, Shader toggle, Reload, primary `Save -> Game`), left vertical tool rail (`72px`: Select, Box, Grab, Rot, Scale, Extrude, Inset, Loop Cut, Knife, Fill, Merge, Delete), right inspector rail (`264px`: Selection transform + Snap Ground, `Mat_Kind` swatch grid, `Bone_Id` list + pose playback, Odin manifest path), center `>75%` 3D stage, bottom `28px` live modal delta / Blender shortcut bar.
- **FORM**: Dual-rail Workbench Studio around 3D stage (Desktop Operate position `1`), `seed:61b5aa4ba616d554`.
- **FINISH**: Complete visual capture & interaction test across Pause Menu, Model Picker turntable, Edit Mode tools + live Save -> Resume hot-reload.
