// pubspec.yaml dependencies:
// dependencies:
//   flutter:
//     sdk: flutter
//   flame: ^1.17.0
//   flame_forge2d: ^0.17.0
//   socket_io_client: ^2.0.3

// main.dart
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/sprite.dart';
import 'dart:math' as math;

void main() {
  runApp(const GameApp());
}

class GameApp extends StatelessWidget {
  const GameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '2D Action Game',
      theme: ThemeData.dark(),
      home: const CharacterSelectionScreen(),
    );
  }
}

// Character Classes
enum CharacterClass { knight, thief, wizard, trader }

class CharacterStats {
  final CharacterClass type;
  double power;
  double magic;
  double dexterity;
  double intelligence;
  int money;
  final String weaponName;
  final double attackRange;
  final double attackDamage;
  final Color color;

  CharacterStats({
    required this.type,
    required this.power,
    required this.magic,
    required this.dexterity,
    required this.intelligence,
    this.money = 100,
    required this.weaponName,
    required this.attackRange,
    required this.attackDamage,
    required this.color,
  });

  factory CharacterStats.fromClass(CharacterClass type) {
    switch (type) {
      case CharacterClass.knight:
        return CharacterStats(
          type: type,
          power: 15,
          magic: 5,
          dexterity: 8,
          intelligence: 7,
          weaponName: 'Sword Slash',
          attackRange: 2.0,
          attackDamage: 15,
          color: Colors.blue,
        );
      case CharacterClass.thief:
        return CharacterStats(
          type: type,
          power: 8,
          magic: 6,
          dexterity: 16,
          intelligence: 10,
          weaponName: 'Throwing Knives',
          attackRange: 8.0,
          attackDamage: 10,
          color: Colors.green,
        );
      case CharacterClass.wizard:
        return CharacterStats(
          type: type,
          power: 6,
          magic: 18,
          dexterity: 7,
          intelligence: 14,
          weaponName: 'Fireball',
          attackRange: 10.0,
          attackDamage: 20,
          color: Colors.purple,
        );
      case CharacterClass.trader:
        return CharacterStats(
          type: type,
          power: 10,
          magic: 7,
          dexterity: 12,
          intelligence: 11,
          weaponName: 'Bow & Arrow',
          attackRange: 12.0,
          attackDamage: 12,
          color: Colors.orange,
        );
    }
  }

  void upgradeStat(String stat) {
    if (money < 50) return;
    money -= 50;
    switch (stat) {
      case 'power':
        power += 5;
        break;
      case 'magic':
        magic += 5;
        break;
      case 'dexterity':
        dexterity += 5;
        break;
      case 'intelligence':
        intelligence += 5;
        break;
    }
  }
}

// Character Selection Screen
class CharacterSelectionScreen extends StatefulWidget {
  const CharacterSelectionScreen({super.key});

  @override
  State<CharacterSelectionScreen> createState() => _CharacterSelectionScreenState();
}

class _CharacterSelectionScreenState extends State<CharacterSelectionScreen> {
  CharacterClass? selectedClass;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey[900]!, Colors.grey[800]!],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text(
                'Choose Your Character',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  padding: const EdgeInsets.all(20),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: CharacterClass.values.map((charClass) {
                    final stats = CharacterStats.fromClass(charClass);
                    return _buildCharacterCard(charClass, stats);
                  }).toList(),
                ),
              ),
              if (selectedClass != null)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: ElevatedButton(
                    onPressed: () => _startGame(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                    ),
                    child: const Text('START GAME', style: TextStyle(fontSize: 20)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCharacterCard(CharacterClass charClass, CharacterStats stats) {
    final isSelected = selectedClass == charClass;
    return GestureDetector(
      onTap: () => setState(() => selectedClass = charClass),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? stats.color.withOpacity(0.3) : Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? stats.color : Colors.transparent,
            width: 3,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              charClass.name.toUpperCase(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Weapon: ${stats.weaponName}', style: const TextStyle(fontSize: 12)),
            const Spacer(),
            _statRow('Power', stats.power),
            _statRow('Magic', stats.magic),
            _statRow('Dexterity', stats.dexterity),
            _statRow('Intelligence', stats.intelligence),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String name, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(fontSize: 11)),
          Text(value.toInt().toString(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _startGame(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(characterClass: selectedClass!),
      ),
    );
  }
}

// Game Screen
class GameScreen extends StatelessWidget {
  final CharacterClass characterClass;

  const GameScreen({super.key, required this.characterClass});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: ActionGame(characterClass: characterClass),
      ),
    );
  }
}

// Main Game
class ActionGame extends FlameGame with HasCollisionDetection, TapDetector {
  final CharacterClass characterClass;
  late Player player;
  late JoystickComponent joystick;
  final List<Enemy> enemies = [];
  final List<Projectile> projectiles = [];
  final List<Platform> platforms = [];
  int enemiesDefeated = 0;
  bool isGameOver = false;

  ActionGame({required this.characterClass});

  @override
  void onTapDown(TapDownInfo info) {
    super.onTapDown(info);
    // Attack button area (top right)
    final tapPos = info.eventPosition.global;
    final attackButtonPos = Vector2(size.x - 60, 60);
    if (tapPos.distanceTo(attackButtonPos) < 40) {
      attack();
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Set camera zoom for better view
    camera.viewfinder.zoom = 1.5;

    // Create ground
    final ground = Platform(
      position: Vector2(size.x / 2, size.y - 50),
      size: Vector2(size.x, 100),
    );
    add(ground);
    platforms.add(ground);

    // Create platforms for climbing/jumping
    for (int i = 0; i < 5; i++) {
      final platform = Platform(
        position: Vector2(
          100 + i * 150.0,
          size.y - 200 - (i % 2) * 100.0,
        ),
        size: Vector2(120, 20),
      );
      add(platform);
      platforms.add(platform);
    }

    // Create walls
    final leftWall = Platform(
      position: Vector2(10, size.y / 2),
      size: Vector2(20, size.y),
    );
    add(leftWall);
    platforms.add(leftWall);

    final rightWall = Platform(
      position: Vector2(size.x - 10, size.y / 2),
      size: Vector2(20, size.y),
    );
    add(rightWall);
    platforms.add(rightWall);

    // Create player
    player = Player(
      position: Vector2(size.x / 2, size.y - 200),
      stats: CharacterStats.fromClass(characterClass),
      game: this,
    );
    add(player);

    // Create enemies
    for (int i = 0; i < 3; i++) {
      final enemyClass = CharacterClass.values[i % CharacterClass.values.length];
      final enemy = Enemy(
        position: Vector2(200 + i * 200.0, size.y - 200),
        stats: CharacterStats.fromClass(enemyClass),
        player: player,
        game: this,
      );
      add(enemy);
      enemies.add(enemy);
    }

    // Create joystick
    joystick = JoystickComponent(
      knob: CircleComponent(radius: 30, paint: Paint()..color = Colors.white30),
      background: CircleComponent(radius: 60, paint: Paint()..color = Colors.white10),
      margin: const EdgeInsets.only(left: 40, bottom: 40),
    );
    add(joystick);

    // Add HUD
    add(HUD(player: player, game: this));

    // Follow player with camera
    camera.follow(player);
  }

  void attack() {
    player.attack();
  }

  void removeEnemy(Enemy enemy) {
    enemies.remove(enemy);
    enemy.removeFromParent();
    enemiesDefeated++;
    player.stats.money += 20;
  }

  void gameOver() {
    isGameOver = true;
  }
}

// Player Component
class Player extends PositionComponent with HasGameRef<ActionGame> {
  final CharacterStats stats;
  final ActionGame game;
  Vector2 velocity = Vector2.zero();
  double health = 100;
  bool isCrouching = false;
  bool isClimbing = false;
  bool isWallSliding = false;
  double attackCooldown = 0;
  bool facingRight = true;
  Platform? groundPlatform;
  Platform? climbingWall;

  Player({required super.position, required this.stats, required this.game});

  @override
  Future<void> onLoad() async {
    size = Vector2(30, 50);
    anchor = Anchor.center;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (attackCooldown > 0) attackCooldown -= dt;

    // Get joystick input - use relativeDelta for vector values
    final joystickDelta = game.joystick.relativeDelta;
    final joystickDirection = game.joystick.direction;
    final moveSpeed = stats.dexterity / 2;

    // Horizontal movement
    if (joystickDelta.x != 0) {
      velocity.x = joystickDelta.x * moveSpeed * 100;
      facingRight = joystickDelta.x > 0;
    } else {
      velocity.x = 0;
    }

    // Crouching (joystick down)
    isCrouching = joystickDirection == JoystickDirection.down && groundPlatform != null;

    // Check for wall sliding
    isWallSliding = false;
    climbingWall = null;
    for (final platform in game.platforms) {
      if (platform.size.y > 100 && _isNearWall(platform)) {
        isWallSliding = true;
        climbingWall = platform;
        velocity.y = math.min(velocity.y, 50); // Slow fall
        break;
      }
    }

    // Climbing
    if (isWallSliding && joystickDirection == JoystickDirection.up) {
      isClimbing = true;
      velocity.y = -moveSpeed * 3;
    } else {
      isClimbing = false;
    }

    // Jumping
    if (joystickDirection == JoystickDirection.up && groundPlatform != null && !isCrouching) {
      velocity.y = -300;
      groundPlatform = null;
    }

    // Gravity
    if (groundPlatform == null && !isClimbing) {
      velocity.y += 800 * dt;
      velocity.y = math.min(velocity.y, 500);
    }

    // Apply velocity
    position += velocity * dt;

    // Check platform collisions
    groundPlatform = null;
    for (final platform in game.platforms) {
      if (_checkPlatformCollision(platform)) {
        if (velocity.y > 0 && position.y < platform.position.y) {
          // Landing on platform
          position.y = platform.position.y - platform.size.y / 2 - size.y / 2;
          velocity.y = 0;
          groundPlatform = platform;
        } else if (velocity.y < 0 && position.y > platform.position.y) {
          // Hitting platform from below
          position.y = platform.position.y + platform.size.y / 2 + size.y / 2;
          velocity.y = 0;
        }

        // Horizontal collision
        if ((position.x < platform.position.x && velocity.x > 0) ||
            (position.x > platform.position.x && velocity.x < 0)) {
          velocity.x = 0;
          if (position.x < platform.position.x) {
            position.x = platform.position.x - platform.size.x / 2 - size.x / 2;
          } else {
            position.x = platform.position.x + platform.size.x / 2 + size.x / 2;
          }
        }
      }
    }

    // Adjust size when crouching
    size.y = isCrouching ? 25 : 50;

    // Check if dead
    if (health <= 0) {
      game.gameOver();
    }
  }

  bool _checkPlatformCollision(Platform platform) {
    final dx = (position.x - platform.position.x).abs();
    final dy = (position.y - platform.position.y).abs();
    return dx < (size.x + platform.size.x) / 2 &&
        dy < (size.y + platform.size.y) / 2;
  }

  bool _isNearWall(Platform wall) {
    final dx = (position.x - wall.position.x).abs();
    final dy = (position.y - wall.position.y).abs();
    return dx < (size.x + wall.size.x) / 2 + 5 &&
        dy < (size.y + wall.size.y) / 2;
  }

  void attack() {
    if (attackCooldown > 0) return;
    attackCooldown = 0.5;

    if (stats.type == CharacterClass.knight) {
      // Melee attack
      for (final enemy in game.enemies) {
        if (position.distanceTo(enemy.position) < stats.attackRange * 30) {
          enemy.takeDamage(stats.attackDamage);
        }
      }
    } else {
      // Ranged attack
      final projectile = Projectile(
        position: position.clone(),
        direction: facingRight ? Vector2(1, 0) : Vector2(-1, 0),
        damage: stats.attackDamage,
        owner: this,
        color: stats.color,
      );
      game.add(projectile);
      game.projectiles.add(projectile);
    }
  }

  void takeDamage(double damage) {
    health = math.max(0, health - damage);
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = stats.color;
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
      paint,
    );

    // Draw weapon indicator
    final weaponPaint = Paint()..color = Colors.yellow;
    final weaponOffset = facingRight ? Offset(size.x / 2 + 5, 0) : Offset(-size.x / 2 - 5, 0);
    canvas.drawCircle(weaponOffset, 5, weaponPaint);
  }
}

// Enemy Component
class Enemy extends PositionComponent with HasGameRef<ActionGame> {
  final CharacterStats stats;
  final Player player;
  final ActionGame game;
  Vector2 velocity = Vector2.zero();
  double health = 100;
  double attackCooldown = 0;
  Platform? groundPlatform;

  Enemy({
    required super.position,
    required this.stats,
    required this.player,
    required this.game,
  });

  @override
  Future<void> onLoad() async {
    size = Vector2(30, 50);
    anchor = Anchor.center;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (attackCooldown > 0) attackCooldown -= dt;

    // Simple AI: move towards player
    final toPlayer = player.position - position;
    final distance = toPlayer.length;

    if (distance < 300) {
      velocity.x = toPlayer.normalized().x * (stats.dexterity / 3);
    } else {
      velocity.x = 0;
    }

    // Gravity
    if (groundPlatform == null) {
      velocity.y += 800 * dt;
      velocity.y = math.min(velocity.y, 500);
    }

    // Apply velocity
    position += velocity * dt;

    // Check platform collisions
    groundPlatform = null;
    for (final platform in game.platforms) {
      if (_checkPlatformCollision(platform)) {
        if (velocity.y > 0 && position.y < platform.position.y) {
          position.y = platform.position.y - platform.size.y / 2 - size.y / 2;
          velocity.y = 0;
          groundPlatform = platform;
        }
      }
    }

    // Attack player if close
    if (distance < stats.attackRange * 30 && attackCooldown <= 0) {
      player.takeDamage(stats.attackDamage / 2);
      attackCooldown = 2.0;
    }
  }

  bool _checkPlatformCollision(Platform platform) {
    final dx = (position.x - platform.position.x).abs();
    final dy = (position.y - platform.position.y).abs();
    return dx < (size.x + platform.size.x) / 2 &&
        dy < (size.y + platform.size.y) / 2;
  }

  void takeDamage(double damage) {
    health -= damage;
    if (health <= 0) {
      game.removeEnemy(this);
    }
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = stats.color.withOpacity(0.7);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
      paint,
    );

    // Health bar
    final healthBarWidth = size.x;
    final healthPercent = health / 100;
    canvas.drawRect(
      Rect.fromLTWH(-size.x / 2, -size.y / 2 - 10, healthBarWidth, 5),
      Paint()..color = Colors.red,
    );
    canvas.drawRect(
      Rect.fromLTWH(-size.x / 2, -size.y / 2 - 10, healthBarWidth * healthPercent, 5),
      Paint()..color = Colors.green,
    );
  }
}

// Platform Component
class Platform extends PositionComponent {
  Platform({required super.position, required super.size}) {
    anchor = Anchor.center;
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = Colors.brown;
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
      paint,
    );
  }
}

// Projectile Component
class Projectile extends PositionComponent with HasGameRef<ActionGame> {
  final Vector2 direction;
  final double damage;
  final Player owner;
  final Color color;
  double lifetime = 3.0;

  Projectile({
    required super.position,
    required this.direction,
    required this.damage,
    required this.owner,
    required this.color,
  }) {
    size = Vector2(10, 10);
    anchor = Anchor.center;
  }

  @override
  void update(double dt) {
    super.update(dt);

    position += direction * 300 * dt;
    lifetime -= dt;

    // Check enemy collisions
    for (final enemy in game.enemies) {
      if (position.distanceTo(enemy.position) < 30) {
        enemy.takeDamage(damage);
        removeFromParent();
        game.projectiles.remove(this);
        return;
      }
    }

    // Check platform collisions
    for (final platform in game.platforms) {
      final dx = (position.x - platform.position.x).abs();
      final dy = (position.y - platform.position.y).abs();
      if (dx < (size.x + platform.size.x) / 2 &&
          dy < (size.y + platform.size.y) / 2) {
        removeFromParent();
        game.projectiles.remove(this);
        return;
      }
    }

    if (lifetime <= 0) {
      removeFromParent();
      game.projectiles.remove(this);
    }
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = color;
    canvas.drawCircle(Offset.zero, 5, paint);
  }
}

// HUD Component
class HUD extends PositionComponent with HasGameRef<ActionGame> {
  final Player player;
  final ActionGame game;

  HUD({required this.player, required this.game}) {
    priority = 100;
  }

  @override
  void render(Canvas canvas) {
    // Background
    canvas.drawRect(
      const Rect.fromLTWH(10, 10, 250, 140),
      Paint()..color = Colors.black.withOpacity(0.7),
    );

    // Text style
    const textStyle = TextStyle(color: Colors.white, fontSize: 14);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Health
    textPainter.text = TextSpan(text: 'HP: ${player.health.toInt()}', style: textStyle);
    textPainter.layout();
    textPainter.paint(canvas, const Offset(20, 20));

    // Health bar
    canvas.drawRect(
      const Rect.fromLTWH(20, 45, 200, 15),
      Paint()..color = Colors.red,
    );
    canvas.drawRect(
      Rect.fromLTWH(20, 45, 200 * (player.health / 100), 15),
      Paint()..color = Colors.green,
    );

    // Money
    textPainter.text = TextSpan(text: 'Money: \$${player.stats.money}', style: textStyle);
    textPainter.layout();
    textPainter.paint(canvas, const Offset(20, 70));

    // Kills
    textPainter.text = TextSpan(text: 'Kills: ${game.enemiesDefeated}', style: textStyle);
    textPainter.layout();
    textPainter.paint(canvas, const Offset(20, 95));

    // Controls hint
    textPainter.text = const TextSpan(text: 'Tap screen to attack', style: TextStyle(color: Colors.yellow, fontSize: 12));
    textPainter.layout();
    textPainter.paint(canvas, const Offset(20, 120));

    // Attack button (top right)
    canvas.drawCircle(
      Offset(game.size.x - 60, 60),
      40,
      Paint()..color = Colors.red.withOpacity(0.5),
    );
    textPainter.text = const TextSpan(text: 'ATK', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold));
    textPainter.layout();
    textPainter.paint(canvas, Offset(game.size.x - 80, 52));
  }

  @override
  void update(double dt) {
    super.update(dt);
    position = -game.camera.viewfinder.position + Vector2(0, 0);
  }
}