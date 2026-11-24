---
version: 1
slug: "odin-client-render-hud-odin"
primary_target: "odin/client/hud_basin.odin"
related_targets: ["odin/client/editor_vui.odin","odin/client/vui_host.odin","odin/client/ui_app.odin"]
---

# Surface: DreamCraft in-game UI (Battlefield HUD, Pause, Model Picker, Model Editor, Shortcut window)

Mode: Operate. Built with vinland-ui (VUI) embedded in the raylib client; renderer moves to SDL3 GPU (Metal/Vulkan) in a later phase.

Audience & job: the solo creator-player. Command Liiroy through the Whispering March (move / attack-move / patrol / stop, minimap scrub, camera follow), pause, and drop into the Model Editor to edit meshes with Blender shortcuts, then resume.
Constraints: Blender shortcuts unchanged; control API commands keep working; HUD costs at most one draw batch per texture and must never steal world clicks outside its own shapes; 60 fps budget belongs to the world.
Decisions from the user: HUD first on raylib, then renderer port; Battlefield HUD is a full-width bottom console (AoE/WC3); editor layout free to change.

## Direction contract

THESIS: The console is the band of a Mamluk inlaid brass basin, the vessel later used to baptise French kings: one object owned by both sides of the Crusades. It refuses the floating-island tool-panel HUD and the generic carved-oak RTS console.

OWN-WORLD: Bitumen-black ground (#16130f) inside hammered brass rims (#b08a4a, highlight #e3c98a, shadow #6e5428); silver inlay (#cfd3d6) for rules and secondary marks; lapis (#2b4a8c) medallion fields; carnelian (#8f2f22) for damage and danger. Engraved arabesque and knotwork bands as procedural textures; heading voice is an inscriptional capital face, body a humanist sans with tabular figures. Gold inlay appears only on what is actionable-now or selected.

Primary dialog actions use a gold-inlay plaque (Resume, Edit model, Save); lapis for secondary, carnelian for destructive. No green success tone.

STORY: The player reads Liiroy's state at a glance (HP, ATK, ARM, waypoint, regen), sees the march on the minimap roundel, and fires commands from inlaid medallions with visible hotkeys. Pause and editor live in the same vessel language, so leaving the battle never changes worlds.

FIRST VIEWPORT: Battlefield fills the top ~78%. A full-width bottom band (≈210px at 1440×900) with a brass rim and an engraved frieze running its top edge. Left: minimap as an elongated engraved roundel (stadium cartouche, brass + silver rings); adaptation: the march is an 80x50 grid and a circle would crop the start and the goal at its ends. Center: hero portrait roundel, name in inscriptional caps, carnelian HP bar in a brass channel, stat row in tabular figures. Centre-right: the march strip, eight khatam oath-stones (kindled brass, next stone gold inlay). Right: command medallions (Move, Attack, Patrol, Stop, Follow, Menu) with keycaps; the armed command is filled with gold inlay. Top center: a thin brass cartouche with level name, waypoint, fog, FPS.

FORM: Impeccable's pick, "Saint Louis Basin" (my rank 1 of 7; roll assigned rank 5), seed:4ec4ccf3685bf2c2.
Raised disciplines kept from declined challengers: gold inlay reserved for one job, actionable or selected (Terminal Yellow Wayfinding); a two-size HUD type ladder (Timetable Slide Rack); tabular figures in fixed cells for every number (Datamatics); picker focus lifts while the rest dims (Streaming Title Wall); turntables at one fixed scale on a shared ground line (Botanical Folio).
Signature move: every control is an inlaid medallion; arming it fills the medallion with gold inlay.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
