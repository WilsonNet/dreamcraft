# Networking

## Architecture

### Client-Server (WebTransport)
- Primary mode for online play
- Low latency vs WebSockets
- Server authoritative state

### P2P LAN (WebRTC DataChannels)
- Direct peer-to-peer
- Lower latency for local networks
- For LAN parties

## Determinism
- Fixed-point math for all positions
- 60 FPS fixed timestep
- Frame-accurate state sync
- Client prediction with server reconciliation