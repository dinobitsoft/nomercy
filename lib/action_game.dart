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
  final String mapName; // Add this field
  late Player player;
  late JoystickComponent joystick;
  final List<Enemy> enemies = [];
  final List<Projectile> projectiles = [];
  final List<Platform> platforms = [];
  int enemiesDefeated = 0;
  bool isGameOver = false;

  ActionGame({
    required this.characterClass,
    this.mapName = 'level_1', // Default map
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    camera.viewfinder.zoom = 1.5;

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

    // Create enemies (you can add enemy spawn points to the map later)
    for (int i = 0; i < 3; i++) {
      final enemyClass = CharacterClass.values[i % CharacterClass.values.length];
      final enemy = Enemy(
        position: Vector2(300 + i * 250.0, gameMap.playerSpawn.y),
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


  @override
  void onTapDown(TapDownInfo info) {
    super.onTapDown(info);
    final tapPos = info.eventPosition.global;
    final attackButtonPos = Vector2(size.x - 60, 60);
    if (tapPos.distanceTo(attackButtonPos) < 40) {
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

// Rest of ActionGame methods stay the same...
}