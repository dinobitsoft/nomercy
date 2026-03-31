---
name: flutter-game-dev
description: >
  Implement 2D mobile games using Flutter and the Flame game engine. Use this skill whenever the
  user is building a game in Flutter/Dart, working with Flame components, implementing game physics,
  character movement, collision detection, sprite animations, game state machines, AI/bot behavior,
  projectile systems, platform collision, camera systems, infinite world/chunk systems, wave spawning,
  event bus architecture, gamepad/controller input, or any Flame-specific pattern. Also trigger for
  questions about structuring a Flutter game project into modules (core/engine/ui/service packages),
  performance optimization in Flame, or integrating Flutter widgets with Flame game canvas.
---

# Flutter / Flame Game Development Skill

You are an expert Flutter game developer specializing in the Flame engine. You write clean,
performant, well-structured Dart code for 2D mobile action games.

## Project Architecture

Structure games as a multi-module Flutter workspace:

```
game_root/
├── lib/main.dart              # App entry point
├── pubspec.yaml               # Root dependencies
└── modules/
    ├── core/                  # Models, events, config, utilities
    ├── engine/                # Game logic, components, systems
    ├── ui/                    # Flutter screens, HUD, menus
    ├── service/               # Audio, achievements, analytics
    └── gamepad/               # Controller input abstraction
```

**Module dependency rules:**
- `core` → no game dependencies (pure Dart)
- `engine` → depends on `core`, `gamepad`
- `ui` → depends on `engine`, `service`, `gamepad`
- `service` → depends on `core`
- `gamepad` → depends on `core`

---

## Key Dependencies

```yaml
flame: ^1.17.0
flame_forge2d: ^0.17.0
flame_audio: ^2.11.12
socket_io_client: ^2.0.3
gamepads: ^0.1.9
font_awesome_flutter: ^10.7.0
```
 
---

## Core Patterns

### FlameGame Setup
```dart
class ActionGame extends FlameGame
    with HasCollisionDetection, TapCallbacks, KeyboardEvents {
  
  @override
  Future<void> onLoad() async {
    camera.viewfinder.zoom = 1.2;
    camera.viewfinder.visibleGameSize = Vector2(1280, 720);
    camera.viewfinder.anchor = Anchor(0.5, 0.75); // player slightly below center
    
    // Add joystick to viewport (not world — stays fixed on screen)
    final joystick = JoystickComponent(
      knob: CircleComponent(radius: 25, paint: Paint()..color = Colors.white.withOpacity(0.5)),
      background: CircleComponent(radius: 50, paint: Paint()..color = Colors.white.withOpacity(0.1)),
      margin: const EdgeInsets.only(left: 40, bottom: 40),
    );
    camera.viewport.add(joystick);
  }
}
```

### GameCharacter Base Pattern
```dart
abstract class GameCharacter extends SpriteAnimationComponent
    with HasGameReference<ActionGame> {
 
  final String uniqueId;
  final GameCharacterState characterState = GameCharacterState();
  
  // Strategy pattern for per-class behavior
  ActionStrategy  get actionStrategy;
  MovementStrategy get movementStrategy;
  
  Vector2 velocity = Vector2.zero();
  bool facingRight = true;
  bool isDead = false;
 
  @override
  void update(double dt) {
    super.update(dt);
    if (characterState.health <= 0) { velocity = Vector2.zero(); return; }
    
    _updateTimers(dt);
    _handleStates(dt);
    
    if (playerType == PlayerType.human) updateHumanControl(dt);
    else updateBotControl(dt);
    
    applyPhysics(dt);
    _updateAnimation();
  }
 
  @override
  void render(Canvas canvas) {
    if (isDead) return; // Critical: skip render immediately on death
    super.render(canvas);
  }
}
```
 
---

## Physics Implementation

### Platform Collision (Manual AABB)
```dart
void applyPhysics(double dt) {
  // Gravity
  if (characterState.groundPlatform == null) {
    velocity.y = math.min(velocity.y + gravity * dt, maxFallSpeed);
  }
  
  // Ground friction
  if (characterState.groundPlatform != null) {
    velocity.x *= characterState.isLanding ? 0.70 : 0.85;
    if (velocity.x.abs() < 5.0) velocity.x = 0;
  }
  
  final proposed = position + velocity * dt;
  GamePlatform? newGround;
  
  for (final p in game.platforms) {
    final pL = p.position.x - p.size.x / 2;
    final pR = p.position.x + p.size.x / 2;
    final pT = p.position.y - p.size.y / 2;
    
    // Only check platforms in horizontal range
    if (proposed.x + size.x/2 <= pL || proposed.x - size.x/2 >= pR) continue;
    
    final dist = (proposed.y + size.y/2) - pT;
    // Land only when falling, within detection range
    if (velocity.y >= 0 && dist > -4 && dist < 15.0) {
      position.y = pT - size.y / 2;
      velocity.y = 0;
      newGround = p;
      break;
    }
  }
  
  if (newGround == null) position.add(velocity * dt);
  else position.x += velocity.x * dt;
  
  characterState.groundPlatform = newGround;
}
```

### Jump Implementation
```dart
void performJump({double? customPower}) {
  final grounded = characterState.groundPlatform != null;
  
  // Ground jump
  if (grounded && characterState.stamina >= 20) {
    velocity.y = customPower ?? jumpPower; // jumpPower is negative (up)
    characterState
      ..groundPlatform = null
      ..stamina -= 20
      ..isJumping = true
      ..isAirborne = true
      ..hasDoubleJumped = false;
    return;
  }
  
  // Double jump (airborne, not yet doubled)
  if (!grounded && characterState.isAirborne && 
      characterState.canDoubleJump && 
      !characterState.hasDoubleJumped &&
      characterState.stamina >= 20) {
    velocity.y = (customPower ?? jumpPower) * 0.85;
    characterState
      ..stamina -= 20
      ..hasDoubleJumped = true
      ..jumpAnimationTimer = 0.3;
  }
}
```
 
---

## Animation System

### Loading Animations from Asset Paths
```dart
Future<SpriteAnimation?> loadAnim(
  FlameGame game, String charName, String animType, {
  required double stepTime,
  required bool loop,
  SpriteAnimation? fallback,
}) async {
  try {
    final entry = AssetPaths.characterSprites[charName]?[animType];
    
    if (entry is List<dynamic> && entry.isNotEmpty) {
      final frames = <Sprite>[];
      for (final path in entry) {
        frames.add(Sprite(await game.images.load(path as String)));
      }
      return SpriteAnimation.spriteList(frames, stepTime: stepTime, loop: loop);
    }
    
    // Single image fallback
    final img = await game.images.load('${charName}_$animType.png');
    return SpriteAnimation.spriteList([Sprite(img)], stepTime: stepTime, loop: loop);
  } catch (_) {
    return fallback;
  }
}
```

### Dynamic Attack Animation (Duration-Driven)
```dart
// stepTime calculated from total duration / frame count
Future<SpriteAnimation?> loadAnimDynamic(
  FlameGame game, String charName, String animType, {
  required double totalDuration,
  required bool loop,
  SpriteAnimation? fallback,
}) async {
  final frames = await loadFrameSequence(game, charName, animType);
  final stepTime = totalDuration / frames.length;
  return SpriteAnimation.spriteList(frames, stepTime: stepTime, loop: loop);
}
```

### State Machine for Animations
```dart
// Priority-ordered state evaluation
CharacterAnimState evaluateState(GameCharacterState cs) {
  if (cs.health <= 0)                               return CharacterAnimState.dead;
  if (cs.isStunned)                                 return CharacterAnimState.stunned;
  if (cs.isAttacking && cs.attackAnimationTimer > 0.01) return CharacterAnimState.attacking;
  if (cs.isDodging   && cs.dodgeDuration > 0.01)    return CharacterAnimState.dodging;
  if (cs.isLanding   && cs.landingAnimationTimer > 0.01) return CharacterAnimState.landing;
  if (cs.isBlocking)                                return CharacterAnimState.blocking;
  if (!cs.wasGrounded || cs.velocity.y < -100) {
    return cs.velocity.y < 0 ? CharacterAnimState.jumping : CharacterAnimState.falling;
  }
  if (cs.wasGrounded && cs.velocity.x.abs() > 15)  return CharacterAnimState.walking;
  return CharacterAnimState.idle;
}
```
 
---

## Event Bus Architecture

### Singleton Event Bus
```dart
class EventBus {
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  
  final Map<Type, List<_EventListener>> _listeners = {};
  
  EventSubscription on<T extends GameEvent>(
    EventCallback<T> callback, {
    ListenerPriority priority = ListenerPriority.normal,
    bool once = false,
  }) {
    final type = T;
    final listener = _EventListener(
      id: '${type}_${DateTime.now().millisecondsSinceEpoch}',
      callback: (event) { if (event is T) callback(event); },
      priority: priority,
      once: once,
    );
    _listeners.putIfAbsent(type, () => []);
    _listeners[type]!.add(listener);
    _listeners[type]!.sort((a, b) => b.priority.value.compareTo(a.priority.value));
    return EventSubscription._(() => _unsubscribe<T>(listener.id));
  }
  
  void emit<T extends GameEvent>(T event) {
    final listeners = _listeners[event.runtimeType];
    if (listeners == null) return;
    final copy = List<_EventListener>.from(listeners);
    for (final l in copy) {
      l.callback(event);
      if (l.once) listeners.remove(l);
    }
  }
}
```

### Game Events Pattern
```dart
abstract class GameEvent {
  final DateTime timestamp = DateTime.now();
}
 
class CharacterKilledEvent extends GameEvent {
  final String victimId;    // Use uniqueId, NOT stats.name (names repeat!)
  final String? killerId;
  final int bountyGold;
  final Vector2 deathPosition;
  final bool shouldDropLoot;
  CharacterKilledEvent({required this.victimId, ...});
}
```

**Critical:** Always use `uniqueId` for character identification, never `stats.name`.
 
---

## Character Registry & Death Handling

```dart
// In ActionGame
final Map<String, GameCharacter> characterRegistry = {};
 
void registerCharacter(GameCharacter character) {
  characterRegistry[character.uniqueId] = character;
}
 
void _handleEnemyDeath(GameCharacter enemy, CharacterKilledEvent event) {
  // 1. Mark dead FIRST — render() returns early this frame
  enemy.isDead = true;
  
  // 2. Remove from tracking lists
  enemies.remove(enemy);
  characterRegistry.remove(enemy.uniqueId);
  
  // 3. Remove from world ONCE (not removeFromParent + world.remove)
  if (enemy.isMounted) world.remove(enemy);
  
  // 4. Award gold, drop loot
  character.stats.money += event.bountyGold;
  if (event.shouldDropLoot) itemSystem.dropLoot(event.deathPosition);
}
```
 
---

## Infinite World / Chunk System

```dart
class InfiniteWorldSystem {
  static const double chunkWidth = 2400.0;
  static const int activeChunks = 5;
  
  final Map<int, WorldChunk> _activeChunks = {};
  final List<WorldChunk> _chunkPool = []; // Object pool for reuse
  
  void update(double dt, Vector2 playerPosition) {
    final chunkIndex = (playerPosition.x / chunkWidth).floor();
    if (chunkIndex != _currentChunkIndex) {
      _onChunkTransition(chunkIndex);
      _currentChunkIndex = chunkIndex;
    }
    _updateCulling(playerPosition);
  }
  
  void _onChunkTransition(int newIndex) {
    // Generate ahead
    for (int i = newIndex - 2; i <= newIndex + 2; i++) _generateChunk(i);
    // Recycle far chunks
    _unloadDistantChunks(newIndex);
  }
  
  void _recycleChunk(WorldChunk chunk) {
    // Remove ONLY floating platforms — infinite ground strip is never recycled
    for (final p in chunk.platforms) {
      p.removeFromParent();
      game.platforms.remove(p);
    }
    chunk.platforms.clear();
    chunk.waveSpawned = false;
    _chunkPool.add(chunk); // Back to pool
  }
}
```

### Infinite Ground Strip (Tile-Based)
```dart
class TiledGroundComponent extends GamePlatform {
  // IMPORTANT: anchor = Anchor.center
  // All render math assumes (0,0) is component centre
  
  @override
  void update(double dt) {
    // Follow player + all enemies
    double leftmost = game.character.position.x;
    double rightmost = game.character.position.x;
    for (final enemy in game.enemies) {
      if (!enemy.isMounted) continue;
      leftmost = math.min(leftmost, enemy.position.x);
      rightmost = math.max(rightmost, enemy.position.x);
    }
    position.x = (leftmost + rightmost) / 2;
    size.x = (rightmost - leftmost).abs() + 2400.0; // _sidePad both sides
  }
}
```
 
---

## Bot AI Pattern

```dart
class SmartBotAI {
  // Call at configurable interval (not every frame) for realism
  double lastDecisionTime = 0;
  final double reactionTime; // 0.10–0.25s per personality
  
  void executeAI(GameCharacter bot, GameCharacter target, double dt) {
    if (bot.characterState.health <= 0) { bot.velocity = Vector2.zero(); return; }
    if (target.characterState.health <= 0) { currentState = BotState.idle; return; }
    
    lastDecisionTime += dt;
    if (lastDecisionTime >= reactionTime) {
      final decision = makeDecision(bot, target, bot.game.projectiles);
      _executeDecision(bot, target, decision, dt);
      lastDecisionTime = 0;
    }
    
    // Always check immediate threats every frame
    _handleImmediateThreats(bot, target, dt);
  }
  
  // Priority scoring — pick highest priority action
  BotDecision makeDecision(bot, target, projectiles) {
    final decisions = [
      _evaluateAttack(bot, target, ...),
      _evaluateDefend(bot, target, ...),
      _evaluateReposition(bot, target, ...),
      _evaluateEvade(bot, target, projectiles, ...),
      _evaluateJumpAttack(bot, target, ...),
    ];
    decisions.sort((a, b) => b.priority.compareTo(a.priority));
    return decisions.first;
  }
}
```
 
---

## Platform Rendering

### Platform Factory Pattern
```dart
class PlatformFactory {
  PlatformQuality quality = PlatformQuality.high;
  
  GamePlatform createPlatform({
    required Vector2 position,
    required Vector2 size,
    required String platformType,
    int priority = 10,
  }) {
    return switch (quality) {
      PlatformQuality.ultra    => EnhancedPlatform(useOverlay: true,  useShadow: true,  ...),
      PlatformQuality.high     => EnhancedPlatform(useOverlay: true,  useShadow: true,  ...),
      PlatformQuality.medium   => EnhancedPlatform(useOverlay: true,  useShadow: false, ...),
      PlatformQuality.low      => EnhancedPlatform(useOverlay: false, useShadow: false, ...),
      PlatformQuality.performance => TiledPlatform(...),
    };
  }
}
```
 
---

## Weapon System

### Weapon Equip with Stats Transfer
```dart
Future<void> equipWeapon(Weapon? weapon) async {
  // Remove old bonuses
  if (_equippedWeapon != null) {
    final old = _equippedWeapon!;
    stats..power -= old.powerBonus..magic -= old.magicBonus
        ..dexterity -= old.dexterityBonus..attackDamage -= old.damage;
  }
  
  _equippedWeapon = weapon;
  
  if (weapon != null) {
    stats..power += weapon.powerBonus..magic += weapon.magicBonus
        ..dexterity += weapon.dexterityBonus..attackDamage += weapon.damage
        ..attackRange = weapon.range..weaponName = weapon.name;
    
    // Rebuild attack animation for new weapon duration
    if (spritesLoaded) {
      attackAnimation = await _buildAttackAnim(
        stats.name.toLowerCase(),
        weapon.attackDurationOverride ?? actionStrategy.attackDuration,
      );
    }
  }
}
```
 
---

## Gamepad Input

### Gamepad Manager Key Points
```dart
class GamepadManager extends Component with KeyboardHandler {
  // Analog stick with deadzone
  double _dz(double v, {double t = 0.12}) => v.abs() < t ? 0.0 : v;
  
  // Compound input: gamepad OR hardware keyboard OR on-screen joystick
  Vector2 get joystickDelta {
    if (_analog.length > 0.12) return _analog;      // Physical gamepad
    if (_hwDpad.length > 0.10) return _hwDpad;      // Arrow keys / game buttons
    return _kbStick;                                  // WASD
  }
  
  bool get isJumpPressed   => _sJump || _hwJump || _kbJump || isStickUp;
  bool get isAttackPressed => _sAttack || _hwAttack || _kbAttack;
  
  // Edge detection for just-pressed
  bool isDodgeJustPressed() => _edge(isDodgePressed, _pDodge, (v) => _pDodge = v);
  bool _edge(bool cur, bool prev, void Function(bool) set) {
    final j = cur && !prev; set(cur); return j;
  }
}
```
 
---

## Performance Guidelines

| Concern | Guideline |
|---------|-----------|
| Platform collision | Manual AABB loop, NOT Flame collision detection (faster) |
| Object pooling | Pool projectiles (20–100 objects), reuse on fire |
| Chunk culling | Set `priority = -1000` for off-screen platforms |
| Bot AI ticks | 150–200ms intervals, not every frame |
| Spatial hashing | Use `SpatialHashGrid` for O(1) proximity lookups |
| Sprite loading | Load once in `onLoad()`, never in `update()` or `render()` |
| Dead character render | Return immediately if `isDead` — saves all child rendering |
| Max projectiles | Cap at 10 per character |
| Max particles | Cap at 100 globally |
 
---

## Common Pitfalls

```dart
// ❌ Wrong: removes same component twice
world.remove(enemy);
enemy.removeFromParent(); // causes duplicate-removal error
 
// ✅ Correct: one removal
if (enemy.isMounted) world.remove(enemy);
 
// ❌ Wrong: using name for identity (names repeat between instances)
if (event.victimId == game.character.stats.name) ...
 
// ✅ Correct: use uniqueId
if (isPlayerCharacter(victim)) ... // compares uniqueId
 
// ❌ Wrong: adding to both game and world
game.add(projectile);
game.world.add(projectile); // only one should own it
 
// ✅ Correct
game.world.add(projectile);
game.projectiles.add(projectile); // tracking list only
 
// ❌ Wrong: platform on TiledGroundComponent affects infinite strip
for (final p in chunk.platforms) p.removeFromParent();
// (removes ground strip too if it was added to chunk.platforms)
 
// ✅ Correct: never add TiledGroundComponent to chunk.platforms
```
 
---

## Module pubspec.yaml Template

```yaml
name: engine
dependencies:
  flutter: { sdk: flutter }
  flame: ^1.17.0
  flame_audio: ^2.11.12
  socket_io_client: ^2.0.3
  gamepads: ^0.1.9
  core: { path: ../core }   # local modules via path
  gamepad: { path: ../gamepad }
```

## Asset Registration (pubspec.yaml)
```yaml
flutter:
  assets:
    - assets/images/
    - assets/audio/
    - assets/maps/
    - assets/maps/level_1.json
```