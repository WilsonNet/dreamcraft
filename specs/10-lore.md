# DreamCraft Lore & Worldbuilding Specification

## 1. World Vision: The Shattered March of Al-Dor & The Gilded Wastes

DreamCraft takes place in **Al-Dor**, a frontier realm where three mythic and historical traditions converge:

1. **High Chivalric Fantasy (*The Lord of the Rings* Inspiration)**:
   - Ancient forest marches of towering pines and elder oaks, weather-worn octagonal oath-stones (**Waypoints**), watchtower beacons, forgotten elven/star-forged runic relics, and desperate last-stand fellowships holding the border against encroaching shadow.
2. **Tales of the Silk-Road & Desert Citadels (*Ali Baba / One Thousand and One Nights* Inspiration)**:
   - Sun-baked oasis sultanates, brass astrolabe observatories, djinn-sealed mountain treasure vaults (*"Open Sesame"* cavern gates), caravan merchant guilds, lapis-and-gold damask pavilions, and notorious forty-thieves brigand brotherhoods hiding inside the timber passes.
3. **Historical Medieval & Levantine Warriors**:
   - Grounded, authentic martial panoply drawn from history rather than oversized cartoon armor: **Mamluk *Faris* heavy cavalry and royal guards** (pointed *khud* steel nasal helms wrapped in silk *keffiyeh* turbans, riveted lamellar and mirror-plate cuirasses, bossed round *daraq* shields, and curved Damascus *shamshirs*), **Andalusian and Crusader frontier knights** (layered surcoats, mail hauberks, kite and round shields), and **Persian *Aswaran* cataphracts**.

> **Art & UI Law (`.agents/skills/art-direction/SKILL.md`):** Magic and ancient tech are heirloom craftsmanship, never a neon light show — thin brass conduits, a single glowing astrolabe lens, or a star-rune inlay etched into a Damascus blade.

---

## 2. The Three Major Factions (`Basic`, `Akana`, `Gorg`)

### 2.1 The Free Emirates & March-Wardens (`Basic` — Campaign Coalition)
- **Culture & Look**: A syncretic border alliance of Levantine **Mamluk Faris** captains and Western March-Wardens who guard the royal pilgrim and caravan roads between the Oasis Sultanates and the High Timber Marches.
- **Materials & Heraldry**: Warm Damascus steel (`#a4a8b0`), aged sovereign brass (`#b28c52`), royal cobalt and lapis lazuli cloth (`#405490`), linen under-tunics (`#c6ba9e`), and cured saddle leather (`#7c5434`).
- **Signature Doctrines**: Disciplined vanguard formations, mobile shield-and-shamshir melee, and oath-bound hero captains who inspire nearby retinues.

### 2.2 The Akana Star-Forge Covenant (`Akana`)
- **Culture & Look**: Scholar-knights, astrolabe artificers, and guardians of the sealed **Vaults of Qaf** — mountain treasuries locked by harmonic phrase-seals and star-runes (the historical reality behind the *Ali Baba* vault legends).
- **Materials & Heraldry**: Burnished gold-leaf filigree, deep celestial indigo and oasis emerald silk, and Damascus blades inlaid with glowing sun-brass conduits.
- **Signature Doctrines**: Precision reconnaissance, runic ward-stones, and high-craft weaponry.

### 2.3 The Gorg Iron-Horde & The Forty-Blades (`Gorg` & Rogue `Luk` Warbands)
- **Culture & Look**: A coalition of desert iron-raiders, mutinous frontier Mamluk levies, and the **Brotherhood of the Forty-Blades** — crimson-turbaned highwaymen who raid caravan vaults and ambush forest supply trails.
- **Materials & Heraldry**: Charred black-iron lamellar, carbuncle crimson and rust-red wraps, spiked brass bosses, and heavy cleaving sabers.
- **Signature Doctrines**: Ambush tactics from mist and timber cover, aggressive chase packs, and plunder raids.

---

## 3. Heroes & Units of Tutorial Level 1: *"Through the Woods"*

### 3.1 Campaign Hero: **Liiroy, the Bold** (`Unit_Kind.Hero`)
- **Title & Origin**: *Al-Faris al-Jari'* — First Captain of the Emir's Vanguard and Warden of the Western Road.
- **Role in Level 1**: Cut off from his caravan escort on the western edge of the **Whispering March** (`grid (2, 25)`), Liiroy must bear the Emir's Astrolabe Seal along the winding dirt trail through thirty dense pine-and-oak groves (`132` tree obstacle cells), rallying stranded Emirate **Vanguard Survivors** (`3` Luk Soldiers near Stone 1) and **Bridge Watch** (`2` Luk Soldiers near Stone 3), kindling the **Eight Octagonal Waypoint Stones** (`waypoints 0..7`, with Stone 3 shifted to `(40, 23)` around an elder oak root), and breaking three escalating Forty-Blades ambush bands (`2`, `3`, and `5` enemy Luk Soldiers) to reach the **Golden Banner Sanctuary** at the eastern pass (`grid x >= 77`).
- **Panoply & Stats**:
  - Heroic `5.36`-head athletic silhouette (`HERO_SCALE = 0.84`, 26-bone rig) clad in royal cobalt-and-gold silk, gilded *khud* helm with white plume, round brass-rimmed *daraq* shield, and star-inlaid shamshir.
  - `500 HP`, `35` melee damage, `5` lamellar armor, `40`-tick (`0.67 s`) attack cadence, `120` movement speed, and `+4 HP/s` heroic resolve regeneration.

### 3.2 Frontier Ambushers: **Luk Soldiers** (`Unit_Kind.Melee`)
- **Title & Origin**: Veteran deserters of Captain Luk's border garrison who joined the **Forty-Blades** brigand brotherhood, holding the central clearing of the Whispering March (`grid (50, 25)`).
- **The Code of the Challenge Horn (`ENEMY_AGGRO_DELAY_TICKS = 240` / `4.0 s`)**:
  - Even among the rogue Forty-Blades, ancient desert-and-chivalric custom demands a challenge before steel is crossed. When a Luk Soldier first sights Liiroy through the forest mist (`VISION_RADIUS = 6` cells), he sounds a brass horn warning — triggering the **Enemy Spotted** chronicle banner (*"A Luk Soldier spots Liiroy, the Bold!"* / *"Steel rings in the mist - Luk Soldier prepares to charge!"*) and a `4.0 s` golden-amber countdown ring (`! SPOTTED`) before charging. If struck first (`hp < hp_max`), the truce breaks immediately.
- **Panoply & Stats**:
  - Standard Mamluk infantry rig (`WARRIOR_SCALE = 0.74`) in crimson-and-iron cloth with curved shamshir and round shield.
  - `100 HP`, `15` melee damage, `0` armor, `60`-tick (`1.0 s`) attack cooldown, `105` movement speed.

---

## 4. How Lore Governs UI & Visual Craft (vinland-ui, `DESIGN.md`)

Every screen of the Operate UI (battlefield console, minimap, pause, F1 window, Model Picker and
Model Editor chrome) is dressed as the band of a Mamluk inlaid brass basin, the "Saint Louis
Basin" world: a Levantine object that carries both Frankish and Mamluk figures, which suits the
Al-Dor setting. `DESIGN.md` is the source of truth for tokens and components.

1. **Typography**: Cinzel (Roman inscriptional capitals) for names and titles, Cinzel Decorative
   for single-word display, Alegreya Sans for labels, values and buttons. Two sizes carry the HUD.
2. **Materials & Palette**: hammered brass housings and rivets over bitumen wells, silver
   interlace friezes, lapis enamel medallions for commands, carnelian for danger, and a pale
   gold inlay reserved for the armed command. A painted colour grade (desaturation, warm tint,
   grain, mottle) runs in the VUI shader and in `watercolor.fs`, so console and world share one
   palette.
3. **Ornament without emblems**: geometry comes from the basin itself (khatam stars, interlace,
   pointed arches, bevelled shoulders). Heraldic crosses and other militant emblems are not used
   as decoration; Stop is a plain bossed shield.
