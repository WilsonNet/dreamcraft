# DreamCraft - Fantasy RTS Tech Stack

Spiritual successor to StarCraft: Brood War, built for the modern web.

## ⚠️ CRITICAL: Specs Files (Read First!)

**BEFORE implementing ANY feature, ALWAYS check:**
1. `specs/` folder for existing specifications
2. `.opencode/skills/specs/SKILL.md` for update guidelines

**AFTER completing ANY feature, ALWAYS:**
1. Update relevant spec files in `specs/`
2. Mark features as `[x]` completed in `specs/01-overview.md`
3. Update unit specs, input specs, or other relevant docs

**Why specs matter:**
- Single source of truth for game design
- Ensures consistency across implementations
- Documents decisions for future developers/agents
- Tracks implementation progress

**Spec files:**
| File | Purpose |
|------|---------|
| `specs/01-overview.md` | Game vision, features, implementation status, architecture |
| `specs/02-units.md` | Unit types, stats, abilities, behaviors |
| `specs/03-isometric.md` | Grid rendering, coordinate systems |
| `specs/04-input.md` | Control schemes, input handling |
| `specs/05-networking.md` | Multiplayer architecture, sync protocols |
| `specs/06-agent-console.md` | Agent Console commands, diagnostics, headless API |
| `specs/07-minimap.md` | StarCraft-style minimap implementation |

---

## Skills Map

Skills are located in `.opencode/skills/` and `.claude/skills/` and provide specialized instructions:

| Skill | Purpose |
|-------|---------|
| **bevy** | Bevy ECS patterns, common errors, UI patterns, WASM/native setup |
| **tmux** | Terminal multiplexing, session management, troubleshooting |
| **specs** | Keeping `specs/` folder updated with new features |

### Skill Update Rule (IMPORTANT!)
After completing ANY task, update relevant skills if:
- You discovered a new pattern or error fix
- You learned something not in the skill
- A skill is missing information that would have helped

Example: Fixed a Bevy UI error? -> Update `.opencode/skills/bevy/SKILL.md` with the fix.

## Code Style Rules

### Function Length Limit
**Functions MUST NOT exceed 50 lines.** If a function grows beyond 50 lines:
1. Identify logical sub-tasks within the function
2. Extract each sub-task into a separate private function
3. Give extracted functions descriptive names
4. Keep the original function as a coordinator

**Example:**
```rust
// BAD - 80 lines doing too much
fn setup_level(...) {
    // spawn camera (10 lines)
    // init grids (15 lines)
    // spawn minimap (30 lines)
    // spawn units (25 lines)
}

// GOOD - each task extracted
fn setup_level(...) {
    spawn_camera(&mut commands, ...);
    initialize_grids(&mut obstacle_grid, ...);
    spawn_minimap(&mut commands, ...);
    spawn_units(&mut commands, ...);
}
```

**Benefits:**
- Easier to test individual pieces
- Better readability
- Reusable components
- Clearer intent

### File Size Limit
**Files MUST NOT exceed 420 lines.** If a file grows beyond 420 lines:
1. Identify logical groupings of code (components, resources, systems, etc.)
2. Extract related code into separate modules
3. Organize modules by feature/domain (units, grid, minimap, input, etc.)
4. Use `mod.rs` files to expose public API

**Example structure:**
```
src/
├── main.rs          # Entry point (< 50 lines)
├── lib.rs           # Plugin registration (< 50 lines)
├── core/
│   ├── mod.rs       # Module exports
│   ├── components.rs
│   ├── resources.rs
│   └── plugin.rs
├── units/           # Unit logic
├── grid/            # Grid & fog of war
├── minimap/         # Minimap rendering
├── input/           # Input handling
└── pathfinding/     # A* pathfinding
```

## Core Architecture

### Logic (The Brain)
- **Language**: Rust
- **Targets**: Native (desktop) + WASM (browser)
- **ECS Framework**: Bevy 0.18
- **Math**: `fixed` crate for deterministic floating-point (essential for RTS synchronization)

### Networking (The Nerve) - Future
- **Client-Server**: WebTransport
- **P2P LAN**: WebRTC DataChannels
- **Rationale**: Bypass WebSocket latency for competitive RTS gameplay

### Graphics (The Eyes)
- **API**: WebGPU (via Bevy) on browser, Vulkan on native
- **Standard**: 2026 high-performance rendering
- **Features**: Custom shaders for fantasy "ambient" skill effects

### UI
- **Native**: Bevy UI (window, title bar, game view)
- **Browser**: Simple canvas (no React) - game renders to HTML canvas
- **Headless**: File-based command system (`headless_command.json` / `headless_result.json`)

## Project Structure

```
dreamcraft/
├── CLAUDE.md              # This file
├── Trunk.toml             # Trunk WASM bundler config (for browser build)
├── Cargo.toml             # Rust configuration
├── .cargo/config.toml     # Cargo config (mold linker, clang)
├── index.html             # HTML entry for WASM (minimal, no React)
├── src/
│   ├── main.rs           # Native entry point (with headless mode support)
│   ├── lib.rs            # Game plugin & ECS (all game logic)
│   └── web.rs            # WASM entry point (minimal)
├── specs/                 # Game specifications
├── .opencode/skills/      # Specialized skills
└── .claude/skills/        # Claude Code skills (mirrors .opencode/skills/)
```

## Development Setup

### Prerequisites
- Rust (stable) with `wasm32-unknown-unknown` target
- Trunk WASM bundler
- Mold linker (installed)
- Clang (installed)

### Install Tools
```bash
# Install trunk
cargo install cargo-binstall
cargo binstall trunk -y

# Install mold linker (already on system)
# Already installed via: sudo pacman -S mold clang
```

### Development Commands

#### Native (PRIMARY - fast iteration)
```bash
# With window (for playing)
cargo run --bin dreamcraft-bin --features bevy/dynamic_linking

# Headless (for agents/LLMs)
cargo run --bin dreamcraft-bin --features bevy/dynamic_linking -- --headless
```

#### Headless Agent Commands
Write to `headless_command.json`, read from `headless_result.json`:

```bash
# Status
echo '{"cmd": "status"}' > headless_command.json

# Move player
echo '{"cmd": "goto", "x": 10, "y": 25}' > headless_command.json

# Verify player position
echo '{"cmd": "verify", "verify": {"type": "player_at", "x": 10, "y": 25}}' > headless_command.json

# Verify level complete
echo '{"cmd": "verify", "verify": {"type": "level_complete"}}' > headless_command.json

# Reset level
echo '{"cmd": "reset"}' > headless_command.json
```

#### WASM (Browser) - Legacy, for testing
```bash
# Start dev server (runs on http://localhost:8080)
/home/wilsonn/.asdf/installs/rust/stable/bin/trunk serve

# Or build only
/home/wilsonn/.asdf/installs/rust/stable/bin/trunk build
```

#### tmux Setup (REQUIRED for agents)
**IMPORTANT**: Always use the tmux skill to run the game. This ensures proper process management and allows you to monitor output.

```bash
# Use tmux skill to create/manage session
tmux new-session -d -s dreamcraft -n native -c /home/wilsonn/www/dreamcraft
tmux send-keys -t dreamcraft:native 'cargo run --bin dreamcraft-bin --features bevy/dynamic_linking' Enter

# Check if game is running
tmux list-sessions
tmux capture-pane -t dreamcraft:native -p

# View live output
tmux attach -t dreamcraft:native
```

**Benefits of tmux + mold linker:**
- Game runs in background without blocking your terminal
- Easy to check compilation errors and runtime output
- Mold linker (configured in `.cargo/config.toml`) provides fast linking
- Can restart game without killing your session

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
- [x] Player unit (blue circle with "M" label) with right-click movement
- [x] Fog of war (cells revealed as player explores)
- [x] 8 waypoints through the map
- [x] Goal zone (right edge) — level complete when reached
- [x] Tree obstacles (30 clusters, 132 cells)
- [x] Camera pan (WASD/Arrow keys)
- [x] Headless command system (file-based for agentic testing)
- [x] Native build with dynamic_linking (fast iteration)
- [x] Window title: "DreamCraft RTS - Tutorial Level 1"

### Headless Agent API
- `status` — Returns player position
- `goto <x> <y>` — Move player to grid position
- `verify player_at <x> <y>` — Verify player is at position
- `verify level_complete` — Check if level is complete
- `reset` — Reset level to start

### Known Issues
- Waypoint 3 at (40,20) collides with tree cluster — pathfinding skips it
- Camera doesn't auto-follow player (must pan manually or use console `goto`)
- Headless mode creates window then closes immediately (needs fix)

## Key Design Principles

1. **Determinism**: All game logic uses fixed-point arithmetic for perfect sync across clients
2. **Low Latency**: WebTransport/WebRTC minimize network delay vs WebSockets
3. **Performance**: WebGPU for GPU-compute and rendering; native uses Vulkan
4. **Modularity**: Clear separation between logic (Rust/Bevy), native UI, browser canvas
5. **Agentic Testing**: All game state controllable and verifiable via headless command files

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
3. Check output: `tmux capture-pane -t dreamcraft:native -p`

### Common Issues:
- **Dynamic linking fails**: Use `--features bevy/dynamic_linking` for native
- **WASM build fails**: Check Cargo.toml has correct crate-type (rlib only, not cdylib)
- **Headless command not processed**: Check `headless_result.json` for errors
- **Cached WASM build**: `trunk build` may use cached lib. Force rebuild: `touch src/lib.rs`