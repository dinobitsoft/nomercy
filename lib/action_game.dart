import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nomercy/game/character/wizard.dart';
import 'package:nomercy/gamepad_manager.dart';
import 'package:nomercy/player_type.dart';
import 'package:nomercy/tiled_platform.dart';

import 'chest/chest.dart';
import 'entities/projectile/projectile.dart';
import 'game/bot_tactic.dart';
import 'game/character/knight.dart';
import 'game/character/thief.dart';
import 'game/character/trader.dart';
import 'game/game_character.dart';
import 'game/tactic/aggressive_tactic.dart';
import 'game/tactic/balanced_tactic.dart';
import 'game/tactic/defensive_tactic.dart';
import 'game/tactic/tactical_tactic.dart';
import 'game_manager.dart';
import 'game_mode.dart';
import 'hud.dart';
import 'item/item.dart';
import 'item/item_drop.dart';
import 'map/map_generator_config.dart';
import 'map/map_loader.dart';
import 'managers/network_manager.dart'; // Add this import

class ActionGame extends FlameGame with HasCollisionDetection, TapDetector, KeyboardEvents {
  final String selectedCharacterClass;
  final String mapName;
  final bool enableMultiplayer;
  final List<ItemDrop> itemDrops = [];
  final List<Item> inventory = [];
  Weapon? equippedWeapon;
  late GameCharacter player;
  late JoystickComponent joystick;
  final GamepadManager gamepadManager = GamepadManager();
  final List<GameCharacter> enemies = [];
  final List<Projectile> projectiles = [];
  final List<TiledPlatform> platforms = [];
  final List<Chest> chests = [];
  int enemiesDefeated = 0;
  bool isGameOver = false;
  late GameManager gameManager;
  GameMode gameMode; // Default to survival
  final bool procedural;
  final MapGeneratorConfig? mapConfig;


  ActionGame({
    required this.selectedCharacterClass,
    required this.gameMode,
    this.mapName = 'level_1',
    this.enableMultiplayer = false, // Default to false for backward compatibility
    this.procedural = false,
    this.mapConfig,
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

    final gameMap = procedural
        ? await MapLoader.loadMap(mapName, procedural: true, config: mapConfig)
        : await MapLoader.loadMap(mapName, procedural: false);

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

    // Create platforms with textures - Priority 10 (bottom layer)
    for (final platformData in gameMap.platforms) {
      final platform = TiledPlatform(
        position: Vector2(
          platformData.x + platformData.width / 2,
          platformData.y + platformData.height / 2,
        ),
        size: Vector2(platformData.width, platformData.height),
        platformType: platformData.type,
      );

      platform.priority = 10;
      world.add(platform);
      platforms.add(platform);
    }

    // Create chests - Priority 50 (middle layer)
    for (final chestData in gameMap.chests) {
      final chest = Chest(
        position: Vector2(chestData.x, chestData.y),
        data: chestData,
      );
      chest.priority = 50;
      add(chest);
      world.add(chest);
      chests.add(chest);
    }

    // Create items - Priority 50 (middle layer)
    for (final itemData in gameMap.items) {
      final itemDrop = ItemDrop(
        position: Vector2(itemData.x, itemData.y),
        item: itemData.toItem(),
      );
      add(itemDrop);
      world.add(itemDrop);
      itemDrops.add(itemDrop);
    }

    // Create HUMAN player - Priority 100 (top character layer)
    player = _createCharacter(
      selectedCharacterClass,
      Vector2(gameMap.playerSpawn.x, gameMap.playerSpawn.y),
      PlayerType.human,
    );
    player.priority = 100; // Ensure local player renders on top
    add(player);
    world.add(player);

    // NEW - Initialize Game Manager
    gameManager = GameManager(mode: gameMode);
    add(gameManager);
    world.add(gameManager);

    // Only create BOT enemies if multiplayer is disabled
    if (!enableMultiplayer) {
      final botConfigs = [
        {
          'class': 'knight',
          'x': 600.0,
          'y': gameMap.playerSpawn.y,
          'tactic': AggressiveTactic(), // Close-combat aggressor
          'name': 'Aggressive Knight'
        },
        {
          'class': 'thief',
          'x': 900.0,
          'y': gameMap.playerSpawn.y - 100, // Start on higher platform
          'tactic': TacticalTactic(), // Smart hit-and-run
          'name': 'Tactical Thief'
        },
        {
          'class': 'wizard',
          'x': 1200.0,
          'y': gameMap.playerSpawn.y,
          'tactic': DefensiveTactic(), // Safe ranged attacker
          'name': 'Defensive Wizard'
        },
        {
          'class': 'trader',
          'x': 1500.0,
          'y': gameMap.playerSpawn.y,
          'tactic': BalancedTactic(), // Versatile fighter
          'name': 'Balanced Trader'
        },
      ];

      for (final config in botConfigs) {
        final bot = _createCharacter(
          config['class'] as String,
          Vector2(config['x'] as double, config['y'] as double),
          PlayerType.bot,
          botTactic: config['tactic'] as BotTactic,
        );
        bot.priority = 80;
        // Optional: Set custom name
        print('Spawning ${config['name']} at (${config['x']}, ${config['y']})');

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

    if (procedural && mapConfig != null) {
      print('🗺️  Playing on procedural map:');
      print('   Style: ${mapConfig!.style.name}');
      print('   Difficulty: ${mapConfig!.difficulty.name}');
      print('   Seed: ${mapConfig!.seed}');
    }

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
  void onTapUp(TapUpInfo info) {
    super.onTapUp(info);
    // Release block when tap is released
    player.stopBlock();
  }

  @override
  void onTapDown(TapDownInfo info) {
    super.onTapDown(info);
    final tapPos = info.eventPosition.global;

    // Attack button
    final attackButtonPos = Vector2(size.x - 80, size.y - 80);
    if (tapPos.distanceTo(attackButtonPos) < 50) {
      player.attack();
      return;
    }

    // Dodge button
    final dodgeButtonPos = Vector2(size.x - 170, size.y - 80);
    if (tapPos.distanceTo(dodgeButtonPos) < 40) {
      final direction = joystick.relativeDelta.length > 0.1
          ? joystick.relativeDelta
          : Vector2(player.facingRight ? 1 : -1, 0);
      player.dodge(direction);
      return;
    }

    // Block button (hold to block - released in onTapUp)
    final blockButtonPos = Vector2(size.x - 80, size.y - 170);
    if (tapPos.distanceTo(blockButtonPos) < 40) {
      player.startBlock();
      return;
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

    _dropLootFromEnemy(enemy);

    // Handle local AI bot
    enemies.remove(enemy);
    enemy.removeFromParent();
    enemiesDefeated++;
    player.stats.money += 20;

    gameManager.onEnemyDefeated();
  }

  void _dropLootFromEnemy(GameCharacter enemy) {
    final random = math.Random();

    // 40% chance to drop health potion
    if (random.nextDouble() < 0.4) {
      final healthPotion = ItemDrop(
        position: enemy.position.clone(),
        item: HealthPotion(),
      );
      add(healthPotion);
      world.add(healthPotion);
      itemDrops.add(healthPotion);
      print('💊 Health potion dropped!');
    }
    // 20% chance to drop a random weapon
    else if (random.nextDouble() < 0.25) {
      final weapons = Weapon.getAllWeapons();
      final randomWeapon = weapons[random.nextInt(weapons.length)];

      final weaponDrop = ItemDrop(
        position: enemy.position.clone(),
        item: randomWeapon,
      );
      add(weaponDrop);
      world.add(weaponDrop);
      itemDrops.add(weaponDrop);
      print('⚔️ ${randomWeapon.name} dropped!');
    }
  }

  void gameOver() {
    if (isGameOver) return;
    isGameOver = true;

    print('\n╔══════════════════════════════╗');
    print('║       GAME OVER!             ║');
    print('╚══════════════════════════════╝');
    print('Wave Reached: ${gameManager.currentWave}');
    print('Total Kills: $enemiesDefeated');
    print('Gold Earned: ${player.stats.money}');

    // Show game over screen (implement this)
    _showGameOverScreen();
  }

  void _showGameOverScreen() {
    // TODO: Add game over overlay
    // For now just pause the game
    pauseEngine();
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

  void addToInventory(Item item) {
    inventory.add(item);
    print('Added ${item.name} to inventory');
  }

  void removeFromInventory(Item item) {
    inventory.remove(item);
  }

  void equipWeapon(Weapon? weapon) {
    // Unapply old weapon bonuses
    if (equippedWeapon != null) {
      player.stats.power -= equippedWeapon!.powerBonus;
      player.stats.magic -= equippedWeapon!.magicBonus;
      player.stats.dexterity -= equippedWeapon!.dexterityBonus;
      player.stats.intelligence -= equippedWeapon!.intelligenceBonus;
      player.stats.attackDamage -= equippedWeapon!.damage;
      player.stats.attackRange = 2.0; // Reset to default
    }

    equippedWeapon = weapon;

    // Apply new weapon bonuses
    if (weapon != null) {
      player.stats.power += weapon.powerBonus;
      player.stats.magic += weapon.magicBonus;
      player.stats.dexterity += weapon.dexterityBonus;
      player.stats.intelligence += weapon.intelligenceBonus;
      player.stats.attackDamage += weapon.damage;
      player.stats.attackRange = weapon.range;
      player.stats.weaponName = weapon.name;

      print('Equipped ${weapon.name}!');
      print('New damage: ${player.stats.attackDamage}');
    }
  }

  void sellItem(Item item) {
    final sellPrice = item.value ~/ 2;
    player.stats.money += sellPrice;
    removeFromInventory(item);
    print('Sold ${item.name} for $sellPrice gold');
  }

  void buyWeapon(Weapon weapon) {
    if (player.stats.money >= weapon.value) {
      player.stats.money -= weapon.value;
      addToInventory(weapon);
      print('Bought ${weapon.name} for ${weapon.value} gold');
    }
  }

  void openInventory() {
    pauseEngine();
    // This will be called from game_screen.dart
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