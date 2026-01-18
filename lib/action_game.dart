import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nomercy/game/character/wizard.dart';
import 'package:nomercy/game/tactic/berserker_tactic.dart';
import 'package:nomercy/gamepad_manager.dart';
import 'package:nomercy/player_type.dart';
import 'package:nomercy/projectile.dart';
import 'package:nomercy/tiled_platform.dart';

import 'chest/chest.dart';
import 'game/bot_tactic.dart';
import 'game/character/knight.dart';
import 'game/character/thief.dart';
import 'game/character/trader.dart';
import 'game/game_character.dart';
import 'game/tactic/aggressive_tactic.dart';
import 'game/tactic/balanced_tactic.dart';
import 'game/tactic/defensive_tactic.dart';
import 'hud.dart';
import 'map/map_loader.dart';
import 'network_manager.dart'; // Add this import

class ActionGame extends FlameGame with HasCollisionDetection, TapDetector, KeyboardEvents {
  final String selectedCharacterClass;
  final String mapName;
  final bool enableMultiplayer; // New parameter

  late GameCharacter player;
  late JoystickComponent joystick;
  final GamepadManager gamepadManager = GamepadManager();
  final List<GameCharacter> enemies = [];
  final List<Projectile> projectiles = [];
  final List<TiledPlatform> platforms = [];
  final List<Chest> chests = [];
  int enemiesDefeated = 0;
  bool isGameOver = false;

  ActionGame({
    required this.selectedCharacterClass,
    this.mapName = 'level_1',
    this.enableMultiplayer = false, // Default to false for backward compatibility
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

    // Create chests
    for (final chestData in gameMap.chests) {
      final chest = Chest(
        position: Vector2(chestData.x, chestData.y),
        data: chestData,
      );
      add(chest);
      world.add(chest);
      chests.add(chest);
    }

    // Create HUMAN player
    player = _createCharacter(
      selectedCharacterClass,
      Vector2(gameMap.playerSpawn.x, gameMap.playerSpawn.y),
      PlayerType.human,
    );
    player.priority = 100; // Ensure local player renders on top
    add(player);
    world.add(player);

    // Only create BOT enemies if multiplayer is disabled
    if (!enableMultiplayer) {
      final botConfigs = [
        {'class': 'knight', 'x': 600.0, 'tactic': AggressiveTactic()},
        {'class': 'thief', 'x': 1000.0, 'tactic': BalancedTactic()},
        {'class': 'wizard', 'x': 1400.0, 'tactic': DefensiveTactic()},
        {'class': 'trader', 'x': 1200.0, 'tactic': BerserkerTactic()},
      ];

      for (final config in botConfigs) {
        final bot = _createCharacter(
          config['class'] as String,
          Vector2(config['x'] as double, gameMap.playerSpawn.y),
          PlayerType.bot,
          botTactic: config['tactic'] as BotTactic,
        );
        add(bot);
        world.add(bot);
        enemies.add(bot);
      }
    }

    // Camera
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

    // Connect to multiplayer server if enabled
    if (enableMultiplayer) {
      debugPrint('Connecting to multiplayer server...');
      NetworkManager().connect(
        selectedCharacterClass,
        player.stats,
        this,
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Update network manager
    if (enableMultiplayer) {
      NetworkManager().update(dt);
    }

    // Check chest interactions
    for (final chest in chests) {
      if (!chest.isOpened && chest.isPlayerNear) {
        // Check if player pressed down
        final joystickDirection = joystick.direction;
        if (joystickDirection == JoystickDirection.down) {
          chest.open(player);
        }
      }
    }
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    gamepadManager.onKeyEvent(event, keysPressed);
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

    // Send attack to multiplayer server
    if (enableMultiplayer && NetworkManager().isConnected) {
      final direction = player.facingRight ? Vector2(1, 0) : Vector2(-1, 0);
      NetworkManager().sendAttack(
        selectedCharacterClass,
        player.position.x,
        player.position.y,
        direction.x,
        direction.y,
      );
    }
  }

  void removeEnemy(GameCharacter enemy) {
    // Check if this is a remote player
    if (enableMultiplayer && NetworkManager().isRemotePlayer(enemy)) {
      final playerId = NetworkManager().getRemotePlayerId(enemy);
      if (playerId != null) {
        // Send damage to server
        NetworkManager().sendDamage(playerId, 100); // Kill shot
        debugPrint('Killed remote player: $playerId');
      }
      return; // Don't remove from local game, server will handle it
    }

    // Handle local AI enemy
    enemies.remove(enemy);
    enemy.removeFromParent();
    enemiesDefeated++;
    player.stats.money += 20;
  }

  void gameOver() {
    isGameOver = true;
    debugPrint('Game Over!');
  }

  @override
  void onRemove() {
    // Disconnect from multiplayer when leaving game
    if (enableMultiplayer) {
      NetworkManager().disconnect();
    }
    super.onRemove();
  }

  GameCharacter _createCharacter(
      String characterClass,
      Vector2 position,
      PlayerType playerType, {
        BotTactic? botTactic,
      }) {
    switch (characterClass) {
      case 'knight':
        return Knight(
          position: position,
          playerType: playerType,
          botTactic: botTactic,
        );
      case 'thief':
        return Thief(
          position: position,
          playerType: playerType,
          botTactic: botTactic,
        );
      case 'wizard':
        return Wizard(
          position: position,
          playerType: playerType,
          botTactic: botTactic,
        );
      case 'trader':
        return Trader(
          position: position,
          playerType: playerType,
          botTactic: botTactic,
        );
      default:
        return Knight(
          position: position,
          playerType: playerType,
          botTactic: botTactic,
        );
    }
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