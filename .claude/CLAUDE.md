# Project Context: 2D Action Game

## Project Overview
A multiplayer 2D action platformer built with Flutter and Flame game engine, featuring four distinct character classes, real-time combat, and Socket.IO networking for multiplayer gameplay.

## Tech Stack
- **Framework**: Flutter
- **Game Engine**: Flame 1.17.0
- **Physics**: Flame Forge2D 0.17.0
- **Networking**: Socket.IO Client 2.0.3
- **Language**: Dart

## Architecture

### Core Components

#### Character System
- **4 Character Classes**: Knight, Thief, Wizard, Trader
- Each class has unique stats and weapons:
    - **Knight**: High power (15), Sword Slash, close-range (2.0)
    - **Thief**: High dexterity (16), Throwing Knives, medium-range (8.0)
    - **Wizard**: High magic (18), Fireball, long-range (10.0)
    - **Trader**: Balanced stats, Bow & Arrow, longest range (12.0)
- Stats: power, magic, dexterity, intelligence, money
- Stat upgrades cost $50 each, add +5 to chosen stat

#### Game Mechanics
- **Movement**: Joystick-controlled with physics
    - Standard movement based on dexterity stat
    - Jumping (velocity: -300)
    - Crouching (reduces height to 30 from 60)
    - Wall sliding on tall platforms (>100 height)
    - Wall climbing when sliding + up input
- **Combat**:
    - Knight: Melee attacks hitting nearby enemies
    - Other classes: Projectile-based attacks
    - Attack cooldown: 0.5 seconds
    - Damage based on character's attackDamage stat
- **Economy**: Earn $20 per enemy defeated

#### Platform System
- Ground platform spans entire screen width
- 5 floating platforms with staggered heights
- Left and right wall boundaries
- Collision detection for all platforms
- Support for wall sliding/climbing mechanics

### File Structure
```
lib/
├── main.dart           # Core game logic, UI, components
└── network_manager.dart # Multiplayer networking (Socket.IO)

Required Assets:
assets/images/
├── knight.png
├── thief.png
├── wizard.png
├── trader.png
├── knight_attack.png
├── thief_attack.png
├── wizard_attack.png
└── trader_attack.png
```

### Key Classes

#### `ActionGame` (FlameGame)
- Main game controller
- Manages: player, enemies, projectiles, platforms
- Camera follows player with 1.5x zoom
- Tracks enemiesDefeated count
- Game over handling

#### `Player` (SpriteAnimationComponent)
- Health: 100
- Velocity-based movement with gravity (800 dt)
- Sprite animations: idle, walk, attack
- Facing direction tracking
- Platform collision detection
- Damage handling

#### `Enemy` (SpriteAnimationComponent)
- AI follows player within 300 units
- Platform collision and gravity
- Attack when within range (attackRange * 30)
- Health bar rendering
- Attack cooldown: 2.0 seconds

#### `NetworkManager` (Singleton)
- Socket.IO connection management
- Events: join-game, current-players, player-joined, player-moved, player-attacked, player-left
- Handles remote player synchronization
- Methods: connect(), sendPosition(), sendAttack(), disconnect()

## Current State

### Implemented Features
✅ Character selection screen with 4 classes
✅ Character stat display and visual selection
✅ Platform-based physics movement
✅ Joystick controls
✅ Jumping, crouching, wall sliding/climbing
✅ Attack system (melee + projectile)
✅ Enemy AI with pathfinding
✅ Projectile collision detection
✅ Money and kill tracking
✅ HUD with health, money, kills, stats
✅ Sprite loading with fallback to colored rectangles
✅ Network manager structure (Socket.IO)

### Known Issues & TODOs
- ⚠️ Network player position updates commented out (see line 50 in network_manager.dart)
- ⚠️ `_addRemotePlayer()` not implemented
- ⚠️ Remote player attack handling empty
- ⚠️ Server IP placeholder: 'http://YOUR_SERVER_IP:3000'
- ⚠️ No server implementation included
- ⚠️ Stat upgrade buttons in HUD are visual-only (no tap detection)
- ⚠️ Game over state doesn't show UI or reset option

## Development Guidelines

### Adding New Features
1. **New Character Class**:
    - Add to `CharacterClass` enum
    - Create stats in `CharacterStats.fromClass()`
    - Add sprite assets
    - Update selection grid

2. **New Enemy Type**:
    - Extend `Enemy` class or create AI variations
    - Modify spawn logic in `ActionGame.onLoad()`

3. **Multiplayer Setup**:
    - Implement Node.js Socket.IO server
    - Complete `_addRemotePlayer()` method
    - Implement remote player component class
    - Uncomment position update code
    - Add interpolation for smooth remote movement

### Physics Constants
- Gravity: 800 dt
- Max fall speed: 500
- Jump velocity: -300
- Wall slide max velocity: 50
- Projectile speed: 300

### Performance Considerations
- Sprites fall back to colored shapes if loading fails
- Projectiles auto-remove after 3s lifetime
- Camera follows player (reduces off-screen rendering)
- Collision checks use AABB (axis-aligned bounding box)

## Common Tasks

### Testing Without Sprites
The game works without image assets by rendering colored rectangles. Simply run without the assets folder to test core mechanics.

### Adding Server-Side Logic
Required server events to implement:
- `join-game`: Register new player
- `player-move`: Broadcast position updates
- `player-attack`: Broadcast attack actions
- `disconnect`: Remove player from game

### Debugging
- Player sprites not loading: Check asset paths in pubspec.yaml
- Physics issues: Verify platform collision bounds
- Network issues: Check Socket.IO server URL and connection status
- Performance: Monitor projectile/enemy count

## Dependencies to Add
```yaml
dependencies:
  flutter:
    sdk: flutter
  flame: ^1.17.0
  flame_forge2d: ^0.17.0
  socket_io_client: ^2.0.3

flutter:
  assets:
    - assets/images/
```

## Quick Start for Claude
When asked to modify this codebase:
1. Preserve the character stat balance
2. Maintain physics constants for consistent feel
3. Keep collision detection AABB-based (performance)
4. Follow Flame component patterns (PositionComponent, SpriteAnimationComponent)
5. Remember: Y-axis increases downward in Flame
6. Network code should be non-blocking

## Future Enhancement Ideas
- Power-ups and collectibles
- Multiple levels/maps
- Boss enemies
- Skill trees beyond stat upgrades
- Leaderboards
- Team-based modes
- Environmental hazards
- Save/load game state