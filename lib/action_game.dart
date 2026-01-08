import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:nomercy/platform.dart' show Platform;
import 'package:nomercy/player.dart';
import 'package:nomercy/projectile.dart';

import 'character_class.dart';
import 'character_stats.dart';
import 'enemy.dart';
import 'game_map.dart';
import 'hud.dart';

class ActionGame extends FlameGame with HasCollisionDetection, TapDetector {
  final CharacterClass characterClass;
  final String mapName;
  late Player player;
  late JoystickComponent joystick;
  final List<Enemy> enemies = [];
  final List<Projectile> projectiles = [];
  final List<Platform> platforms = [];
  int enemiesDefeated = 0;
  bool isGameOver = false;

  ActionGame({
    required this.characterClass,
    this.mapName = 'level_1',
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Adjust camera for landscape 16:9
    camera.viewfinder.zoom = 0.8; // Zoom out more for wider view

    // Load map from JSON
    final gameMap = await MapLoader.loadMap(mapName);

    // Create platforms from map data
    for (final platformData in gameMap.platforms) {
      final platform = Platform(
        position: Vector2(
          platformData.x + platformData.width / 2,
          platformData.y + platformData.height / 2,
        ),
        size: Vector2(platformData.width, platformData.height),
        platformType: platformData.type,
      );
      add(platform);
      platforms.add(platform);
    }

    // Create player at spawn point
    player = Player(
      position: Vector2(gameMap.playerSpawn.x, gameMap.playerSpawn.y),
      stats: CharacterStats.fromClass(characterClass),
      game: this,
    );
    add(player);

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
      add(enemy);
      enemies.add(enemy);
    }

    // Create joystick - positioned for landscape
    joystick = JoystickComponent(
      knob: CircleComponent(radius: 40, paint: Paint()..color = Colors.white30),
      background: CircleComponent(radius: 80, paint: Paint()..color = Colors.white10),
      margin: const EdgeInsets.only(left: 60, bottom: 60),
    );
    add(joystick);

    // Add HUD
    add(HUD(player: player, game: this));

    // Camera setup for landscape
    camera.follow(player);
    camera.viewfinder.visibleGameSize = Vector2(1920, 1080);
  }

  @override
  void onTapDown(TapDownInfo info) {
    super.onTapDown(info);
    final tapPos = info.eventPosition.global;

    // Attack button positioned for landscape (top right)
    final attackButtonPos = Vector2(size.x - 100, 100);
    if (tapPos.distanceTo(attackButtonPos) < 60) {
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