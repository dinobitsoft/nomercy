---
name: game-design
description: Design and implement game features for this Flutter/Flame 2D action platformer. Use when asked to add characters, AI tactics, map styles, combat mechanics, enemies, game modes, or any gameplay system.
allowed-tools: Read Grep Edit Write Glob Bash TodoWrite
argument-hint: [feature to design — e.g. "new character Ranger", "new map style Swamp", "new AI tactic Coward"]
---

# Game Design Skill

Design and implement `$ARGUMENTS` for this Flutter/Flame 2D action platformer.

## Project Context

- **Engine**: Flame 1.x on Flutter 3.x, Dart
- **Key files**:
  - `lib/game/game_character.dart` — abstract base for all characters
  - `lib/game/bot_tactic.dart` — AI tactic interface
  - `lib/game/tactic/bot_ai_system.dart` — SmartBotAI decision engine
  - `lib/game/character/` — Knight, Thief, Wizard, Trader
  - `lib/game/stat/stats.dart` — CharacterStats subclasses
  - `lib/procedural/map_generator_core.dart` — ProceduralMapGenerator
  - `lib/map/map_loader.dart` — MapLoader factory methods
  - `lib/game_manager.dart` — wave/boss/difficulty management
  - `lib/action_game.dart` — main game, `_createCharacter()` factory
  - `lib/projectile.dart` — Projectile entity

## Workflow

1. **Understand the request** — identify which system(s) are involved (character, AI, map, combat, mode).
2. **Read relevant files** — read every file you will modify before touching it.
3. **Plan** — list files to create/edit, draft the design (stats, formulas, behavior), then check with the user if the scope is large.
4. **Implement** — follow the patterns below exactly; do not invent new patterns.
5. **Wire up** — register the new thing in all switch/factory points so it is reachable from the game.
6. **Report** — print a summary table of every file changed and what was added/changed.

---

## Pattern: New Character Class

### 1. Stats (edit `lib/game/stat/stats.dart`)

Add a new `XxxStats` class extending `CharacterStats`:

```dart
class RangerStats extends CharacterStats {
  RangerStats() : super(
    name: 'Ranger',
    power: 10,
    magic: 6,
    dexterity: 14,
    intelligence: 10,
    weaponName: 'Short Bow',
    attackRange: 11.0,
    attackDamage: 13,
    color: Colors.green,
  );
}
```

**Stat balance guide**:
| Role | Power | Dex | Magic | Atk Dmg | Atk Range |
|------|-------|-----|-------|---------|-----------|
| Tank (melee) | 14-16 | 7-9 | 4-6 | 14-16 | 1.5-2.5 |
| Agile (melee) | 8-10 | 15-17 | 5-7 | 9-12 | 1.5-3.0 |
| Ranged (mid) | 9-11 | 12-15 | 6-8 | 11-14 | 8-12 |
| Mage (ranged) | 5-7 | 6-8 | 17-20 | 18-22 | 9-12 |

### 2. Character class (create `lib/game/character/xxx.dart`)

```dart
import 'package:flame/components.dart';
import '../game_character.dart';
import '../bot_tactic.dart';
import '../../player_type.dart';
import '../../projectile.dart';
import '../stat/stats.dart';
import '../tactic/tactical_tactic.dart';

class Ranger extends GameCharacter {
  Ranger({
    required super.position,
    required super.playerType,
    BotTactic? botTactic,
  }) : super(
    botTactic: botTactic ?? TacticalTactic(),
    stats: RangerStats(),
  );

  @override
  void updateHumanControl(double dt) {
    // identical movement logic to existing characters — copy from Trader
  }

  @override
  void updateBotControl(double dt) {
    if (botTactic != null) {
      botTactic!.execute(this, game.player, dt);
    }
  }

  @override
  void attack() {
    if (!prepareAttack()) return;
    // For melee: call super or use hitbox check
    // For ranged: spawn a Projectile
    final dir = facingRight ? Vector2(1, 0) : Vector2(-1, 0);
    final proj = Projectile(
      position: position.clone()..add(Vector2(facingRight ? 40 : -40, 0)),
      direction: dir,
      damage: stats.attackDamage.toDouble(),
      speed: 500,
      owner: playerType == PlayerType.human ? this : null,
      enemyOwner: playerType == PlayerType.bot ? this : null,
      color: stats.color,
      type: 'arrow',
    );
    game.add(proj);
    game.projectiles.add(proj);
  }
}
```

### 3. Register in factory (edit `lib/action_game.dart`)

Find `_createCharacter()` and add a case:

```dart
case 'ranger':
  return Ranger(
    position: position,
    playerType: playerType,
    botTactic: botTactic,
  );
```

### 4. Expose in character selection (edit `lib/character_selection_screen.dart`)

Add the new character name/display to the available characters list — follow the existing pattern for Knight/Thief/Wizard/Trader.

---

## Pattern: New AI Tactic

### 1. Add personality to enum (edit `lib/game/tactic/bot_ai_system.dart`)

```dart
enum BotPersonality {
  aggressive, defensive, balanced, tactical, berserker,
  coward,  // NEW
}
```

### 2. Add personality params to `_initializePersonality()` (same file)

```dart
case BotPersonality.coward:
  aggressionLevel = 0.15;
  cautionLevel = 0.95;
  staminaReserve = 50;
  optimalRange = 500;
  retreatThreshold = 60;   // starts retreating at 60% HP
  reactionTime = 0.25;
  break;
```

**Personality param guide**:
| Param | Range | Meaning |
|-------|-------|---------|
| aggressionLevel | 0.0-1.0 | Probability weight toward attacking |
| cautionLevel | 0.0-1.0 | Probability weight toward defending/retreating |
| staminaReserve | 10-60 | Min stamina before attacking |
| optimalRange | 100-600 | Preferred distance to target (px) |
| retreatThreshold | 0-80 | HP% at which bot starts retreating |
| reactionTime | 0.08-0.30 | Seconds between AI decisions |

### 3. Create tactic file (create `lib/game/tactic/coward_tactic.dart`)

```dart
import '../game_character.dart';
import '../bot_tactic.dart';
import '../../projectile.dart';
import 'bot_ai_system.dart';

class CowardTactic implements BotTactic {
  final SmartBotAI _ai = SmartBotAI(
    name: 'Coward',
    personality: BotPersonality.coward,
  );

  @override
  String get name => _ai.name;

  @override
  void execute(GameCharacter bot, GameCharacter target, double dt) {
    _ai.executeAI(bot, target, dt);
    // Add any tactic-specific overrides here
  }

  @override
  bool shouldEvade(GameCharacter bot, List<Projectile> projectiles) {
    return projectiles.isNotEmpty; // always evade
  }

  @override
  void onDamageTaken(GameCharacter bot, double damage) {
    _ai.onDamageTaken(bot, damage);
  }
}
```

---

## Pattern: New Map Style

### 1. Add to enum (edit `lib/procedural/map_generator_core.dart`)

```dart
enum MapStyle {
  arena, platformer, dungeon, towers, chaos, balanced,
  swamp, // NEW
}
```

### 2. Add case to `_generatePlatforms()` switch (same file)

```dart
case MapStyle.swamp:
  _generateSwamp();
  break;
```

### 3. Implement generation method (same file)

```dart
void _generateSwamp() {
  // Ground
  platforms.add(GeneratedPlatform(
    position: Vector2(0, config.height - 50),
    size: Vector2(config.width, 50),
    type: 'ground',
    layer: 0,
  ));

  // Scattered mid-level islands (uneven heights for swamp feel)
  final clusterCount = 4 + random.nextInt(3);
  for (int i = 0; i < clusterCount; i++) {
    final clusterX = (config.width / clusterCount) * i + random.nextDouble() * 200;
    final baseY = config.height - 200 - random.nextDouble() * 250;
    // 2-3 platforms per cluster at slightly different heights
    final platformsInCluster = 2 + random.nextInt(2);
    for (int j = 0; j < platformsInCluster; j++) {
      platforms.add(GeneratedPlatform(
        position: Vector2(
          clusterX + j * (120 + random.nextDouble() * 60),
          baseY + random.nextDouble() * 80 - 40,
        ),
        size: Vector2(_getPlatformWidth() * 0.8, 30),
        type: 'brick',
        layer: i,
      ));
    }
  }
}
```

**Layout guide**:
| Style | Ground | Platform count | Vertical spread |
|-------|--------|---------------|-----------------|
| Arena | Wide (90%) | 3-6 sparse | Low (1-2 layers) |
| Platformer | Full | 12-20 | High (4 layers) |
| Dungeon | Room floors | 8-14 | Medium rooms |
| Towers | Thin base | 15-25 vertical | Very high |
| Chaos | Full | 10-18 random | Full |
| Balanced | Full | 9-12 structured | 3 layers |

### 4. Expose in map selection (edit `lib/map_selection_screen.dart`)

Add the new style to the displayed options, following the existing pattern.

---

## Pattern: New Combat Mechanic

Before implementing, read `lib/game/game_character.dart` fully to understand:
- `stamina` / `maxStamina` management
- `isAttacking`, `isBlocking`, `isDodging`, `isStunned`, `isAirborne` flags
- `takeDamage()` flow

Key rules:
- Every action that costs stamina must check `stamina >= cost` first.
- Set a flag (e.g., `isParrying`) immediately when the action starts; clear it in the update loop after the duration elapses.
- Invincibility windows are enforced by checking the relevant flag in `takeDamage()`.
- New timers use `double _xxxTimer = 0` incremented each `update(dt)`.

---

## Pattern: New Game Mode

1. Add to `GameMode` enum in `lib/game_manager.dart`.
2. Add handling in `GameManager.update()` for the new mode's wave/spawn logic.
3. Add a case in `lib/mode_selection_screen.dart` to display and route to the new mode.
4. Pass the new `GameMode` through `GameScreen` → `ActionGame` → `GameManager`.

---

## Checklist before finishing

- [ ] All modified files were read before editing.
- [ ] New class is registered in every factory/switch that needs it.
- [ ] Stats are balanced relative to existing characters (no outliers unless intentional).
- [ ] No new public API added that isn't used immediately.
- [ ] No print statements left in production paths.
- [ ] No Flutter/Dart lints introduced (no unused imports, no `dynamic` without reason).

## Output format

```
## Game Design Implementation

| File | Change |
|------|--------|
| lib/game/stat/stats.dart | Added RangerStats |
| lib/game/character/ranger.dart | Created Ranger class |
| lib/action_game.dart | Registered 'ranger' in _createCharacter() |
| lib/character_selection_screen.dart | Added Ranger to selection UI |
```
