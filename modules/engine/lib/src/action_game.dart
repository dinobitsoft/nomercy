import 'dart:math' as math;
import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ui/ui.dart';

import 'manager/infinite_map_manager.dart';

/// INTEGRATION GUIDE:
/// ==================
/// 1. Replace InfiniteMapManager in action_game.dart with the new implementation
/// 2. Add ProceduralMapGenerator to game initialization
/// 3. Call infiniteMapManager.update(character.position, dt) in ActionGame.update()
/// 4. Use infiniteMapManager.getStats() for debugging
///
/// The new system provides:
/// - Seamless infinite world generation
/// - Deterministic chunk generation via seeds
/// - Proper memory management with chunk pooling
/// - Camera-based culling for performance
/// - Automatic wave spawning at boundaries
/// - Biome-based difficulty scaling

class ActionGame extends FlameGame
    with HasCollisionDetection, TapCallbacks, KeyboardEvents {

  // ==========================================
  // EVENT SYSTEMS
  // ==========================================
  final EventBus eventBus = EventBus();
  late final CombatSystem combatSystem;
  late final WaveSystem waveSystem;
  late final AudioSystem audioSystem;
  late final ItemSystem itemSystem;
  late final UISystem uiSystem;

  // ==========================================
  // INFINITE MAP SYSTEM
  // ==========================================
  late InfiniteMapManager mapManager;
  late ProceduralMapGenerator mapGenerator;

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
  final int? mapSeed;

  int availableSpawns = 0;
  int totalSpawns = 0;

  late GameCharacter character;
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
    this.mapName = 'infinite',
    this.procedural = true,
    this.mapConfig,
    this.enableMultiplayer = false,
    this.mapSeed,
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

    // Initialize infinite map system
    mapGenerator = ProceduralMapGenerator(seed: mapSeed);
    mapManager = InfiniteMapManager(game: this, seed: mapSeed);

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
    _createBackground();

    // Initialize infinite map (generates initial chunks)
    mapManager.initialize();

    // Create player
    character = _createCharacter(
      selectedCharacterClass,
      Vector2(400, 600),
      PlayerType.human,
      customId: 'player_main',
    );
    character.priority = 100;
    world.add(character);
    _registerCharacter(character);

    // Create initial enemies
    _spawnInitialEnemies();

    // Setup camera
    camera.follow(character);
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
    camera.viewport.add(HUD(character: character, game: this));

    // Initialize multiplayer
    if (enableMultiplayer) {
      NetworkManager().connect(
        selectedCharacterClass,
        character.stats,
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

    print('✅ ActionGame: Fully initialized with infinite map system');
  }

  void _createBackground() {
    // Large dynamic background (follows camera)
    final bgRect = RectangleComponent(
      size: Vector2(20000, 2000),
      position: Vector2(-5000, -500),
      paint: Paint()..shader = UIGradient.linear(
        const Offset(0, 0),
        const Offset(0, 1000),
        [const Color(0xFF1a1a2e), const Color(0xFF16213e)],
      ).shader,
    );
    world.add(bgRect);
  }

  void _spawnInitialEnemies() {
    // Spawn a few initial enemies to start gameplay
    final botConfigs = [
      {'class': 'knight', 'x': 800.0, 'tactic': AggressiveTactic()},
      {'class': 'thief', 'x': 1000.0, 'tactic': BalancedTactic()},
      {'class': 'trader', 'x': 1200.0, 'tactic': BalancedTactic()},
    ];

    for (int i = 0; i < botConfigs.length; i++) {
      final config = botConfigs[i];
      final bot = _createCharacter(
        config['class'] as String,
        Vector2(config['x'] as double, 600.0),
        PlayerType.bot,
        botTactic: config['tactic'] as BotTactic,
        customId: 'bot_${config['class']}_$i',
      );
      bot.priority = 90;
      world.add(bot);
      enemies.add(bot);
      _registerCharacter(bot);
    }
  }

  void _registerCharacter(GameCharacter character) {
    _characterRegistry[character.uniqueId] = character;
    print('✅ Registered: ${character.uniqueId}');
  }

  void _unregisterCharacter(GameCharacter character) {
    _characterRegistry.remove(character.uniqueId);
  }

  GameCharacter? findCharacterById(String uniqueId) {
    return _characterRegistry[uniqueId];
  }

  bool isPlayerCharacter(GameCharacter character) {
    return character.uniqueId == this.character.uniqueId;
  }

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

  void onPowerUpActivated() {
    // Regenerate all nearby chunks
    final currentIndex = mapManager.currentChunkIndex;
    for (int i = currentIndex - 2; i <= currentIndex + 2; i++) {
      mapManager.regenerateChunk(i);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // CRITICAL: Update infinite map system
    mapManager.update(character.position, dt);

    final loadedChunks = mapManager.loadedChunks;
    for (final chunk in loadedChunks.values) {
      // Render or process chunk
    }

    final chunks = mapManager.generate(radius: 2);

    for (final entry in chunks.entries) {
      final chunkIndex = entry.key;
      final chunk = entry.value;
      print('Generated chunk $chunkIndex');
    }

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

    // Debug: Print stats periodically
    if (DateTime.now().second % 10 == 0) {
      // Optional: infiniteMapManager.printStats();
    }
  }

  @override
  KeyEventResult onKeyEvent(
      KeyEvent event,
      Set<LogicalKeyboardKey> keysPressed,
      ) {
    gamepadManager.onKeyEvent(event, keysPressed);
    return KeyEventResult.ignored;
  }

  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);
    character.stopBlock();
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    super.onTapCancel(event);
    character.stopBlock();
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    final tapPos = event.localPosition;

    final attackButtonPos = Vector2(size.x - 80, size.y - 80);
    if (tapPos.distanceTo(attackButtonPos) < 50) {
      _playerAttack();
      return;
    }

    final dodgeButtonPos = Vector2(size.x - 170, size.y - 80);
    if (tapPos.distanceTo(dodgeButtonPos) < 40) {
      final direction = joystick.relativeDelta.length > 0.1
          ? joystick.relativeDelta
          : Vector2(character.facingRight ? 1 : -1, 0);
      character.dodge(direction);
      return;
    }

    final blockButtonPos = Vector2(size.x - 80, size.y - 170);
    if (tapPos.distanceTo(blockButtonPos) < 40) {
      character.startBlock();
      return;
    }
  }

  void _onCharacterKilled(CharacterKilledEvent event) {
    final victim = findCharacterById(event.victimId);

    if (victim == null) {
      print('⚠️ Could not find victim: ${event.victimId}');
      return;
    }

    if (isPlayerCharacter(victim)) {
      _handlePlayerDeath();
      return;
    }

    if (isBotCharacter(victim)) {
      _handleEnemyDeath(victim, event);
      return;
    }
  }

  void _handlePlayerDeath() {
    isGameOver = true;
    final playTime = DateTime.now().difference(gameStartTime!);

    eventBus.emit(GameOverEvent(
      reason: 'death',
      finalScore: character.stats.money,
      wavesCompleted: waveSystem.currentWave,
      enemiesKilled: enemiesDefeated,
      goldEarned: character.stats.money,
      playTime: playTime,
    ));
  }

  void _handleEnemyDeath(GameCharacter enemy, CharacterKilledEvent event) {
    character.stats.money += event.bountyGold;
    enemiesDefeated++;

    enemies.remove(enemy);
    _unregisterCharacter(enemy);
    enemy.removeFromParent();
    remove(enemy);
    world.remove(enemy);

    if (event.shouldDropLoot) {
      itemSystem.dropLoot(event.deathPosition);
    }

    eventBus.emit(UpdateHUDEvent(element: 'kills', value: enemiesDefeated));
    eventBus.emit(UpdateHUDEvent(element: 'gold', value: character.stats.money));
  }

  void _onEnemySpawned(EnemySpawnedEvent event) {
    final enemy = _createEnemy(event.enemyType, event.spawnPosition);
    if (enemy != null) {
      enemy.priority = 90;
      world.add(enemy);
      enemies.add(enemy);
      _registerCharacter(enemy);
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
    final aliveEnemies = enemies.where((e) => e.characterState.health > 0 && e.isMounted).toList();

    for (final enemy in aliveEnemies) {
      final distance = character.position.distanceTo(enemy.position);
      if (distance < character.stats.attackRange * 30) {
        combatSystem.processAttack(
          attacker: character,
          target: enemy,
          attackType: character.stats.attackRange > 5 ? 'projectile' : 'melee',
        );
      }
    }

    if (character.stats.attackRange > 5 && character.characterState.attackCooldown <= 0) {
      _createProjectile(
        shooter: character,
        direction: character.facingRight ? Vector2(1, 0) : Vector2(-1, 0),
      );
    }

    character.attack();
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
    chest.open(character);
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

    final enemyId = 'spawned_${enemyType}_${DateTime.now().millisecondsSinceEpoch}';

    final enemy = _createCharacter(
      enemyType,
      position,
      PlayerType.bot,
      botTactic: randomTactic,
      customId: enemyId,
    );

    if (enemy != null) {
      _registerCharacter(enemy);
    }

    return enemy;
  }

  void addToInventory(Item item) => inventory.add(item);

  void equipWeapon(Weapon? weapon) {
    if (equippedWeapon != null) {
      character.stats.power -= equippedWeapon!.powerBonus;
      character.stats.magic -= equippedWeapon!.magicBonus;
      character.stats.dexterity -= equippedWeapon!.dexterityBonus;
      character.stats.intelligence -= equippedWeapon!.intelligenceBonus;
      character.stats.attackDamage -= equippedWeapon!.damage;
    }
    equippedWeapon = weapon;
    if (weapon != null) {
      character.stats.power += weapon.powerBonus;
      character.stats.magic += weapon.magicBonus;
      character.stats.dexterity += weapon.dexterityBonus;
      character.stats.intelligence += weapon.intelligenceBonus;
      character.stats.attackDamage += weapon.damage;
      character.stats.attackRange = weapon.range;
      character.stats.weaponName = weapon.name;

      eventBus.emit(WeaponEquippedEvent(
        characterId: character.stats.name,
        weaponId: weapon.id,
        weaponName: weapon.name,
        newDamage: character.stats.attackDamage,
        newRange: character.stats.attackRange,
      ));
    }
  }

  void sellItem(Item item) {
    character.stats.money += item.value ~/ 2;
    inventory.remove(item);
  }

  void buyWeapon(Weapon weapon) {
    if (character.stats.money >= weapon.value) {
      character.stats.money -= weapon.value;
      addToInventory(weapon);
    }
  }

  @override
  void onRemove() {
    _characterRegistry.clear();

    for (final sub in _subscriptions) sub.cancel();
    _subscriptions.clear();

    combatSystem.dispose();
    waveSystem.dispose();
    audioSystem.dispose();
    itemSystem.dispose();
    uiSystem.dispose();
    mapManager.dispose();
    mapGenerator.clearCache();

    if (enableMultiplayer) NetworkManager().disconnect();
    super.onRemove();
  }
}

class UIGradient {
  static Paint linear(Offset from, Offset to, List<Color> colors) {
    return Paint()..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors)
        .createShader(Rect.fromPoints(from, to));
  }
}