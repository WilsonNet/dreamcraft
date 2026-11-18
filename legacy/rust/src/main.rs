use bevy::prelude::*;
use dreamcraft::DreamCraftPlugin;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let headless = args.iter().any(|a| a == "--headless");

    let mut app = App::new();

    if headless {
        app.add_plugins(DefaultPlugins.set(WindowPlugin {
            primary_window: None,
            ..default()
        }));
    } else {
        app.add_plugins(DefaultPlugins.set(WindowPlugin {
            primary_window: Some(Window {
                title: "DreamCraft RTS - Tutorial Level 1".into(),
                resolution: (1280, 720).into(),
                ..default()
            }),
            ..default()
        }));
    }

    app.add_plugins(DreamCraftPlugin)
        .run();
}
