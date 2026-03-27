# DreamCraft - Fantasy RTS Tech Stack

## Skills Map

Skills are located in `.opencode/skills/` and provide specialized instructions:

| Skill | Purpose |
|-------|---------|
| **bevy.md** | Bevy ECS patterns, common errors, UI patterns, WASM setup |
| **tmux.md** | Terminal multiplexing, session management, troubleshooting |
| **specs.md** | Keeping `specs/` folder updated with new features |

### Skill Update Rule (IMPORTANT!)
After completing ANY task, update relevant skills if:
- You discovered a new pattern or error fix
- You learned something not in the skill
- A skill is missing information that would have helped

Example: Fixed a Bevy UI error? → Update `bevy.md` with the fix.

## Core Architecture

### Logic (The Brain)
- **Language**: Rust
- **Target**: WebAssembly (WASM)
- **ECS Framework**: Bevy
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
- **Framework**: React
- **Compiler**: React Compiler (for optimized re-renders)

## Project Structure

```
dreamcraft/
├── AGENTS.md              # This file
├── Trunk.toml             # Trunk WASM bundler config
├── Cargo.toml             # Rust configuration
├── .cargo/config.toml     # Cargo config (mold linker)
├── index.html             # HTML entry for Trunk
├── bevy-docs/             # Bevy engine source for reference
├── specs/                 # Game specifications
├── .opencode/skills/      # Specialized skills (ALWAYS KEEP UPDATED!)
├── src/
│   ├── main.rs           # Native entry point
│   ├── lib.rs            # Game plugin & ECS
│   └── web.rs            # WASM entry point
└── web/
    ├── src/
    │   ├── App.tsx       # React UI
    │   └── renderer/     # WebGPU integration
    └── package.json
```

## Development Setup

### Prerequisites
- Rust (stable)
- Trunk WASM bundler
- Mold linker (installed)
- Clang (installed)
- Bun (for web/React)

### Install Tools
```bash
# Install trunk
cargo install cargo-binstall
cargo binstall trunk -y

# Install mold linker (already on system)
# Already installed via: sudo pacman -S mold clang
```

### Development Commands

#### Native (Desktop Testing)
```bash
# Run native version
cargo run

# Or with dynamic linking for faster builds
cargo run --features bevy/dynamic_linking
```

#### WASM (Browser)
```bash
# Start dev server (runs on http://localhost:8080)
/home/wilsonn/.asdf/installs/rust/stable/bin/trunk serve

# Or build for release
trunk build --release
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

## Key Design Principles

1. **Determinism**: All game logic uses fixed-point arithmetic for perfect sync across clients
2. **Low Latency**: WebTransport/WebRTC minimize network delay vs WebSockets
3. **Performance**: WebGPU for GPU-compute and rendering; React Compiler eliminates unnecessary re-renders
4. **Modularity**: Clear separation between logic (Rust), networking (Rust), and UI (React)

## Bevy Reference

The `bevy-docs/` directory contains the full Bevy engine source for quick reference:
- Examples: `bevy-docs/examples/`
- ECS patterns: Look at `bevy-docs/examples/ecs/`
- 2D rendering: `bevy-docs/examples/2d/`
- Shaders: `bevy-docs/examples/shader/`

Also see `.opencode/skills/bevy.md` for quick reference.

## Troubleshooting

### Before Searching Docs (Max 3 attempts):
1. Check tmux session: `tmux list-sessions`
2. Check tmux window: `tmux list-windows -t dreamcraft`
3. Check output: `tmux capture-pane -t dreamcraft:trunk -p`

### Common Issues:
- **Trunk not found**: Use full path `/home/wilsonn/.asdf/installs/rust/stable/bin/trunk serve`
- **Port in use**: Kill existing process or change port in Trunk.toml
- **WASM build fails**: Check Cargo.toml has correct crate-type (rlib only, not cdylib)
