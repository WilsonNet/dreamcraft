# DreamCraft - Fantasy RTS Tech Stack

Spiritual successor to StarCraft: Brood War, built for the modern web.

## Skills Map

Skills are located in `.opencode/skills/` and `.claude/skills/` and provide specialized instructions:

| Skill | Purpose |
|-------|---------|
| **bevy** | Bevy ECS patterns, common errors, UI patterns, WASM setup, debug console |
| **tmux** | Terminal multiplexing, session management, troubleshooting |
| **specs** | Keeping `specs/` folder updated with new features |

### Skill Update Rule (IMPORTANT!)
After completing ANY task, update relevant skills if:
- You discovered a new pattern or error fix
- You learned something not in the skill
- A skill is missing information that would have helped

Example: Fixed a Bevy UI error? -> Update `.opencode/skills/bevy/SKILL.md` with the fix.

## Core Architecture

### Logic (The Brain)
- **Language**: Rust
- **Target**: WebAssembly (WASM)
- **ECS Framework**: Bevy 0.18
- **Math**: `fixed` crate for deterministic floating-point (essential for RTS synchronization)

### Networking (The Nerve)
- **Client-Server**: WebTransport
- **P2P LAN**: WebRTC DataChannels
- **Rationale**: Bypass WebSocket latency for competitive RTS gameplay

### Graphics (The Eyes)
- **API**: WebGPU (via Bevy)
- **Standard**: 2026 high-performance browser rendering
- **Features**: Custom shaders for fantasy "ambient" skill effects

### UI
- **Framework**: React 19 (loaded from CDN in trunk-served page)
- **Console**: Agent Console overlay (React) — toggled with backtick key
- **Minimap**: React canvas component, StarCraft-style bottom-left

### Bevy <-> React Interop
Game state flows through `localStorage`:
- **Bevy -> React**: `dreamcraft_debug_state` (JSON, updated every 30 frames)
- **Bevy -> React**: `dreamcraft_minimap` (compact text grid, updated every 30 frames)
- **React -> Bevy**: `dreamcraft_command` (JSON command, consumed by `read_console_commands` system)
- **Bevy -> React**: `dreamcraft_command_result` (JSON response)

This allows headless control via Playwright (`window.dreamcraftConsole` API).

## Project Structure

```
dreamcraft/
├── CLAUDE.md              # This file
├── Trunk.toml             # Trunk WASM bundler config
├── Cargo.toml             # Rust configuration
├── .cargo/config.toml     # Cargo config (mold linker)
├── index.html             # HTML entry for Trunk (game + React console + minimap)
├── reference.jpg          # StarCraft Brood War UI reference
├── bevy-docs/             # Bevy engine source for reference
├── specs/                 # Game specifications
├── .opencode/skills/      # Specialized skills (ALWAYS KEEP UPDATED!)
├── .claude/skills/        # Claude Code skills (mirrors .opencode/skills/)
├── src/
│   ├── main.rs           # Native entry point
│   ├── lib.rs            # Game plugin & ECS (all game logic)
│   └── web.rs            # WASM entry point (minimal, just starts Bevy app)
└── web/                   # Legacy Bun-based UI (not actively used)
    ├── src/
    │   ├── App.tsx       # Old console app
    │   └── ConsoleApp.tsx # Old console with localStorage sync
    └── package.json
```

## Development Setup

### Prerequisites
- Rust (stable) with `wasm32-unknown-unknown` target
- Trunk WASM bundler
- Mold linker (installed)
- Clang (installed)
- Bun (for web/React — legacy, not needed for main dev flow)

### Install Tools
```bash
# Install trunk
cargo install cargo-binstall
cargo binstall trunk -y

# Install mold linker (already on system)
# Already installed via: sudo pacman -S mold clang
```

### Development Commands

#### WASM (Browser) — PRIMARY WORKFLOW
```bash
# Start dev server (runs on http://localhost:8080)
# This serves the game + React console + minimap, all on one page
/home/wilsonn/.asdf/installs/rust/stable/bin/trunk serve

# Or build only
/home/wilsonn/.asdf/installs/rust/stable/bin/trunk build

# Force rebuild after editing lib.rs (touch to invalidate cache)
touch src/lib.rs && /home/wilsonn/.asdf/installs/rust/stable/bin/trunk build
```

#### Native (Desktop Testing)
```bash
# NOTE: Native build currently broken (lib.rs uses wasm-only extern blocks)
# Use WASM build for all development
cargo run --features bevy/dynamic_linking
```

#### tmux Setup
```bash
tmux new-session -d -s dreamcraft -n trunk -c /path/to/dreamcraft
tmux send-keys -t dreamcraft:trunk '/home/wilsonn/.asdf/installs/rust/stable/bin/trunk serve' Enter
```

### Cargo Configuration (.cargo/config.toml)
```toml
[target.x86_64-unknown-linux-gnu]
linker = "clang"
rustflags = ["-C", "link-arg=-fuse-ld=/usr/bin/mold"]

[profile.dev]
opt-level = 1

[profile.dev.package."*"]
opt-level = 3

[profile.release]
codegen-units = 1
lto = "thin"
```

## Specs

Detailed game specifications are in `specs/`:

| Spec | Description |
|------|-------------|
| `specs/01-overview.md` | Game vision, features, implementation status, architecture |
| `specs/02-units.md` | Unit types, stats, abilities |
| `specs/03-isometric.md` | Grid rendering, coordinate systems |
| `specs/04-input.md` | Control schemes, input handling |
| `specs/05-networking.md` | Multiplayer architecture, sync protocols |
| `specs/06-agent-console.md` | Agent Console commands, diagnostics, headless API |
| `specs/07-minimap.md` | StarCraft-style minimap implementation |

Always check and update relevant specs after implementing features (see specs skill).

## Game Features (Tutorial Level 1)

### Implemented
- [x] 80x50 grid map with A* pathfinding
- [x] Player unit (blue circle) with right-click movement
- [x] Fog of war (cells revealed as player explores)
- [x] 8 waypoints through the map
- [x] Goal zone (right edge) — level complete when reached
- [x] Tree obstacles (30 clusters, 132 cells)
- [x] Camera pan (WASD/Arrow keys)
- [x] Context menu suppressed (no right-click browser menu)
- [x] StarCraft-style minimap (React canvas, bottom-left)
- [x] Agent Console (React overlay, backtick toggle)
- [x] Headless game control via localStorage + Playwright

### Known Issues
- Waypoint 3 at (40,20) collides with tree cluster — pathfinding skips it
- Camera doesn't auto-follow player (must pan manually or use console `goto`)
- Native build broken (wasm-only extern blocks in lib.rs need cfg guards)

## Agent Console

Toggle with backtick (`` ` ``). Commands:
- `status` — Full game state with diagnostics (player visible, fog, camera distance)
- `fog` — Fog of war coverage
- `waypoints` — List all waypoints with distances and status
- `goto <x> <y>` — Move player to grid position
- `next` — Move to next waypoint
- `autoplay` — Auto-complete level through all waypoints
- `reset` — Reset level
- `watch` — Toggle live state feed
- `help` / `clear`

### Diagnostics (auto-detected warnings)
- "Player not visible on screen!" — camera viewport doesn't contain player
- "Player hidden under fog of war!" — player cell not revealed
- "Camera too far from player (Npx)" — camera drift > 800px
- "Player unit is not selected!" — unit lost selection

### Headless API (for Playwright/testing)
```js
window.dreamcraftConsole.getState()       // returns parsed debug state
window.dreamcraftConsole.sendCommand(cmd, x, y)  // sends command to game
window.dreamcraftConsole.getCommandResult()      // reads command response
```

## Key Design Principles

1. **Determinism**: All game logic uses fixed-point arithmetic for perfect sync across clients
2. **Low Latency**: WebTransport/WebRTC minimize network delay vs WebSockets
3. **Performance**: WebGPU for GPU-compute and rendering; React for UI overlays
4. **Modularity**: Clear separation between logic (Rust/Bevy), UI (React), diagnostics (Agent Console)
5. **Agentic Testing**: All game state observable and controllable via localStorage bridge

## Bevy Reference

The `bevy-docs/` directory contains the full Bevy engine source for quick reference:
- Examples: `bevy-docs/examples/`
- ECS patterns: Look at `bevy-docs/examples/ecs/`
- 2D rendering: `bevy-docs/examples/2d/`
- Shaders: `bevy-docs/examples/shader/`

Also see `.opencode/skills/bevy/SKILL.md` for quick reference.

## Troubleshooting

### Before Searching Docs (Max 3 attempts):
1. Check tmux session: `tmux list-sessions`
2. Check tmux window: `tmux list-windows -t dreamcraft`
3. Check output: `tmux capture-pane -t dreamcraft:trunk -p`

### Common Issues:
- **Trunk not found**: Use full path `/home/wilsonn/.asdf/installs/rust/stable/bin/trunk serve`
- **Port in use**: Kill existing process `lsof -ti:8080 | xargs kill` or change port in Trunk.toml
- **WASM build fails**: Check Cargo.toml has correct crate-type (rlib only, not cdylib)
- **Trunk rebuild loop**: Ensure Trunk.toml `[watch] ignore` includes `dist`, `.playwright-mcp`
- **dynamic_linking breaks WASM**: Never use `bevy = { features = ["dynamic_linking"] }` in Cargo.toml — use as CLI flag only for native: `cargo run --features bevy/dynamic_linking`
- **Viewport struct private in Bevy 0.18**: Can't use `bevy::render::camera::Viewport` directly — use render layers or HTML overlay instead
- **Second camera overwrites screen**: Cameras with `order > 0` and no viewport will clear and re-render the full screen. Use HTML canvas overlays instead of extra cameras for minimap/UI.
- **Cached WASM build**: `trunk build` may use cached lib. Force rebuild: `touch src/lib.rs`
