use bevy::prelude::*;
use dreamcraft::DreamCraftPlugin;

#[wasm_bindgen(start)]
pub fn wasm_main() {
    App::new()
        .add_plugins(DefaultPlugins.set(WindowPlugin {
            primary_window: Some(Window {
                title: "DreamCraft RTS".into(),
                resolution: (1280.0, 720.0).into(),
                fit_canvas_to_parent: true,
                prevent_default_event_handling: false,
                ..default()
            }),
            ..default()
        }))
        .add_plugins(DreamCraftPlugin)
        .run();
}
