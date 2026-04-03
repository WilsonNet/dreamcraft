# DreamCraft RTS

A web-based fantasy RTS game — spiritual successor to StarCraft: Brood War. Built with Rust/Bevy (WASM) for game logic and React for UI overlays.

## Quick Start

```bash
# Install trunk (WASM bundler)
cargo binstall trunk -y

# Run dev server (via tmux)
tmux new-session -d -s dreamcraft -n trunk
tmux send-keys -t dreamcraft:trunk '/home/wilsonn/.asdf/installs/rust/stable/bin/trunk serve' Enter

# Open http://localhost:8080
```

## Controls

- **Right-Click**: Move unit to location
- **WASD / Arrow Keys**: Pan camera
- **Backtick (`` ` ``)**: Toggle Agent Console

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Game Logic | Rust + Bevy 0.18 ECS |
| Target | WebAssembly (via Trunk) |
| UI Overlays | React 19 (CDN, same page) |
| Minimap | React Canvas (StarCraft-style, bottom-left) |
| Debug | Agent Console + Playwright MCP |
| Math | `fixed` crate (deterministic floating-point) |
| Networking | WebTransport + WebRTC (planned) |

## Specs

Detailed specifications live in the [`specs/`](specs/) folder:

| Spec | Description |
|------|-------------|
| [01-overview.md](specs/01-overview.md) | Game vision, features, implementation status, architecture |
| [02-units.md](specs/02-units.md) | Unit types, stats, abilities |
| [03-isometric.md](specs/03-isometric.md) | Grid rendering, coordinate systems |
| [04-input.md](specs/04-input.md) | Control schemes, input handling |
| [05-networking.md](specs/05-networking.md) | Multiplayer architecture, sync protocols |
| [06-agent-console.md](specs/06-agent-console.md) | Agent Console commands, diagnostics, headless API |
| [07-minimap.md](specs/07-minimap.md) | StarCraft-style minimap implementation |

## Current State: Tutorial Level 1

"Through the Woods" — navigate a unit through a fog-covered forest to reach the goal zone.

- 80x50 grid map with A* pathfinding
- Fog of war with progressive reveal via 8 waypoints
- 30 tree clusters (132 obstacle cells)
- StarCraft-style minimap with camera viewport indicator
- Agent Console for debugging and automated level completion
- Fully completable headlessly via Playwright

## Project Structure

```
dreamcraft/
├── src/
│   ├── lib.rs         # All game logic (ECS systems, pathfinding, fog, debug)
│   ├── web.rs         # WASM entry point
│   └── main.rs        # Native entry point
├── index.html         # Trunk entry (game canvas + React console + React minimap)
├── specs/             # Game specifications
├── Cargo.toml         # Rust dependencies
├── Trunk.toml         # WASM bundler config
└── bevy-docs/         # Bevy engine reference
```

## Architecture

- **Game Logic**: Pure Rust/Bevy ECS — deterministic, sync-ready
- **Rendering**: Bevy 2D (Mesh2d, Circle, Rectangle, Gizmos)
- **UI Overlays**: React 19 components rendered in the same Trunk-served page
- **Bevy <-> React**: Bidirectional communication via localStorage
- **Testing**: Headless control via `window.dreamcraftConsole` API + Playwright MCP

## Links

- [Bevy Docs](bevy-docs/) — Engine reference
- [Specs](specs/) — Game specifications
- [CLAUDE.md](CLAUDE.md) — Development guide and troubleshooting
