import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nomercy/gamepad_manager.dart';
import 'package:nomercy/player.dart';
import 'package:nomercy/projectile.dart';
import 'package:nomercy/tiled_platform.dart';

import 'character_class.dart';
import 'character_stats.dart';
import 'chest/chest.dart';
import 'enemy.dart';
import 'hud.dart';
import 'map/map_loader.dart';

class ActionGame extends FlameGame with HasCollisionDetection, TapDetector, KeyboardEvents {
  final CharacterClass characterClass;
  final String mapName;
  late Player player;
  late JoystickComponent joystick;
  final GamepadManager gamepadManager = GamepadManager();
  final List<Enemy> enemies = [];
  final List<Projectile> projectiles = [];
  final List<TiledPlatform> platforms = [];
  final List<Chest> chests = [];
  int enemiesDefeated = 0;
  bool isGameOver = false;

  ActionGame({
    required this.characterClass,
    this.mapName = 'level_1',
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Add gamepad manager as a component
    add(gamepadManager);

    // Adjust camera for a tighter, more cinematic view on mobile
    camera.viewfinder.zoom = 1.2;

    // Load background
    final background = SpriteComponent()
      ..sprite = await loadSprite('ground.png')
      ..size = Vector2(1920, 1080)
      ..paint = (Paint()..color = Colors.blueGrey.withOpacity(0.2));
    world.add(background);

    // Create a large background gradient
    final bgRect = RectangleComponent(
      size: Vector2(5000, 2000),
      position: Vector2(-1000, -500),
      paint: Paint()..shader = UIGradient.linear(
        const Offset(0, 0),
        const Offset(0, 1000),
        [const Color(0xFF1a1a2e), const Color(0xFF16213e)],
      ).shader,
    );
    world.add(bgRect);

    // Load map from JSON
    final gameMap = await MapLoader.loadMap(mapName);

    // Create platforms with textures
    for (final platformData in gameMap.platforms) {
      final platform = TiledPlatform(
        position: Vector2(
          platformData.x + platformData.width / 2,
          platformData.y + platformData.height / 2,
        ),
        size: Vector2(platformData.width, platformData.height),
        platformType: platformData.type,
      );
      world.add(platform);
      platforms.add(platform);
    }

    for (final chestData in gameMap.chests) {
      final chest = Chest(
        position: Vector2(chestData.x, chestData.y),
        data: chestData,
      );
      add(chest);
      world.add(chest);
      chests.add(chest);
    }

    print('✅ ActionGame: ${chests.length} chests created');

    // Create player at spawn point
    player = Player(
      position: Vector2(gameMap.playerSpawn.x, gameMap.playerSpawn.y),
      stats: CharacterStats.fromClass(characterClass),
      game: this,
    );
    world.add(player);

    // Create enemies
    for (int i = 0; i < 3; i++) {
      final enemyClass = CharacterClass.values[i % CharacterClass.values.length];
      final enemy = Enemy(
        position: Vector2(
          gameMap.playerSpawn.x + 400 + i * 300.0,
          gameMap.playerSpawn.y,
        ),
        stats: CharacterStats.fromClass(enemyClass),
        player: player,
        game: this,
      );
      world.add(enemy);
      enemies.add(enemy);
    }

    // Camera setup for landscape
    camera.follow(player);
    camera.viewfinder.visibleGameSize = Vector2(1280, 720);

    // Create joystick - Added to the camera viewport to stay fixed and visible
    joystick = JoystickComponent(
      knob: CircleComponent(radius: 25, paint: Paint()..color = Colors.white.withOpacity(0.5)),
      background: CircleComponent(radius: 50, paint: Paint()..color = Colors.white.withOpacity(0.1)),
      margin: const EdgeInsets.only(left: 40, bottom: 40),
    );
    camera.viewport.add(joystick);

    // Add HUD to viewport
    camera.viewport.add(HUD(player: player, game: this));
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    gamepadManager.onKeyEvent(event, keysPressed);
//print(keysPressed);
    print(event);
    return KeyEventResult.handled;
  }

  @override
  void onTapDown(TapDownInfo info) {
    super.onTapDown(info);
    final tapPos = info.eventPosition.global;

    // Attack button logic
    final attackButtonPos = Vector2(size.x - 80, size.y - 80);
    if (tapPos.distanceTo(attackButtonPos) < 50) {
      attack();
    }
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

class UIGradient {
  static Paint linear(Offset from, Offset to, List<Color> colors) {
    return Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ).createShader(Rect.fromPoints(from, to));
  }
}
