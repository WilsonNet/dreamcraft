---
name: DreamCraft
description: Native Odin RTS and model editor dressed as the band of a Mamluk inlaid brass basin.
colors:
  bitumen: "#16130f"
  bitumen-raised: "#221c16"
  bitumen-deep: "#0c0a08"
  brass: "#9a7843"
  brass-hi: "#cdb37c"
  brass-lo: "#584222"
  inlay: "#ecd9a6"
  inlay-ink: "#2a1a08"
  plaque-light: "#e4d8bf"
  silver: "#b8bab8"
  silver-dim: "#8a8d8f"
  lapis: "#253c68"
  lapis-hi: "#324e86"
  lapis-lo: "#14213e"
  carnelian: "#74281d"
  carnelian-hi: "#a4473a"
  amber-alert: "#d49a44"
typography:
  display:
    fontFamily: "Cinzel"
    fontSize: "22px"
    fontWeight: 400
    lineHeight: 1
  dialog-title:
    fontFamily: "Cinzel"
    fontSize: "20px"
    fontWeight: 700
  decorative:
    fontFamily: "Cinzel Decorative"
    fontSize: "28px"
    fontWeight: 700
  title:
    fontFamily: "Cinzel"
    fontSize: "15px"
    fontWeight: 700
  body:
    fontFamily: "Alegreya Sans"
    fontSize: "13px"
    fontWeight: 700
  label:
    fontFamily: "Alegreya Sans"
    fontSize: "13px"
    fontWeight: 700
    letterSpacing: "0.12em"
  value:
    fontFamily: "Alegreya Sans"
    fontSize: "13px"
    fontWeight: 700
    fontFeature: "tnum"
  button:
    fontFamily: "Alegreya Sans"
    fontSize: "14px"
    fontWeight: 800
    letterSpacing: "0.1em"
  chip:
    fontFamily: "Alegreya Sans"
    fontSize: "12px"
    fontWeight: 700
    letterSpacing: "0.08em"
rounded:
  keycap: "3px"
  chip: "4px"
  plaque: "6px"
  well: "10px"
  prompt: "14px"
  panel: "16px"
  cartouche: "18px"
  housing-well: "35px"
  crest: "38px"
  housing-engraving: "41px"
  housing: "44px"
  crown: "120px"
  arch: "300px"
  full: "9999px"
spacing:
  rivet-inset: "3px"
  engraving-inset: "5px"
  plate: "10px"
  housing: "16px"
  chamfer-rivet: "19px"
  gap-sm: "8px"
  gap-md: "12px"
  gap-lg: "20px"
  frieze: "30px"
  console-band: "150px"
  housing-height: "196px"
components:
  plaque-inlay:
    backgroundColor: "{colors.inlay}"
    textColor: "{colors.inlay-ink}"
    typography: "{typography.button}"
    rounded: "{rounded.plaque}"
    height: "44px"
    padding: "0 16px"
  plaque-lapis:
    backgroundColor: "{colors.lapis}"
    textColor: "{colors.plaque-light}"
    typography: "{typography.button}"
    rounded: "{rounded.plaque}"
    height: "44px"
    padding: "0 16px"
  plaque-carnelian:
    backgroundColor: "{colors.carnelian}"
    textColor: "{colors.plaque-light}"
    typography: "{typography.button}"
    rounded: "{rounded.plaque}"
    height: "44px"
    padding: "0 16px"
  plaque-brass:
    backgroundColor: "{colors.bitumen-raised}"
    textColor: "{colors.plaque-light}"
    typography: "{typography.button}"
    rounded: "{rounded.plaque}"
    height: "44px"
    padding: "0 16px"
  chip:
    backgroundColor: "{colors.bitumen-raised}"
    textColor: "{colors.silver}"
    typography: "{typography.chip}"
    rounded: "{rounded.chip}"
    height: "28px"
    padding: "0 8px"
  chip-active:
    backgroundColor: "{colors.brass-hi}"
    textColor: "{colors.inlay-ink}"
    typography: "{typography.chip}"
    rounded: "{rounded.chip}"
    height: "28px"
    padding: "0 8px"
  keycap:
    backgroundColor: "{colors.bitumen-deep}"
    textColor: "{colors.brass-hi}"
    rounded: "{rounded.keycap}"
    padding: "1px 6px"
  medallion:
    backgroundColor: "{colors.lapis}"
    textColor: "{colors.silver}"
    rounded: "{rounded.full}"
    size: "58px"
  medallion-armed:
    backgroundColor: "{colors.inlay}"
    textColor: "{colors.inlay-ink}"
    rounded: "{rounded.full}"
    size: "58px"
  basin-panel:
    backgroundColor: "{colors.bitumen}"
    rounded: "{rounded.panel}"
    padding: "10px"
  console-housing:
    backgroundColor: "{colors.brass}"
    rounded: "{rounded.housing}"
    padding: "16px"
    height: "196px"
  command-prompt:
    backgroundColor: "{colors.bitumen}"
    textColor: "{colors.silver}"
    rounded: "{rounded.prompt}"
    padding: "6px 6px 0"
  portrait-dome:
    backgroundColor: "{colors.lapis}"
    rounded: "{rounded.full}"
    size: "112px"
---

# Design System: DreamCraft

## Overview

**Creative North Star: "The Saint Louis Basin"**

Every surface of DreamCraft is cut from one object: a Mamluk inlaid brass basin, the vessel later used to baptise French kings and so owned by both sides of the Crusades. The battlefield console is the basin's band. Panels, dialogs, the model picker and the editor chrome are fittings cast from the same metal. Leaving the battle for the pause menu or the editor never changes worlds: it is the same brass, the same bitumen, the same inlay.

The system is material, not flat. Hammered brass plates (a gradient from lit top to shaded foot, a hammered texture tiled at 96px, a lit inner top edge and a black outer seam) hold recessed bitumen wells. Engraved interlace and khatam star textures are cut into rims and fields at low opacity. Rivets sit at plate corners, and where a plate is chamfered a rivet sits on the cut. Plate, engraving and well of one fitting share one registered corner cut, so every layer follows the one outside it. Inside the wells, information is silver inlay: uppercase tracked labels and tabular figures. Lapis fills medallion fields and secondary actions; carnelian carries damage, danger and destructive actions. Gold inlay is reserved for one job: what is armed, selected or the next actionable target.

The HUD and the world share one painted grade. The VUI context runs `GRADE_PAINTED` (saturation 0.78, contrast 0.94, grain 0.06, mottle 0.16, warm tint 1.0/0.95/0.86). The watercolour post-shader applies the world half: a lighter saturation pull (0.84), a warm tint (1.0/0.96/0.88), an empty void that settles into warm bitumen (0.075/0.062/0.048) rather than cold blue-black, a darkening where the world tucks under the console (up to 42%, over 110px) and a lighter one under the top edge. HUD and battlefield read as one image.

**Key Characteristics:**
- One vessel: a single brass-and-bitumen material language across battle, pause, picker and editor.
- Gold inlay means "armed, selected or next"; nothing else is gold.
- Silver inlay for all reading text; tabular figures in every number.
- Every command is a round inlaid medallion with a visible keycap.
- Engraved interlace and khatam textures, never flat fills alone, on structural surfaces.
- Registered cuts: plate, engraving and well of one fitting share one corner geometry.
- UI and world share one warm, painted grade.

## Colors

A warm, low-key metalwork palette: black-brown ground, three brass tones, silver for reading, and three gem tones each holding a single meaning.

### Primary
- **Hammered Brass** (`brass`, with `brass-hi` and `brass-lo`): the body of every plate, rim, rivet, bezel and rule, and the colour of the stat icons. `brass-hi` is also the heading colour (Cinzel names, small caps headings) and keycap glyph colour; `brass-lo` is the divider, quiet ring and unlit oath-stone.
- **Gold Inlay** (`inlay`): the fill of an armed medallion, an active chip or tool, the selected picker row's title, the selected hero's portrait lip, the next oath-stone, and the one primary action of a dialog (Resume Battle, Edit model, Save, Save & exit).
- **Inlay Ink** (`inlay-ink`): text and icon mask colour on any gold-inlay fill. The build applies it as a literal, not a theme token.

### Secondary
- **Lapis** (`lapis`, `lapis-hi`, `lapis-lo`): medallion domes at rest, the hero portrait field, secondary dialog actions (Model Editor, Edit procedural, Game), help badges, the Patrol prompt dot, and the editor's modal status line.

### Tertiary
- **Carnelian** (`carnelian`, `carnelian-hi`): hit-point vials and nameplate bars, the Attack prompt dot, the charge banner star, destructive actions (Retry Level, Discard), editor error status, and "has fallen" text.
- **Alarm Amber** (`amber-alert`): the enemy challenge countdown only (the "Spotted" world tag, the challenge banner star, timer and bar). It is time pressure, not success.

### Neutral
- **Bitumen** (`bitumen`): the well and panel ground everywhere.
- **Raised Bitumen** (`bitumen-raised`): resting button and chip tops, editor bars, count tiles.
- **Deep Bitumen** (`bitumen-deep`): keycaps, list wells, tab troughs, empty vial channels, unlit stone sockets.
- **Silver Inlay** (`silver`): values, body copy, idle icons, resting chip labels.
- **Tarnished Silver** (`silver-dim`): secondary labels, captions, FPS, stat names, idle medallion labels, unselected picker rows.
- **Plaque Light** (`plaque-light`): the warm parchment-silver label on lapis, carnelian and brass plaques. Applied as a literal.

### Named Rules
**The One Gold Rule.** Gold inlay marks what is armed, selected, or the next actionable target, and the one primary action in a dialog. A gold fill anywhere else is a defect.

**The Gem Meaning Rule.** Lapis is secondary and calm, carnelian is damage, danger or destruction, amber is a running countdown. There is no green success tone and no verdigris.

## Typography

**Display Font:** Cinzel (variable, 400 and 700)
**Decorative Font:** Cinzel Decorative (400, 700), single words only
**Body Font:** Alegreya Sans (500, 700, 800), the VUI default font `game`

**Character:** An inscriptional Roman capital for names and titles, as if cut into the rim, set against a humanist sans that stays legible at 13px over a dark, textured ground.

### Hierarchy
- **Decorative** (Cinzel Decorative 700, 28px): a single word on an arch dialog ("Paused"). Never a phrase.
- **Display** (Cinzel 400, 22px, line-height 1): every name on the battlefield HUD: the level name in the top cartouche, the hero's name, the armed command verb, the challenge banner heading.
- **Dialog Title** (Cinzel 700, 20-22px): dialog and window titles (help window, unsaved changes, picker preview, Model Editor); the outcome arch rises to 24px.
- **Title** (Cinzel 700, 15px): section headings inside editor inspector cards and popups.
- **Body** (Alegreya Sans 700, 13-14px): hints, descriptions, dialog copy, help entries.
- **Label** (Alegreya Sans 700, 13px, 0.12em tracking, uppercase): every small heading on the HUD and in panels ("Whispering March", "The March", help group titles) in `brass-hi`, and stat names in `silver-dim`.
- **Value** (Alegreya Sans 700, 13px, tabular figures): every number: waypoint, fog, FPS, counts, timers; hero HP and stat values step to 800.
- **Button** (Alegreya Sans 800, 14px, 0.1em tracking, uppercase): plaque buttons. Medallion labels use 13px, 0.1em, uppercase, with a 1px black text shadow.
- **Chip** (Alegreya Sans 700, 12px, 0.08em, uppercase); editor tool rail labels drop to 11px.

### Named Rules
**The Two-Size HUD Rule.** On the battlefield HUD, text is 13px (labels, values, body) or 22px (Cinzel names and the challenge banner heading). Small headings take the 13px uppercase label, never a third size. Larger sizes live only in dialogs and the outcome arch; the editor's dense chrome may use 11-12px.

**The Tabular Rule.** Every number is set with tabular figures in a fixed position so it never jitters as it changes.

**The Single Word Rule.** Cinzel Decorative sets a single word only; Cinzel carries every multi-word title.

## Layout

The battlefield fills the screen above a full-width console band, 150px tall: a 30px cast frieze (an engraved interlace strip between two dark grooves, with a lit hairline under the lower groove) over a 120px bitumen field patterned with a faint khatam texture and ruled by paired silver and black hairlines 6-7px from each edge. Two raised housings (196px tall) rise out of the band at the corners: the minimap housing left (270px) and the command housing right (262px), each chamfered at its inner top corner and crowned by a small pointed crest tab that stands 26px above it. Between them the hero plate takes the remaining width; the march strip (200px) joins it at viewport widths of 1100px and up. The hero portrait dome breaks the band's top edge, backed by a pointed engraved crown arch seated on the frieze.

A brass cartouche hangs from the top centre, scooped at its lower corners, carrying the level name, waypoint, fog, FPS and Help. The armed-command prompt is a plate plaque seated on the frieze beside the portrait crown, over the hero column (448px from the left edge), so it reads as a fitting of the band rather than a floating toast. The challenge banner is a 560px basin panel 44px from the top, centred. Dialogs and the help window centre over a 60-65% black scrim; the help window widens from 600px to 900px when it has two shortcut groups.

The model picker is a centred basin panel up to 1000x640px, split 42% list and remainder preview. The editor wraps the viewport in four bars: top 44px, tool rail 88px, inspector 272px, status 28px, each separated from the viewport by a 2px `brass-lo` border. The editor compacts below 1400px and drops status hints below 1120px.

Spacing follows the metal: rivets sit 3-4px in from a plate's corner, engravings 4-5px, plates are 10px thick around wells (16px on the console housings), and content gaps step 4, 8, 12 and 20px.

## Elevation & Depth

Depth is physical and layered: plates sit above the world, wells are cut into plates, gems are domed out of wells. Shadows play three roles: drop shadows that lift plates off the battlefield, inset shadows that recess wells and shape domes, and a lit inner edge on plates and plaques that catches light from above. Rings and inset shadows follow the element's corner shape, so a bevelled or arched plate keeps its lit lip and dark seam on the cut. The world itself darkens under the console in the post-shader, so the band reads as sitting on the battlefield rather than pasted over it.

### Shadow Vocabulary
- **Plate lip** (`inset 0 2px 0 rgba(240,226,190,0.4)` with a 1px `black/85` ring): the lit top edge of every cast plate.
- **Well cut** (`inset 0 2px 5px rgba(0,0,0,0.7)`, 1px `black/90` ring, `0 0 0 2px rgba(205,179,124,0.4)` outer lip): every recessed bitumen well.
- **Panel lift** (`0 8px 24px rgba(0,0,0,0.7)`): floating basin panels.
- **Console lift** (`0 -8px 20px rgba(0,0,0,0.6)`; housings `±4px 0 10px rgba(0,0,0,0.6)`; prompt plaque `0 -4px 10px rgba(0,0,0,0.6)`): the band and its fittings over the world.
- **Medallion contact** (`0 3px 4px rgba(0,0,0,0.8)`): every medallion bezel. Armed adds a warm halo `0 0 14px rgba(205,179,124,0.35)`; the selected portrait a `0 0 16px rgba(236,217,166,0.3)` glow.
- **Dome shade** (`inset 0 -4px 6px rgba(0,0,0,0.6)`): the lower curve of a lapis dome; warmer on gold; `inset 0 -6px 12px rgba(0,0,0,0.55)` on the portrait.
- **Dome crescent** (`inset 0 3px 2px rgba(255,250,235,0.22)` over `inset 0 -3px 3px rgba(205,179,124,0.18)`): the specular highlight of a domed enamel is a lit crescent along its top, with a faint brass reflection at its foot.
- **Engraving** (text shadow `0 1px 0 rgba(0,0,0,0.9)`): brass and silver text sitting on metal.

### Named Rules
**The Cast, Cut, Domed Rule.** A surface is either a cast plate (lit lip, drop shadow), a well cut into a plate (inset shadow, brass outer lip), or a domed gem (radial fill, inset crescent highlight, lower shade). Never a flat card.

## Shapes

The vocabulary is roundels and basin fittings. Commands, portrait, rivets and minimap are round (the minimap stretches to a stadium because the march is an 80x50 grid and a circle would crop its ends). Panels nest radii 16, 13, 10px with scooped corners. Housings carry one chamfered inner shoulder whose three layers are registered on a single cut: plate 44px, engraving 41px, well 35px, following `r_in = r - d * (2 - sqrt(2))` for an inset of `d`; a rivet sits on the chamfer 19px in from the corner. Pointed arches (`corner-t-arch`) carry the tall shapes: the crest tabs on the housings (70x34px), the crown arch behind the portrait (146x110px, 120px radius, with an interlace engraving inset 5px), and the pause and outcome dialogs (260-300px radius over a 10-12px base). The cartouche scoops at the bottom; the command prompt bevels its top corners (14px plate, 10px well). Buttons are small bevelled plaques (6px), chips 4px, keycaps 3px. Engraved bands repeat interlace (rims, frieze, crown, heading rules) and khatam stars (console field, crest tabs, arch dialog field, oath-stones, banner icon).

### Named Rules
**The Registered Cut Rule.** Every layer of a fitting takes the same corner shape as the layer outside it, at a radius derived from its inset. A well that rounds where its plate is chamfered is a defect.

## Components

### Buttons (Plaque)
Bevelled cast plaques for menus and dialogs: firm, heavy, clearly pressable.
- **Shape:** 44px tall, bevelled 6px corners, 1px `brass` ring, a 1px white/25 inner lip.
- **Inlay (primary):** gold gradient from `inlay` through `brass-hi` to deep brass, `inlay-ink` text and icon. One per dialog.
- **Lapis (secondary), Carnelian (destructive), Brass (neutral or cancel):** gradient fills from their `-hi` tone down (brass is raised bitumen), `plaque-light` text, silver icon.
- **Content:** optional 20px icon mask, uppercase 14px label that grows, optional keycap at the right edge.
- **Hover / Active:** brightness 1.15 on hover, 0.9 when pressed.

### Chips
Small bevelled toggles for editor bars and secondary chrome.
- **Style:** 28px tall (24px in tight spots), 4px bevel, 1px ring; resting on a `bitumen-raised` gradient with a `brass-lo` ring and silver label.
- **State:** hover lifts the ring to `brass` and the label to `inlay`; active fills with gold (`brass-hi` to deep brass), `silver` ring, `inlay-ink` label and icon.

### Keycap
Every shortcut shown in the UI is a keycap: `bitumen-deep`, 3px bevel, 1px `brass-lo` ring, 11px extrabold `brass-hi` glyph. Medallions carry one at their lower right; plaques at their right edge; help rows in a fixed 150px column.

### Cards / Containers (Basin Panel)
- **Corner Style:** scooped, nested 16/13/10px.
- **Background:** hammered brass plate around a `bitumen` well.
- **Shadow Strategy:** Panel lift outside, Well cut inside (see Elevation & Depth).
- **Border:** an engraved interlace band inset 4px in the plate rim; four rivets at the corners.
- **Internal Padding:** plate 10px; well content 12-24px (20-24px for dialogs, 12px for the challenge banner, 8px for popups).
- Inside panels and the editor inspector, sub-cards are `bitumen-deep` wells with 8px bevelled corners, a `brass-lo/80` ring and a Cinzel 15px title.

### Console Housing
A raised plate (196px) rising out of the band at each corner: hammered brass, 16px thick around a bitumen well, its inner top corner chamfered on the registered 44/41/35px cut with an interlace engraving between plate and well. Three rivets sit at the outer corners and a fourth on the chamfer. A pointed crest tab carrying a khatam star stands on its top edge.

### Navigation (Picker tabs and list)
Tabs are a row of chips in a `bitumen-deep` trough. List rows are 40px, bevelled 5px; the selected row fades from `brass-lo/70` into `bitumen-raised` with a `brass-hi` ring and an `inlay` title, others are `silver-dim` with a `bitumen-raised` hover.

### Command Medallion (signature)
A round domed lapis enamel (58px) in a cast brass bezel, with an inset crescent highlight, a silver icon mask, a keycap at its lower right and an uppercase label beneath. Six sit in a 3x2 grid in the command housing: Move (chevrons), Attack (crossed sword and shamshir), Patrol (pennons), Stop (heater shield with a plain boss), Follow or Free (nasal helm), Menu (order scroll).
- **Idle:** lapis dome, silver icon, `silver-dim` label; hover warms the bezel and turns the icon to `inlay`.
- **On (engaged toggle):** lapis dome ringed 2px inside in `brass-hi`, `brass-hi` label.
- **Armed (waiting for a click):** the dome fills with gold inlay, the icon turns to ink, a warm halo plus a pulsing `brass-hi/70` ring 5px outside.
- **Disabled:** dull brass bezel, dark dome, 45% opacity.

### Command Prompt
When a command is armed, a plate plaque seated on the frieze beside the portrait crown carries a coloured dot (`brass-hi` Move, `carnelian-hi` Attack, `lapis-hi` Patrol), the verb in Cinzel 22px, the hint in silver and the cancel hint in tarnished silver, all inside a bitumen well with bevelled top corners.

### Hero Plate and Portrait
The portrait is a 112px lapis dome showing the hero's live mesh, inside a 2px lip (silver at rest, gold inlay when the hero is selected) and a 7px cast collar, with a rivet at its crown. Behind it stands the pointed crown arch. Beside it: the name in Cinzel 22px with the rank in tarnished silver, the hit-point vial, and a stat row of Attack, Armour and Regen, each a 16px `brass` icon (sword, shield, heart), a `silver-dim` label and an 800-weight silver value. When the hero falls the portrait greys to 50% and a carnelian "has fallen" label replaces the vial.

### Hit-Point Vial
A 12px glass vial of carnelian (gradient `carnelian-hi` to near-black red) in a 22px rounded brass channel, with a white/15 glint and black quarter ticks. At 25% or less it pulses. The value sits beside it in tabular figures. World nameplates repeat it at 46x7px (hero) or 32x6px (enemy) in `bitumen-deep` channels.

### March Strip
Eight khatam oath-stones in a 4-column grid inside a well: kindled stones `brass-hi`, the next stone `inlay` in a ring of `brass-hi` with a warm glow, the rest `brass-lo/60` in recessed sockets.

## Do's and Don'ts

### Do:
- **Do** build every new surface from the plate, well and rivet set: hammered brass around a bitumen well, nested radii, an engraved band in the rim.
- **Do** register every cut: when a plate is chamfered or arched, its engraving and well take the same corner shape at radii derived from the inset.
- **Do** reserve gold inlay (`inlay`) for the armed command, the selected item, the next target and the one primary action in a dialog.
- **Do** set every number with tabular figures at 13px on the battlefield HUD.
- **Do** show the hotkey of every command as a keycap on the control itself.
- **Do** keep reading text silver (`silver`, `silver-dim`), names Cinzel in `brass-hi`, and small headings in the 13px uppercase label.
- **Do** use lapis for secondary actions, carnelian for damage and destructive actions, amber only for a running countdown.
- **Do** seat transient HUD plaques on the console (frieze, housing) rather than floating them over the world.
- **Do** keep the HUD on the painted grade (`GRADE_PAINTED`) so it matches the watercolour world.

### Don't:
- **Don't** float detached tool-panel islands over the battlefield; the console is one band with cast housings.
- **Don't** add a green success tone or a verdigris accent.
- **Don't** put gold on a resting control, a decoration or a second dialog action.
- **Don't** set phrases in Cinzel Decorative; it takes one word.
- **Don't** use proportional figures for a value that changes during play.
- **Don't** render a command as a square button; commands are round medallions.
