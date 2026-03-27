# Specs Update Skill

## Purpose

Keep the `specs/` folder updated whenever new features are implemented or existing features change.

## When to Update

Update specs after completing any of these tasks:

### Always Update
- Adding new features
- Modifying existing features
- Changing game mechanics
- Adding new levels or maps
- Adding new UI elements
- Modifying controls
- Adding or changing networking features

### Check After
- Implementing pathfinding changes
- Adding fog of war
- Adding minimap
- Creating new unit types
- Implementing combat
- Adding resource systems

## What to Update

### `specs/01-overview.md`
- Implementation status table
- Completed features list
- Controls section
- Architecture diagrams
- Waypoint/coordinate data

### Other Specs Files
- `02-units.md` - Unit stats, abilities, behaviors
- `03-isometric.md` - Grid rendering, coordinate systems
- `04-input.md` - Control schemes, input handling
- `05-networking.md` - Multiplayer architecture, sync protocols

## Update Format

```markdown
#### Feature Name
- [x] Feature description
- [x] Sub-feature or detail
```

Use:
- `[x]` for completed features
- `[ ]` for planned/unimplemented features

## Quick Checklist

Before each commit, verify:

1. Did I add/modify any features? → Update relevant spec
2. Did I change the grid/level? → Update coordinates in 01-overview.md
3. Did I add new UI? → Document in 01-overview.md
4. Did I change controls? → Update controls section

## Example Updates

### Adding a new unit type:
```markdown
## Unit Types
- [x] Scout (Blue) - Fast movement, large vision
- [x] Melee (Red) - Close combat
- [ ] Archer (Green) - Ranged attacks (NEW)
```

### Adding a map feature:
```markdown
- [x] Minimap (bottom-left)
- [x] Fog of War system
- [x] Waypoint system
```
