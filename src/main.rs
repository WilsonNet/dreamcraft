use bevy::prelude::*;
use dreamcraft::DreamCraftPlugin;

fn main() {
    App::new()
        .add_plugins(DefaultPlugins)
        .add_plugins(DreamCraftPlugin)
        .run();
}
