//! DreamCraft RTS - Main library
//!
//! Module structure:
//! - core: Components, resources, plugin registration
//! - grid: Grid setup, visibility, fog of war
//! - units: Unit movement, commands, goal detection
//! - minimap: Minimap rendering and updates
//! - input: Mouse/keyboard input, camera controls
//! - pathfinding: A* pathfinding algorithm
//! - ui: UI systems (placeholder)

pub mod core;
pub mod grid;
pub mod input;
pub mod minimap;
pub mod pathfinding;
pub mod ui;
pub mod units;

// Re-export commonly used items
pub use core::*;

/// Run the game (native entry point helper)
pub fn run() {
    use bevy::prelude::*;
    App::new()
        .add_plugins(DefaultPlugins)
        .add_plugins(DreamCraftPlugin)
        .run();
}
