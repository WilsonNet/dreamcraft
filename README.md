# DreamCraft

A web-based fantasy RTS game built with Rust, Bevy, and WebGPU.

## Tech Stack

- **Logic**: Rust + WebAssembly (WASM)
- **Engine**: Bevy ECS
- **Math**: `fixed` crate for deterministic floating-point
- **Networking**: WebTransport (client-server) + WebRTC (P2P LAN)
- **Graphics**: WebGPU
- **UI**: React + React Compiler
- **Bundler**: Trunk

## Getting Started

### Prerequisites
- Rust (stable)
- Trunk WASM bundler
- Mold linker
- Clang
- Bun (for web/React)

### Development

```bash
# Run native (fast iteration)
cargo run

# Run WASM dev server (on tmux window 'trunk')
/home/wilsonn/.asdf/installs/rust/stable/bin/trunk serve
# Open http://localhost:8080
```

## Project Structure

```
dreamcraft/
├── src/                    # Rust game code
│   ├── lib.rs             # Bevy ECS plugins
│   ├── main.rs            # Native entry point
│   └── web.rs             # WASM entry point
├── web/                    # React UI (menu only)
├── bevy-docs/              # Bevy engine reference
├── specs/                  # Game specifications
└── index.html              # Trunk entry point
```

## Architecture

- **Game Logic**: Pure Rust/Bevy ECS - deterministic, sync-ready
- **Rendering**: WebGPU via Bevy
- **Networking**: WebTransport (online) + WebRTC (LAN)
- **UI**: React for menus overlaying WASM canvas

## Links

- [Bevy Docs](bevy-docs/) - Engine reference
- [Specs](specs/) - Game specifications