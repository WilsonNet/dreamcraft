// DreamCraft RTS - Isometric Proof of Concept
// Deterministic ECS-based game engine with isometric rendering

// Types
enum UnitType {
    GATHERER = 0,  // Gold - Resource collection
    SCOUT = 1,     // Blue - Fast, vision
    MELEE = 2,     // Red - Close combat
    RANGED = 3,    // Green - Projectile attacks
}

enum EntityState {
    IDLE = 0,
    MOVING = 1,
    GATHERING = 2,
    ATTACKING = 3,
    RETURNING = 4,
}

// Deterministic fixed-point math (using integers scaled by 1000)
const FP_SCALE = 1000;

class FixedVec2 {
    constructor(public x: number = 0, public y: number = 0) {}
    
    add(other: FixedVec2): FixedVec2 {
        return new FixedVec2(this.x + other.x, this.y + other.y);
    }
    
    sub(other: FixedVec2): FixedVec2 {
        return new FixedVec2(this.x - other.x, this.y - other.y);
    }
    
    mul(scalar: number): FixedVec2 {
        return new FixedVec2(
            Math.floor((this.x * scalar) / FP_SCALE),
            Math.floor((this.y * scalar) / FP_SCALE)
        );
    }
    
    length(): number {
        // Approximate sqrt for integers: using bit shifts for performance
        const squared = (this.x * this.x + this.y * this.y) / FP_SCALE;
        return Math.floor(Math.sqrt(squared) * FP_SCALE);
    }
    
    normalize(): FixedVec2 {
        const len = this.length();
        if (len === 0) return new FixedVec2(0, 0);
        return new FixedVec2(
            Math.floor((this.x * FP_SCALE) / len),
            Math.floor((this.y * FP_SCALE) / len)
        );
    }
    
    distanceTo(other: FixedVec2): number {
        const dx = this.x - other.x;
        const dy = this.y - other.y;
        return Math.floor(Math.sqrt(dx * dx + dy * dy));
    }
}

// Components
class Transform {
    position: FixedVec2 = new FixedVec2();
    velocity: FixedVec2 = new FixedVec2();
    rotation: number = 0;
}

class UnitData {
    type: UnitType = UnitType.MELEE;
    state: EntityState = EntityState.IDLE;
    hp: number = 100;
    maxHp: number = 100;
    speed: number = 5 * FP_SCALE; // Units per frame
    attackRange: number = 2 * FP_SCALE;
    visionRange: number = 10 * FP_SCALE;
    damage: number = 10;
    attackCooldown: number = 0;
    maxAttackCooldown: number = 60; // Frames
}

class Selection {
    selected: boolean = false;
}

class Target {
    position: FixedVec2 | null = null;
    entityId: number | null = null;
    path: FixedVec2[] = [];
}

// Resource component
class Resource {
    amount: number = 100;
    maxAmount: number = 100;
}

// Projectile component
class Projectile {
    damage: number = 20;
    speed: number = 15 * FP_SCALE;
    targetId: number = -1;
    lifeTime: number = 60;
}

// Entity
class Entity {
    id: number;
    transform: Transform | null = null;
    unitData: UnitData | null = null;
    selection: Selection | null = null;
    target: Target | null = null;
    resource: Resource | null = null;
    projectile: Projectile | null = null;
    
    constructor(id: number) {
        this.id = id;
    }
}

// World
class World {
    entities: Map<number, Entity> = new Map();
    nextId: number = 0;
    gridSize: number = 32; // Grid cell size in world units
    gridWidth: number = 50;
    gridHeight: number = 50;
    
    createEntity(): Entity {
        const entity = new Entity(this.nextId++);
        this.entities.set(entity.id, entity);
        return entity;
    }
    
    removeEntity(id: number) {
        this.entities.delete(id);
    }
    
    getEntitiesWith<T>(component: keyof Entity): Entity[] {
        return Array.from(this.entities.values()).filter(e => e[component] !== null);
    }
}

// A* Pathfinding
class Pathfinder {
    world: World;
    
    constructor(world: World) {
        this.world = world;
    }
    
    findPath(start: FixedVec2, end: FixedVec2): FixedVec2[] {
        // Convert to grid coordinates
        const startX = Math.floor(start.x / this.world.gridSize);
        const startY = Math.floor(start.y / this.world.gridSize);
        const endX = Math.floor(end.x / this.world.gridSize);
        const endY = Math.floor(end.y / this.world.gridSize);
        
        // Simple BFS for pathfinding
        const queue: [number, number][] = [[startX, startY]];
        const visited = new Set<string>([`${startX},${startY}`]);
        const parent = new Map<string, [number, number]>();
        
        const directions = [[0, 1], [0, -1], [1, 0], [-1, 0], [1, 1], [1, -1], [-1, 1], [-1, -1]];
        
        let found = false;
        
        while (queue.length > 0) {
            const [cx, cy] = queue.shift()!;
            
            if (cx === endX && cy === endY) {
                found = true;
                break;
            }
            
            for (const [dx, dy] of directions) {
                const nx = cx + dx;
                const ny = cy + dy;
                const key = `${nx},${ny}`;
                
                if (nx >= 0 && nx < this.world.gridWidth && 
                    ny >= 0 && ny < this.world.gridHeight && 
                    !visited.has(key)) {
                    visited.add(key);
                    parent.set(key, [cx, cy]);
                    queue.push([nx, ny]);
                }
            }
        }
        
        if (!found) return [];
        
        // Reconstruct path
        const path: FixedVec2[] = [];
        let curr: [number, number] = [endX, endY];
        
        while (curr[0] !== startX || curr[1] !== startY) {
            path.unshift(new FixedVec2(
                curr[0] * this.world.gridSize + this.world.gridSize / 2,
                curr[1] * this.world.gridSize + this.world.gridSize / 2
            ));
            curr = parent.get(`${curr[0]},${curr[1]}`)!;
        }
        
        return path;
    }
}

// Game State
class GameState {
    world: World = new World();
    pathfinder: Pathfinder;
    lastUpdateTime: number = 0;
    frameCount: number = 0;
    selectedEntities: Set<number> = new Set();
    
    // Camera
    cameraX: number = 0;
    cameraY: number = 0;
    zoom: number = 1;
    
    // Input
    mouseX: number = 0;
    mouseY: number = 0;
    isDragging: boolean = false;
    dragStartX: number = 0;
    dragStartY: number = 0;
    shiftPressed: boolean = false;
    
    constructor() {
        this.pathfinder = new Pathfinder(this.world);
        this.initWorld();
    }
    
    initWorld() {
        // Create base
        const base = this.world.createEntity();
        base.transform = new Transform();
        base.transform.position = new FixedVec2(25 * this.world.gridSize, 25 * this.world.gridSize);
        base.unitData = new UnitData();
        base.unitData.type = UnitType.GATHERER;
        base.unitData.speed = 0;
        base.selection = new Selection();
        base.resource = new Resource();
        
        // Create resource nodes
        for (let i = 0; i < 5; i++) {
            const resource = this.world.createEntity();
            resource.transform = new Transform();
            resource.transform.position = new FixedVec2(
                (10 + i * 8) * this.world.gridSize,
                (10 + i * 3) * this.world.gridSize
            );
            resource.resource = new Resource();
            resource.resource.amount = 500;
        }
        
        // Create units
        const unitConfigs = [
            { type: UnitType.GATHERER, count: 3, color: '#FFD700' },
            { type: UnitType.SCOUT, count: 2, color: '#4169E1' },
            { type: UnitType.MELEE, count: 4, color: '#DC143C' },
            { type: UnitType.RANGED, count: 3, color: '#228B22' },
        ];
        
        let unitId = 0;
        for (const config of unitConfigs) {
            for (let i = 0; i < config.count; i++) {
                const unit = this.world.createEntity();
                unit.transform = new Transform();
                unit.transform.position = new FixedVec2(
                    (20 + unitId % 5) * this.world.gridSize,
                    (20 + Math.floor(unitId / 5)) * this.world.gridSize
                );
                unit.unitData = new UnitData();
                unit.unitData.type = config.type;
                unit.selection = new Selection();
                unit.target = new Target();
                
                // Set unit-specific stats
                switch (config.type) {
                    case UnitType.GATHERER:
                        unit.unitData.speed = 4 * FP_SCALE;
                        unit.unitData.attackRange = 2 * FP_SCALE;
                        break;
                    case UnitType.SCOUT:
                        unit.unitData.speed = 10 * FP_SCALE;
                        unit.unitData.visionRange = 20 * FP_SCALE;
                        unit.unitData.attackRange = 2 * FP_SCALE;
                        break;
                    case UnitType.MELEE:
                        unit.unitData.speed = 5 * FP_SCALE;
                        unit.unitData.attackRange = 3 * FP_SCALE;
                        unit.unitData.damage = 15;
                        break;
                    case UnitType.RANGED:
                        unit.unitData.speed = 4 * FP_SCALE;
                        unit.unitData.attackRange = 15 * FP_SCALE;
                        unit.unitData.damage = 8;
                        break;
                }
                
                unitId++;
            }
        }
        
        // Create enemy units for testing
        for (let i = 0; i < 3; i++) {
            const enemy = this.world.createEntity();
            enemy.transform = new Transform();
            enemy.transform.position = new FixedVec2(
                (40 + i) * this.world.gridSize,
                15 * this.world.gridSize
            );
            enemy.unitData = new UnitData();
            enemy.unitData.type = UnitType.MELEE;
            enemy.unitData.speed = 5 * FP_SCALE;
            enemy.unitData.attackRange = 3 * FP_SCALE;
            enemy.unitData.hp = 50;
            enemy.selection = new Selection();
            enemy.target = new Target();
        }
    }
    
    update() {
        // Fixed timestep at 60 FPS
        const units = this.world.getEntitiesWith('unitData');
        
        for (const unit of units) {
            if (!unit.transform || !unit.unitData) continue;
            
            // Handle attack cooldown
            if (unit.unitData.attackCooldown > 0) {
                unit.unitData.attackCooldown--;
            }
            
            // State machine
            switch (unit.unitData.state) {
                case EntityState.IDLE:
                    // Find nearest enemy
                    const nearest = this.findNearestEnemy(unit);
                    if (nearest && unit.unitData.attackRange > 0) {
                        const dist = unit.transform.position.distanceTo(nearest.transform!.position);
                        if (dist <= unit.unitData.attackRange) {
                            unit.unitData.state = EntityState.ATTACKING;
                            if (unit.target) unit.target.entityId = nearest.id;
                        }
                    }
                    break;
                    
                case EntityState.MOVING:
                    if (unit.target && unit.target.path.length > 0) {
                        const nextPos = unit.target.path[0];
                        const dist = unit.transform.position.distanceTo(nextPos);
                        
                        if (dist < unit.unitData.speed) {
                            unit.transform.position = nextPos;
                            unit.target.path.shift();
                            if (unit.target.path.length === 0) {
                                unit.unitData.state = EntityState.IDLE;
                            }
                        } else {
                            const dir = nextPos.sub(unit.transform.position).normalize();
                            unit.transform.velocity = dir.mul(unit.unitData.speed / FP_SCALE);
                            unit.transform.position = unit.transform.position.add(unit.transform.velocity);
                        }
                    } else {
                        unit.unitData.state = EntityState.IDLE;
                    }
                    break;
                    
                case EntityState.ATTACKING:
                    if (unit.target && unit.target.entityId !== null) {
                        const target = this.world.entities.get(unit.target.entityId);
                        if (target && target.unitData && target.transform) {
                            const dist = unit.transform.position.distanceTo(target.transform.position);
                            
                            if (dist > unit.unitData.attackRange) {
                                // Move closer
                                unit.unitData.state = EntityState.MOVING;
                                unit.target.path = this.pathfinder.findPath(
                                    unit.transform.position,
                                    target.transform.position
                                );
                            } else if (unit.unitData.attackCooldown === 0) {
                                // Attack
                                if (unit.unitData.type === UnitType.RANGED) {
                                    this.spawnProjectile(unit, target);
                                } else {
                                    target.unitData.hp -= unit.unitData.damage;
                                    if (target.unitData.hp <= 0) {
                                        this.world.removeEntity(target.id);
                                        unit.target.entityId = null;
                                        unit.unitData.state = EntityState.IDLE;
                                    }
                                }
                                unit.unitData.attackCooldown = unit.unitData.maxAttackCooldown;
                            }
                        } else {
                            unit.unitData.state = EntityState.IDLE;
                            unit.target.entityId = null;
                        }
                    }
                    break;
                    
                case EntityState.GATHERING:
                    // Gatherer logic - move to resource and back to base
                    if (unit.target && unit.target.entityId !== null) {
                        const target = this.world.entities.get(unit.target.entityId);
                        if (target && target.resource && target.transform) {
                            const dist = unit.transform.position.distanceTo(target.transform.position);
                            
                            if (dist > unit.unitData.attackRange) {
                                unit.target.path = this.pathfinder.findPath(
                                    unit.transform.position,
                                    target.transform.position
                                );
                                unit.unitData.state = EntityState.MOVING;
                            } else {
                                // Gather resources
                                if (target.resource.amount > 0) {
                                    target.resource.amount -= 1;
                                    if (target.resource.amount === 0) {
                                        unit.unitData.state = EntityState.IDLE;
                                    }
                                }
                            }
                        }
                    }
                    break;
            }
        }
        
        // Update projectiles
        const projectiles = this.world.getEntitiesWith('projectile');
        for (const proj of projectiles) {
            if (!proj.projectile || !proj.transform) continue;
            
            proj.projectile.lifeTime--;
            if (proj.projectile.lifeTime <= 0) {
                this.world.removeEntity(proj.id);
                continue;
            }
            
            const target = this.world.entities.get(proj.projectile.targetId);
            if (target && target.transform) {
                const dist = proj.transform.position.distanceTo(target.transform.position);
                
                if (dist < proj.projectile.speed) {
                    // Hit target
                    if (target.unitData) {
                        target.unitData.hp -= proj.projectile.damage;
                        if (target.unitData.hp <= 0) {
                            this.world.removeEntity(target.id);
                        }
                    }
                    this.world.removeEntity(proj.id);
                } else {
                    const dir = target.transform.position.sub(proj.transform.position).normalize();
                    proj.transform.velocity = dir.mul(proj.projectile.speed / FP_SCALE);
                    proj.transform.position = proj.transform.position.add(proj.transform.velocity);
                }
            } else {
                this.world.removeEntity(proj.id);
            }
        }
        
        this.frameCount++;
    }
    
    findNearestEnemy(unit: Entity): Entity | null {
        let nearest: Entity | null = null;
        let minDist = Infinity;
        
        const units = this.world.getEntitiesWith('unitData');
        for (const other of units) {
            if (other.id === unit.id || !other.transform) continue;
            
            const dist = unit.transform!.position.distanceTo(other.transform.position);
            if (dist < minDist && dist <= unit.unitData!.visionRange) {
                minDist = dist;
                nearest = other;
            }
        }
        
        return nearest;
    }
    
    spawnProjectile(source: Entity, target: Entity) {
        const proj = this.world.createEntity();
        proj.transform = new Transform();
        proj.transform.position = new FixedVec2(
            source.transform!.position.x,
            source.transform!.position.y
        );
        proj.projectile = new Projectile();
        proj.projectile.damage = source.unitData!.damage;
        proj.projectile.targetId = target.id;
    }
    
    // Input handling
    screenToWorld(screenX: number, screenY: number): FixedVec2 {
        // Reverse isometric projection
        // isoX = (x - y) * (tileWidth / 2)
        // isoY = (x + y) * (tileHeight / 4)
        
        // Solving for x, y:
        // x = isoX / (tileWidth / 2) + isoY / (tileHeight / 4)
        // y = isoY / (tileHeight / 4) - isoX / (tileWidth / 2)
        
        const tileWidth = this.world.gridSize * this.zoom;
        const tileHeight = this.world.gridSize * this.zoom;
        
        const isoX = screenX - this.cameraX;
        const isoY = screenY - this.cameraY;
        
        const x = Math.floor((isoX / (tileWidth / 2) + isoY / (tileHeight / 4)) / 2);
        const y = Math.floor((isoY / (tileHeight / 4) - isoX / (tileWidth / 2)) / 2);
        
        return new FixedVec2(x * this.world.gridSize, y * this.world.gridSize);
    }
    
    selectEntity(entity: Entity, addToSelection: boolean = false) {
        if (!addToSelection) {
            this.clearSelection();
        }
        
        if (entity.selection) {
            entity.selection.selected = true;
            this.selectedEntities.add(entity.id);
        }
    }
    
    selectBox(x1: number, y1: number, x2: number, y2: number, addToSelection: boolean = false) {
        if (!addToSelection) {
            this.clearSelection();
        }
        
        const entities = this.world.getEntitiesWith('unitData');
        
        for (const entity of entities) {
            if (!entity.transform) continue;
            
            const pos = this.worldToScreen(
                entity.transform.position.x,
                entity.transform.position.y
            );
            
            if (pos.x >= Math.min(x1, x2) && pos.x <= Math.max(x1, x2) &&
                pos.y >= Math.min(y1, y2) && pos.y <= Math.max(y1, y2)) {
                if (entity.selection) {
                    entity.selection.selected = true;
                    this.selectedEntities.add(entity.id);
                }
            }
        }
    }
    
    clearSelection() {
        for (const id of this.selectedEntities) {
            const entity = this.world.entities.get(id);
            if (entity && entity.selection) {
                entity.selection.selected = false;
            }
        }
        this.selectedEntities.clear();
    }
    
    worldToScreen(worldX: number, worldY: number): { x: number, y: number } {
        // Isometric projection
        // isoX = (x - y) * (tileWidth / 2)
        // isoY = (x + y) * (tileHeight / 4)
        
        const tileWidth = this.world.gridSize * this.zoom;
        const tileHeight = this.world.gridSize * this.zoom;
        
        const isoX = (worldX - worldY) * (tileWidth / 2) / FP_SCALE;
        const isoY = (worldX + worldY) * (tileHeight / 4) / FP_SCALE;
        
        return {
            x: isoX + this.cameraX,
            y: isoY + this.cameraY
        };
    }
}

// Renderer
class Renderer {
    canvas: HTMLCanvasElement;
    ctx: CanvasRenderingContext2D;
    gameState: GameState;
    
    constructor(canvas: HTMLCanvasElement, gameState: GameState) {
        this.canvas = canvas;
        this.ctx = canvas.getContext('2d')!;
        this.gameState = gameState;
        
        this.resize();
        window.addEventListener('resize', () => this.resize());
    }
    
    resize() {
        this.canvas.width = window.innerWidth;
        this.canvas.height = window.innerHeight;
        
        // Center camera on world
        this.gameState.cameraX = this.canvas.width / 2;
        this.gameState.cameraY = this.canvas.height / 4;
    }
    
    render() {
        // Clear
        this.ctx.fillStyle = '#1a1a2e';
        this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
        
        // Render grid
        this.renderGrid();
        
        // Render resources
        this.renderResources();
        
        // Render selection box
        if (this.gameState.isDragging) {
            this.renderSelectionBox();
        }
        
        // Render units
        this.renderUnits();
        
        // Render projectiles
        this.renderProjectiles();
        
        // Render UI overlay
        this.renderUI();
    }
    
    renderGrid() {
        const ctx = this.ctx;
        const gridSize = this.gameState.world.gridSize * this.gameState.zoom;
        
        ctx.strokeStyle = 'rgba(100, 100, 150, 0.3)';
        ctx.lineWidth = 1;
        
        // Draw isometric grid
        for (let x = 0; x <= this.gameState.world.gridWidth; x++) {
            for (let y = 0; y <= this.gameState.world.gridHeight; y++) {
                const p1 = this.gameState.worldToScreen(x * FP_SCALE * this.gameState.world.gridSize, y * FP_SCALE * this.gameState.world.gridSize);
                const p2 = this.gameState.worldToScreen((x + 1) * FP_SCALE * this.gameState.world.gridSize, y * FP_SCALE * this.gameState.world.gridSize);
                const p3 = this.gameState.worldToScreen(x * FP_SCALE * this.gameState.world.gridSize, (y + 1) * FP_SCALE * this.gameState.world.gridSize);
                
                ctx.beginPath();
                ctx.moveTo(p1.x, p1.y);
                ctx.lineTo(p2.x, p2.y);
                ctx.stroke();
                
                ctx.beginPath();
                ctx.moveTo(p1.x, p1.y);
                ctx.lineTo(p3.x, p3.y);
                ctx.stroke();
            }
        }
    }
    
    renderResources() {
        const resources = this.gameState.world.getEntitiesWith('resource');
        
        for (const resource of resources) {
            if (!resource.transform || !resource.resource) continue;
            
            const pos = this.gameState.worldToScreen(
                resource.transform.position.x,
                resource.transform.position.y
            );
            
            const size = 16 * this.gameState.zoom;
            
            // Draw resource node
            this.ctx.fillStyle = '#8B4513';
            this.ctx.beginPath();
            this.ctx.ellipse(pos.x, pos.y - size/2, size, size/2, 0, 0, Math.PI * 2);
            this.ctx.fill();
            
            // Draw resource indicator
            this.ctx.fillStyle = '#FFD700';
            this.ctx.beginPath();
            this.ctx.arc(pos.x, pos.y - size, 6 * this.gameState.zoom, 0, Math.PI * 2);
            this.ctx.fill();
        }
    }
    
    renderUnits() {
        const units = this.gameState.world.getEntitiesWith('unitData');
        
        // Sort by Y for proper depth
        units.sort((a, b) => {
            if (!a.transform || !b.transform) return 0;
            return a.transform.position.y - b.transform.position.y;
        });
        
        for (const unit of units) {
            if (!unit.transform || !unit.unitData) continue;
            
            const pos = this.gameState.worldToScreen(
                unit.transform.position.x,
                unit.transform.position.y
            );
            
            const size = 12 * this.gameState.zoom;
            
            // Get unit color
            let color = '#fff';
            switch (unit.unitData.type) {
                case UnitType.GATHERER: color = '#FFD700'; break;
                case UnitType.SCOUT: color = '#4169E1'; break;
                case UnitType.MELEE: color = '#DC143C'; break;
                case UnitType.RANGED: color = '#228B22'; break;
            }
            
            // Draw selection ring
            if (unit.selection?.selected) {
                this.ctx.strokeStyle = '#00ff00';
                this.ctx.lineWidth = 2;
                this.ctx.beginPath();
                this.ctx.ellipse(pos.x, pos.y, size + 4, size/2 + 2, 0, 0, Math.PI * 2);
                this.ctx.stroke();
            }
            
            // Draw unit as skewed square (isometric projection)
            this.ctx.fillStyle = color;
            this.ctx.beginPath();
            
            // Isometric square
            const halfSize = size / 2;
            this.ctx.moveTo(pos.x - halfSize, pos.y - halfSize/2);
            this.ctx.lineTo(pos.x + halfSize, pos.y - halfSize/2);
            this.ctx.lineTo(pos.x + halfSize, pos.y + halfSize/2);
            this.ctx.lineTo(pos.x - halfSize, pos.y + halfSize/2);
            this.ctx.closePath();
            this.ctx.fill();
            
            // Draw HP bar
            if (unit.unitData.hp < unit.unitData.maxHp) {
                const hpPercent = unit.unitData.hp / unit.unitData.maxHp;
                const barWidth = size * 1.5;
                const barHeight = 3 * this.gameState.zoom;
                
                this.ctx.fillStyle = '#333';
                this.ctx.fillRect(pos.x - barWidth/2, pos.y - size - 8, barWidth, barHeight);
                
                this.ctx.fillStyle = hpPercent > 0.5 ? '#0f0' : hpPercent > 0.25 ? '#ff0' : '#f00';
                this.ctx.fillRect(pos.x - barWidth/2, pos.y - size - 8, barWidth * hpPercent, barHeight);
            }
            
            // Draw unit type indicator
            this.ctx.fillStyle = '#fff';
            this.ctx.font = `${10 * this.gameState.zoom}px monospace`;
            this.ctx.textAlign = 'center';
            const typeNames = ['G', 'S', 'M', 'R'];
            this.ctx.fillText(typeNames[unit.unitData.type], pos.x, pos.y + 3);
        }
    }
    
    renderProjectiles() {
        const projectiles = this.gameState.world.getEntitiesWith('projectile');
        
        for (const proj of projectiles) {
            if (!proj.transform) continue;
            
            const pos = this.gameState.worldToScreen(
                proj.transform.position.x,
                proj.transform.position.y
            );
            
            this.ctx.fillStyle = '#ffff00';
            this.ctx.beginPath();
            this.ctx.arc(pos.x, pos.y, 3 * this.gameState.zoom, 0, Math.PI * 2);
            this.ctx.fill();
        }
    }
    
    renderSelectionBox() {
        const ctx = this.ctx;
        const x1 = this.gameState.dragStartX;
        const y1 = this.gameState.dragStartY;
        const x2 = this.gameState.mouseX;
        const y2 = this.gameState.mouseY;
        
        ctx.strokeStyle = '#00ff00';
        ctx.fillStyle = 'rgba(0, 255, 0, 0.2)';
        ctx.lineWidth = 1;
        
        ctx.fillRect(
            Math.min(x1, x2),
            Math.min(y1, y2),
            Math.abs(x2 - x1),
            Math.abs(y2 - y1)
        );
        
        ctx.strokeRect(
            Math.min(x1, x2),
            Math.min(y1, y2),
            Math.abs(x2 - x1),
            Math.abs(y2 - y1)
        );
    }
    
    renderUI() {
        // Update FPS
        const fps = Math.round(1000 / (performance.now() - this.gameState.lastUpdateTime + 16));
        document.getElementById('fps')!.textContent = fps.toString();
        document.getElementById('unitCount')!.textContent = this.gameState.world.entities.size.toString();
        document.getElementById('selectedCount')!.textContent = this.gameState.selectedEntities.size.toString();
    }
}

// Main Game
class Game {
    canvas: HTMLCanvasElement;
    gameState: GameState;
    renderer: Renderer;
    isRunning: boolean = false;
    animationId: number = 0;
    
    constructor() {
        this.canvas = document.getElementById('gameCanvas') as HTMLCanvasElement;
        this.gameState = new GameState();
        this.renderer = new Renderer(this.canvas, this.gameState);
        
        this.setupInput();
        this.start();
    }
    
    setupInput() {
        // Mouse down
        this.canvas.addEventListener('mousedown', (e) => {
            this.gameState.mouseX = e.clientX;
            this.gameState.mouseY = e.clientY;
            this.gameState.shiftPressed = e.shiftKey;
            
            if (e.button === 0) {
                // Left click - start selection
                this.gameState.isDragging = true;
                this.gameState.dragStartX = e.clientX;
                this.gameState.dragStartY = e.clientY;
            } else if (e.button === 2) {
                // Right click - move/attack
                e.preventDefault();
                this.handleRightClick(e.clientX, e.clientY);
            }
        });
        
        // Mouse move
        this.canvas.addEventListener('mousemove', (e) => {
            this.gameState.mouseX = e.clientX;
            this.gameState.mouseY = e.clientY;
        });
        
        // Mouse up
        this.canvas.addEventListener('mouseup', (e) => {
            if (e.button === 0 && this.gameState.isDragging) {
                // End selection
                const dragDistance = Math.sqrt(
                    Math.pow(e.clientX - this.gameState.dragStartX, 2) +
                    Math.pow(e.clientY - this.gameState.dragStartY, 2)
                );
                
                if (dragDistance < 5) {
                    // Single click - select unit under cursor
                    this.handleLeftClick(e.clientX, e.clientY);
                } else {
                    // Box select
                    this.gameState.selectBox(
                        this.gameState.dragStartX,
                        this.gameState.dragStartY,
                        e.clientX,
                        e.clientY,
                        this.gameState.shiftPressed
                    );
                }
                
                this.gameState.isDragging = false;
            }
        });
        
        // Prevent context menu
        this.canvas.addEventListener('contextmenu', (e) => {
            e.preventDefault();
        });
        
        // Keyboard
        window.addEventListener('keydown', (e) => {
            if (e.key === 'Shift') {
                this.gameState.shiftPressed = true;
            }
        });
        
        window.addEventListener('keyup', (e) => {
            if (e.key === 'Shift') {
                this.gameState.shiftPressed = false;
            }
            if (e.key === 'Escape') {
                this.gameState.clearSelection();
            }
        });
    }
    
    handleLeftClick(x: number, y: number) {
        const worldPos = this.gameState.screenToWorld(x, y);
        
        // Find unit under cursor
        const units = this.gameState.world.getEntitiesWith('unitData');
        let clickedUnit: Entity | null = null;
        let minDist = Infinity;
        
        for (const unit of units) {
            if (!unit.transform) continue;
            
            const dist = unit.transform.position.distanceTo(worldPos);
            if (dist < 20 * FP_SCALE && dist < minDist) {
                minDist = dist;
                clickedUnit = unit;
            }
        }
        
        if (clickedUnit) {
            this.gameState.selectEntity(clickedUnit, this.gameState.shiftPressed);
        } else if (!this.gameState.shiftPressed) {
            this.gameState.clearSelection();
        }
    }
    
    handleRightClick(x: number, y: number) {
        const worldPos = this.gameState.screenToWorld(x, y);
        
        // Check if clicked on enemy
        const units = this.gameState.world.getEntitiesWith('unitData');
        let clickedEnemy: Entity | null = null;
        let minDist = Infinity;
        
        for (const unit of units) {
            if (!unit.transform || this.gameState.selectedEntities.has(unit.id)) continue;
            
            const dist = unit.transform.position.distanceTo(worldPos);
            if (dist < 20 * FP_SCALE && dist < minDist) {
                minDist = dist;
                clickedEnemy = unit;
            }
        }
        
        // Command selected units
        for (const id of this.gameState.selectedEntities) {
            const unit = this.gameState.world.entities.get(id);
            if (!unit || !unit.unitData || !unit.target) continue;
            
            if (clickedEnemy) {
                // Attack command
                unit.target.entityId = clickedEnemy.id;
                unit.unitData.state = EntityState.ATTACKING;
                unit.target.path = this.gameState.pathfinder.findPath(
                    unit.transform!.position,
                    clickedEnemy.transform!.position
                );
            } else {
                // Move command
                unit.target.position = worldPos;
                unit.target.entityId = null;
                unit.unitData.state = EntityState.MOVING;
                unit.target.path = this.gameState.pathfinder.findPath(
                    unit.transform!.position,
                    worldPos
                );
            }
        }
    }
    
    start() {
        if (this.isRunning) return;
        this.isRunning = true;
        this.loop();
    }
    
    stop() {
        this.isRunning = false;
        cancelAnimationFrame(this.animationId);
    }
    
    loop() {
        if (!this.isRunning) return;
        
        const now = performance.now();
        
        // Fixed 60 FPS update
        this.gameState.update();
        
        // Render
        this.renderer.render();
        
        this.gameState.lastUpdateTime = now;
        
        this.animationId = requestAnimationFrame(() => this.loop());
    }
}

// Initialize game
const game = new Game();

// Export for HMR
if (import.meta.hot) {
    import.meta.hot.accept(() => {
        console.log('Hot reload accepted');
    });
}
