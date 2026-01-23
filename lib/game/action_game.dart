// lib/game/action_game.dart - FIXED VERSION

import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nomercy/game/tactic/aggressive_tactic.dart';
import 'package:nomercy/game/tactic/balanced_tactic.dart';
import 'package:nomercy/game/tactic/defensive_tactic.dart';
import 'package:nomercy/game/tactic/tactical_tactic.dart';

import '../chest/chest.dart';
import '../core/event_bus.dart';
import '../core/game_event.dart';
import '../entities/projectile/projectile.dart';
import '../game_mode.dart';
import '../gamepad_manager.dart';
import '../hud.dart';
import '../item/item.dart';
import '../item/item_drop.dart';
import '../managers/network_manager.dart';
import '../map/map_generator_config.dart';
import '../map/map_loader.dart';
import '../player_type.dart';
import '../systems/audio_system.dart';
import '../systems/combat_system.dart';
import '../systems/item_system.dart';
import '../systems/ui_system.dart';
import '../systems/wave_system.dart';
import '../tiled_platform.dart';
import 'bot_tactic.dart';
import 'character/knight.dart';
import 'character/thief.dart';
import 'character/trader.dart';
import 'character/wizard.dart';
import 'game_character.dart';

class ActionGame extends FlameGame
    with HasCollisionDetection, TapDetector, KeyboardEvents {

  // ==========================================
  // EVENT SYSTEMS
  // ==========================================
  final EventBus eventBus = EventBus();
  late final CombatSystem combatSystem;
  late final WaveSystem waveSystem;
  late final AudioSystem audioSystem;
  late final ItemSystem itemSystem;
  late final UISystem uiSystem;

  // Event subscriptions
  final List<EventSubscription> _subscriptions = [];

  // ==========================================
  // GAME STATE
  // ==========================================
  final String selectedCharacterClass;
  final String mapName;
  final GameMode gameMode;
  final bool procedural;
  final MapGeneratorConfig? mapConfig;
  final bool enableMultiplayer;

  late GameCharacter player;
  final List<GameCharacter> enemies = [];
  final Map<String, GameCharacter> _characterRegistry = {};

  final List<Projectile> projectiles = [];
  final List<TiledPlatform> platforms = [];
  final List<Chest> chests = [];
  final List<Item> inventory = [];
  final List<ItemDrop> itemDrops = [];
  Weapon? equippedWeapon;

  late JoystickComponent joystick;
  final GamepadManager gamepadManager = GamepadManager();

  int enemiesDefeated = 0;
  bool isGameOver = false;
  DateTime? gameStartTime;

  ActionGame({
    required this.selectedCharacterClass,
    required this.gameMode,
    this.mapName = 'level_1',
    this.procedural = false,
    this.mapConfig,
    this.enableMultiplayer = false,
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    gameStartTime = DateTime.now();

    // Initialize systems
    combatSystem = CombatSystem();
    waveSystem = WaveSystem(game: this, gameMode: gameMode);
    audioSystem = AudioSystem();
    itemSystem = ItemSystem(game: this);
    uiSystem = UISystem(game: this);

    // Setup event listeners
    _setupEventListeners();

    // Add gamepad manager to game components
    add(gamepadManager);

    // Setup camera
    camera.viewfinder.zoom = 1.2;

    // Load map
    final gameMap = procedural
        ? await MapLoader.loadMap(mapName, procedural: true, config: mapConfig)
        : await MapLoader.loadMap(mapName, procedural: false);

    // Create background
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

    // Create platforms
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

    // Create chests
    for (final chestData in gameMap.chests) {
      final chest = Chest(
        position: Vector2(chestData.x, chestData.y),
        data: chestData,
      );
      chest.priority = 50;
      world.add(chest);
      chests.add(chest);
    }

    // Create items
    for (final itemData in gameMap.items) {
      final item = itemData.toItem();
      final itemDrop = ItemDrop(
        position: Vector2(itemData.x, itemData.y),
        item: item,
      );
      itemDrop.priority = 50;
      world.add(itemDrop);
      itemDrops.add(itemDrop);
    }

    // Create player
    player = _createCharacter(
      selectedCharacterClass,
      Vector2(gameMap.playerSpawn.x, gameMap.playerSpawn.y),
      PlayerType.human,
      customId: 'player_main', // Explicit player ID
    );
    player.priority = 100;
    world.add(player);

    // Register player
    _registerCharacter(player);

    // Create BOT enemies
    final botConfigs = [
      {'class': 'knight', 'x': 600.0, 'tactic': AggressiveTactic()},
      {'class': 'thief', 'x': 1000.0, 'tactic': BalancedTactic()},
      {'class': 'trader', 'x': 1000.0, 'tactic': BalancedTactic()},
      {'class': 'wizard', 'x': 1400.0, 'tactic': DefensiveTactic()},
    ];

    for (int i = 0; i < botConfigs.length; i++) {
      final config = botConfigs[i];
      final bot = _createCharacter(
        config['class'] as String,
        Vector2(config['x'] as double, gameMap.playerSpawn.y),
        PlayerType.bot,
        botTactic: config['tactic'] as BotTactic,
        customId: 'bot_${config['class']}_$i', // Unique bot ID
      );
      bot.priority = 90;
      world.add(bot);
      enemies.add(bot);

      // Register bot
      _registerCharacter(bot);
    }

    // Setup camera
    camera.follow(player);
    camera.viewfinder.visibleGameSize = Vector2(1280, 720);

    // Create joystick
    joystick = JoystickComponent(
      knob: CircleComponent(
        radius: 25,
        paint: Paint()..color = Colors.white.withOpacity(0.5),
      ),
      background: CircleComponent(
        radius: 50,
        paint: Paint()..color = Colors.white.withOpacity(0.1),
      ),
      margin: const EdgeInsets.only(left: 40, bottom: 40),
    );
    camera.viewport.add(joystick);

    // Add HUD
    camera.viewport.add(HUD(player: player, game: this));

    // Initialize multiplayer
    if (enableMultiplayer) {
      NetworkManager().connect(
        selectedCharacterClass,
        player.stats,
        this,
      );
    }

    // Start game
    waveSystem.initialize();
    waveSystem.startFirstWave();

    // Emit events
    eventBus.emit(GameStartedEvent(
      gameMode: gameMode.toString(),
      characterClass: selectedCharacterClass,
      mapName: mapName,
    ));

    eventBus.emit(PlayMusicEvent(musicId: 'battle_theme'));

    print('✅ ActionGame: Fully initialized');
  }

  // NEW: Register character in registry
  void _registerCharacter(GameCharacter character) {
    _characterRegistry[character.uniqueId] = character;
    print('✅ Registered character: ${character.uniqueId} (${character.stats.name}, ${character.playerType})');
  }

  // NEW: Unregister character from registry
  void _unregisterCharacter(GameCharacter character) {
    _characterRegistry.remove(character.uniqueId);
    print('❌ Unregistered character: ${character.uniqueId}');
  }

  // NEW: Find character by unique ID
  GameCharacter? findCharacterById(String uniqueId) {
    return _characterRegistry[uniqueId];
  }

  // NEW: Check if character is the player
  bool isPlayerCharacter(GameCharacter character) {
    return character.uniqueId == player.uniqueId;
  }

  // NEW: Check if character is a bot
  bool isBotCharacter(GameCharacter character) {
    return enemies.any((e) => e.uniqueId == character.uniqueId);
  }

  void _setupEventListeners() {
    _subscriptions.add(eventBus.on<CharacterKilledEvent>(
        _onCharacterKilled,
        priority: ListenerPriority.highest
    ));
    _subscriptions.add(eventBus.on<EnemySpawnedEvent>(
        _onEnemySpawned,
        priority: ListenerPriority.high
    ));
    _subscriptions.add(eventBus.on<GameOverEvent>(
        _onGameOver,
        priority: ListenerPriority.highest
    ));
    _subscriptions.add(eventBus.on<GamePausedEvent>(
        _onGamePaused,
        priority: ListenerPriority.high
    ));
    _subscriptions.add(eventBus.on<GameResumedEvent>(
        _onGameResumed,
        priority: ListenerPriority.high
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);

    waveSystem.update(dt);
    combatSystem.updateCombos(dt);
    itemSystem.update(dt);
    uiSystem.update(dt);

    if (enableMultiplayer) {
      NetworkManager().update(dt);
    }

    // Check attack from gamepad
    if (gamepadManager.isAttackJustPressed()) {
      _playerAttack();
    }

    // Check chest interactions
    for (final chest in chests) {
      if (!chest.isOpened && chest.isPlayerNear) {
        if (joystick.direction == JoystickDirection.down || gamepadManager.joystickDelta.y > 0.5) {
          _openChest(chest);
        }
      }
    }
  }

  @override
  KeyEventResult onKeyEvent(
      KeyEvent event,
      Set<LogicalKeyboardKey> keysPressed,
      ) {
    // Explicitly forward to gamepad manager if not automatically handled
    gamepadManager.onKeyEvent(event, keysPressed);
    return KeyEventResult.ignored; // Let Flame dispatch to other components
  }

  @override
  void onTapUp(TapUpInfo info) {
    super.onTapUp(info);
    player.stopBlock();
  }

  @override
  void onTapDown(TapDownInfo info) {
    super.onTapDown(info);
    final tapPos = info.eventPosition.global;

    final attackButtonPos = Vector2(size.x - 80, size.y - 80);
    if (tapPos.distanceTo(attackButtonPos) < 50) {
      _playerAttack();
      return;
    }

    final dodgeButtonPos = Vector2(size.x - 170, size.y - 80);
    if (tapPos.distanceTo(dodgeButtonPos) < 40) {
      final direction = joystick.relativeDelta.length > 0.1
          ? joystick.relativeDelta
          : Vector2(player.facingRight ? 1 : -1, 0);
      player.dodge(direction);
      return;
    }

    final blockButtonPos = Vector2(size.x - 80, size.y - 170);
    if (tapPos.distanceTo(blockButtonPos) < 40) {
      player.startBlock();
      return;
    }
  }

  void _onCharacterKilled(CharacterKilledEvent event) {
    print('💀 Character killed event: victimId=${event.victimId}');

    // Try to find the character by the victimId (which should be uniqueId)
    final victim = findCharacterById(event.victimId);

    if (victim == null) {
      print('⚠️ Warning: Could not find victim with ID: ${event.victimId}');
      return;
    }

    // Check if it's the player using unique ID comparison
    if (isPlayerCharacter(victim)) {
      print('💀 PLAYER DIED: ${victim.stats.name}');
      _handlePlayerDeath();
      return;
    }

    // Check if it's a bot using unique ID comparison
    if (isBotCharacter(victim)) {
      print('💀 BOT DIED: ${victim.stats.name} (${victim.uniqueId})');
      _handleEnemyDeath(victim, event);
      return;
    }

    print('⚠️ Warning: Character ${event.victimId} is neither player nor registered bot');
  }

  void _handlePlayerDeath() {
    isGameOver = true;
    final playTime = DateTime.now().difference(gameStartTime!);

    print('☠️ GAME OVER - Player died');

    eventBus.emit(GameOverEvent(
      reason: 'death',
      finalScore: player.stats.money,
      wavesCompleted: waveSystem.currentWave,
      enemiesKilled: enemiesDefeated,
      goldEarned: player.stats.money,
      playTime: playTime,
    ));
  }

  void _handleEnemyDeath(GameCharacter enemy, CharacterKilledEvent event) {
    print('💀 Handling bot death: ${enemy.stats.name} (${enemy.uniqueId})');

    player.stats.money += event.bountyGold;
    enemiesDefeated++;

    // Remove from tracking list FIRST
    final wasRemoved = enemies.remove(enemy);
    print('  - Removed from enemies list: $wasRemoved');

    // Unregister from character registry
    _unregisterCharacter(enemy);

    // Stop all animations and clear state
    enemy.health = 0;
    enemy.velocity = Vector2.zero();
    enemy.animation = null;

    // Remove from component tree
    enemy.removeFromParent();

    // Remove from world explicitly
    if (world.children.contains(enemy)) {
      world.remove(enemy);
      print('  - Removed from world');
    } else {
      world.remove(enemy);

    }

    // Additional cleanup
    if (enemy.isMounted) {
      // enemy.removed(); //TODO: implement this method
      print('  - Called removed() lifecycle');
    }

    print('✅ Bot fully removed: ${enemy.stats.name} (${enemy.uniqueId})');
    print('  - Remaining enemies: ${enemies.length}');
    print('  - Registered characters: ${_characterRegistry.length}');

    // Drop loot
    if (event.shouldDropLoot) {
      itemSystem.dropLoot(event.deathPosition);
    }

    // Update HUD
    eventBus.emit(UpdateHUDEvent(element: 'kills', value: enemiesDefeated));
    eventBus.emit(UpdateHUDEvent(element: 'gold', value: player.stats.money));
  }

  void _onEnemySpawned(EnemySpawnedEvent event) {
    final enemy = _createEnemy(event.enemyType, event.spawnPosition);
    if (enemy != null) {
      enemy.priority = 90;
      world.add(enemy);
      enemies.add(enemy);
      print('✅ Spawned enemy: ${enemy.uniqueId}');
    }
  }

  void _onGameOver(GameOverEvent event) {
    pauseEngine();
    eventBus.emit(StopMusicEvent());
  }

  void _onGamePaused(GamePausedEvent event) {
    pauseEngine();
    audioSystem.pauseMusic();
  }

  void _onGameResumed(GameResumedEvent event) {
    resumeEngine();
    audioSystem.resumeMusic();
  }

  void _playerAttack() {
    for (final enemy in enemies) {
      final distance = player.position.distanceTo(enemy.position);
      if (distance < player.stats.attackRange * 30) {
        combatSystem.processAttack(
          attacker: player,
          target: enemy,
          attackType: player.stats.attackRange > 5 ? 'projectile' : 'melee',
        );
      }
    }

    if (player.stats.attackRange > 5 && player.attackCooldown <= 0) {
      _createProjectile(
        shooter: player,
        direction: player.facingRight ? Vector2(1, 0) : Vector2(-1, 0),
      );
    }
    
    // Trigger animation
    player.attack();
  }

  void _createProjectile({
    required GameCharacter shooter,
    required Vector2 direction,
  }) {
    final projectile = Projectile(
      position: shooter.position.clone(),
      direction: direction,
      damage: shooter.stats.attackDamage,
      owner: shooter.playerType == PlayerType.human ? shooter : null,
      enemyOwner: shooter.playerType == PlayerType.bot ? shooter : null,
      color: shooter.stats.color,
      type: _getProjectileType(shooter),
    );
    projectile.priority = 75;
    world.add(projectile);
    projectiles.add(projectile);
  }

  String _getProjectileType(GameCharacter character) {
    final name = character.stats.name.toLowerCase();
    if (name.contains('thief')) return 'knife';
    if (name.contains('wizard')) return 'fireball';
    if (name.contains('trader')) return 'arrow';
    return 'projectile';
  }

  void _openChest(Chest chest) {
    chest.open(player);
    eventBus.emit(ChestOpenedEvent(
      chestId: chest.data.id.toString(),
      reward: 'Health Potion',
      position: chest.position,
    ));
  }

  GameCharacter _createCharacter(
      String characterClass,
      Vector2 position,
      PlayerType playerType, {
        BotTactic? botTactic,
        String? customId,
      }) {
    switch (characterClass.toLowerCase()) {
      case 'knight':
        return Knight(
          position: position,
          playerType: playerType,
          botTactic: botTactic,
          customId: customId,
        );
      case 'thief':
        return Thief(
          position: position,
          playerType: playerType,
          botTactic: botTactic,
          customId: customId,
        );
      case 'wizard':
        return Wizard(
          position: position,
          playerType: playerType,
          botTactic: botTactic,
          customId: customId,
        );
      case 'trader':
        return Trader(
          position: position,
          playerType: playerType,
          botTactic: botTactic,
          customId: customId,
        );
      default:
        return Knight(
          position: position,
          playerType: playerType,
          botTactic: botTactic,
          customId: customId,
        );
    }
  }


  GameCharacter? _createEnemy(String enemyType, Vector2 position) {
    final tactics = [
      AggressiveTactic(),
      BalancedTactic(),
      DefensiveTactic(),
      TacticalTactic()
    ];
    final randomTactic = tactics[math.Random().nextInt(tactics.length)];

    // Generate unique ID for spawned enemy
    final enemyId = 'spawned_${enemyType}_${DateTime.now().millisecondsSinceEpoch}';

    final enemy = _createCharacter(
      enemyType,
      position,
      PlayerType.bot,
      botTactic: randomTactic,
      customId: enemyId,
    );

    // Register the new enemy
    if (enemy != null) {
      _registerCharacter(enemy);
    }

    return enemy;
  }

  void addToInventory(Item item) => inventory.add(item);

  void equipWeapon(Weapon? weapon) {
    if (equippedWeapon != null) {
      player.stats.power -= equippedWeapon!.powerBonus;
      player.stats.magic -= equippedWeapon!.magicBonus;
      player.stats.dexterity -= equippedWeapon!.dexterityBonus;
      player.stats.intelligence -= equippedWeapon!.intelligenceBonus;
      player.stats.attackDamage -= equippedWeapon!.damage;
    }
    equippedWeapon = weapon;
    if (weapon != null) {
      player.stats.power += weapon.powerBonus;
      player.stats.magic += weapon.magicBonus;
      player.stats.dexterity += weapon.dexterityBonus;
      player.stats.intelligence += weapon.intelligenceBonus;
      player.stats.attackDamage += weapon.damage;
      player.stats.attackRange = weapon.range;
      player.stats.weaponName = weapon.name;

      eventBus.emit(WeaponEquippedEvent(
        characterId: player.stats.name,
        weaponId: weapon.id,
        weaponName: weapon.name,
        newDamage: player.stats.attackDamage,
        newRange: player.stats.attackRange,
      ));
    }
  }

  void sellItem(Item item) {
    player.stats.money += item.value ~/ 2;
    inventory.remove(item);
  }

  void buyWeapon(Weapon weapon) {
    if (player.stats.money >= weapon.value) {
      player.stats.money -= weapon.value;
      addToInventory(weapon);
    }
  }

  @override
  void onRemove() {
    // Clear character registry
    _characterRegistry.clear();

    for (final sub in _subscriptions) sub.cancel();
    _subscriptions.clear();
    combatSystem.dispose();
    waveSystem.dispose();
    audioSystem.dispose();
    itemSystem.dispose();
    uiSystem.dispose();
    if (enableMultiplayer) NetworkManager().disconnect();
    super.onRemove();
  }
}

class UIGradient {
  static Paint linear(Offset from, Offset to, List<Color> colors) {
    return Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors).createShader(Rect.fromPoints(from, to));
  }
}