# Isometric Coordinate System

## Grid Configuration
- Tile width: 64px
- Tile height: 32px (2:1 ratio)
- Grid size: 50x50 tiles

## Transformations

### World to Screen (Isometric Projection)
```
screenX = (worldX - worldY) * (tileWidth / 2)
screenY = (worldX + worldY) * (tileHeight / 2)
```

### Screen to World (Inverse)
```
worldX = (screenX / (tileWidth / 2) + screenY / (tileHeight / 2)) / 2
worldY = (screenY / (tileHeight / 2) - screenX / (tileWidth / 2)) / 2
```

## Rendering Order
- Units sorted by Y position for proper depth
- Draw back-to-front