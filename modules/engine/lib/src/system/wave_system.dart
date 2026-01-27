// lib/system/wave_system.dart

import 'dart:ui';

import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';

/// Wave management system using events
class WaveSystem {
  final EventBus _eventBus = EventBus();
  final ActionGame game;
  final GameMode gameMode;

  // Wave state
  int currentWave = 0;
  int enemiesInWave = 0;
  int enemiesDefeatedThisWave = 0;
  bool isWaveActive = false;
  double waveBreakTimer = 0;
  final double waveBreakDuration = 5.0;

  // Wave tracking
  DateTime? waveStartTime;
  int totalEnemiesDefeated = 0;
  int totalGoldEarned = 0;

  // Subscriptions (for cleanup)
  final List<EventSubscription> _subscriptions = [];

  WaveSystem({
    required this.game,
    this.gameMode = GameMode.survival,
  }) {
    _setupEventListeners();
  }

  /// Setup event listeners
  void _setupEventListeners() {
    // Listen for enemy deaths
    _subscriptions.add(
      _eventBus.on<CharacterKilledEvent>(
        _onEnemyKilled,
        priority: ListenerPriority.normal,
      ),
    );

    // Listen for game start
    _subscriptions.add(
      _eventBus.on<GameStartedEvent>(
        _onGameStarted,
        priority: ListenerPriority.high,
      ),
    );

    print('✅ WaveSystem: Event listeners registered');
  }

  /// Initialize wave system
  void initialize() {
    currentWave = 0;
    totalEnemiesDefeated = 0;
    totalGoldEarned = 0;

    // Emit game started event
    _eventBus.emit(GameStartedEvent(
      gameMode: gameMode.toString(),
      characterClass: game.selectedCharacterClass,
      mapName: game.mapName,
    ));
  }

  /// Start first wave
  void startFirstWave() {
    // Fixed: Using Future.delayed instead of Flame Timer which takes double/dt
    Future.delayed(const Duration(seconds: 2), () {
      _startNextWave();
    });
  }

  /// Update wave system (call every frame)
  void update(double dt) {
    // Update wave break timer
    if (!isWaveActive && waveBreakTimer > 0) {
      waveBreakTimer -= dt;

      if (waveBreakTimer <= 0) {
        _startNextWave();
      }
    }

    // Check if wave is complete
    if (isWaveActive && game.enemies.isEmpty) {
      _completeWave();
    }
  }

  // ==========================================
  // WAVE MANAGEMENT
  // ==========================================

  /// Start next wave
  void _startNextWave() {
    currentWave++;
    enemiesDefeatedThisWave = 0;
    isWaveActive = true;
    waveStartTime = DateTime.now();

    // Calculate wave difficulty
    final difficultyMod = _getDifficultyMultiplier();

    // Calculate enemy count
    enemiesInWave = _calculateEnemyCount();

    // Determine enemy types
    final enemyTypes = _selectEnemyTypes();

    print('\n╔════════════════════════════════════╗');
    print('║      WAVE $currentWave STARTING!       ║');
    print('╚════════════════════════════════════╝');
    print('Enemies: $enemiesInWave');
    print('Types: ${enemyTypes.join(", ")}');
    print('Difficulty: ${difficultyMod.toStringAsFixed(2)}x\n');

    // Emit wave started event
    _eventBus.emit(WaveStartedEvent(
      waveNumber: currentWave,
      enemyCount: enemiesInWave,
      enemyTypes: enemyTypes,
      difficultyMultiplier: difficultyMod,
    ));

    // Spawn enemies
    _spawnWaveEnemies(enemyTypes);

    // Special wave events
    if (currentWave % 5 == 0) {
      _eventBus.emit(ShowNotificationEvent(
        message: '⚠️ BOSS WAVE!',
        color: const Color(0xFFFF4444),
        duration: const Duration(seconds: 3),
      ));
      _eventBus.emit(PlayMusicEvent(
        musicId: 'boss_theme',
        volume: 0.7,
      ));
    } else if (currentWave % 10 == 0) {
      _eventBus.emit(ShowNotificationEvent(
        message: '🎉 MILESTONE WAVE!',
        color: const Color(0xFFFFD700),
        duration: const Duration(seconds: 3),
      ));
    }
  }

  /// Complete current wave
  void _completeWave() {
    if (!isWaveActive) return;

    isWaveActive = false;
    waveBreakTimer = waveBreakDuration;

    // Calculate rewards
    final goldReward = _calculateWaveReward();
    final completionTime = DateTime.now().difference(waveStartTime!);
    final perfectClear = enemiesDefeatedThisWave == enemiesInWave;

    // Award gold
    game.character.stats.money += goldReward;
    totalGoldEarned += goldReward;

    print('\n✅ WAVE $currentWave COMPLETE!');
    print('Time: ${completionTime.inSeconds}s');
    print('Reward: +$goldReward gold');
    if (perfectClear) print('🌟 PERFECT CLEAR!');
    print('Next wave in ${waveBreakDuration.toInt()}s\n');

    // Emit wave completed event
    _eventBus.emit(WaveCompletedEvent(
      waveNumber: currentWave,
      goldReward: goldReward,
      completionTime: completionTime,
      perfectClear: perfectClear,
    ));

    // Show notification
    String message = 'Wave $currentWave Complete!\n+$goldReward gold';
    if (perfectClear) message += '\n🌟 PERFECT!';

    _eventBus.emit(ShowNotificationEvent(
      message: message,
      color: const Color(0xFF44FF44),
      duration: const Duration(seconds: 3),
    ));

    // Restore player resources
    _rewardPlayer();
  }

  /// Spawn enemies for current wave
  void _spawnWaveEnemies(List<String> enemyTypes) {
    final spawnPoints = _getSpawnPoints();

    for (int i = 0; i < enemiesInWave; i++) {
      final enemyType = enemyTypes[i % enemyTypes.length];
      final spawnPos = spawnPoints[i % spawnPoints.length];

      // Delay spawn for dramatic effect
      // Fixed: Using Future.delayed instead of Flame Timer which takes double/dt
      Future.delayed(Duration(milliseconds: i * 300), () {
        _spawnEnemy(enemyType, spawnPos);
      });
    }
  }

  /// Spawn individual enemy
  void _spawnEnemy(String enemyType, Vector2 position) {
    // This will be called by game manager
    _eventBus.emit(EnemySpawnedEvent(
      enemyId: 'enemy_${DateTime.now().millisecondsSinceEpoch}',
      enemyType: enemyType,
      spawnPosition: position,
      waveNumber: currentWave,
    ));
  }

  // ==========================================
  // CALCULATIONS
  // ==========================================

  /// Calculate enemy count for current wave
  int _calculateEnemyCount() {
    final baseCount = BalanceConfig.enemiesPerWaveBase;
    final increment = (currentWave / 3).floor() *
        BalanceConfig.enemiesPerWaveIncrement;
    return (baseCount + increment).clamp(2, 12);
  }

  /// Select enemy types for wave
  List<String> _selectEnemyTypes() {
    // Early waves: simple enemies
    if (currentWave <= 3) {
      return List.filled(enemiesInWave, 'knight');
    }

    // Boss waves: one strong enemy + support
    if (currentWave % 5 == 0) {
      return ['knight', 'wizard', ...List.filled(enemiesInWave - 2, 'thief')];
    }

    // Mixed waves
    final types = <String>[];
    final availableTypes = ['knight', 'thief', 'wizard', 'trader'];

    for (int i = 0; i < enemiesInWave; i++) {
      types.add(availableTypes[i % availableTypes.length]);
    }

    return types;
  }

  /// Calculate wave completion reward
  int _calculateWaveReward() {
    int reward = BalanceConfig.goldPerWave + (currentWave * 10);

    // Bonus for fast completion
    if (waveStartTime != null) {
      final duration = DateTime.now().difference(waveStartTime!);
      if (duration.inSeconds < 30) {
        reward = (reward * 1.5).toInt();
      }
    }

    return reward;
  }

  /// Get difficulty multiplier
  double _getDifficultyMultiplier() {
    return 1.0 + (currentWave - 1) * 0.1;
  }

  /// Get spawn points for enemies
  List<Vector2> _getSpawnPoints() {
    return [
      Vector2(100, 600),
      Vector2(1800, 600),
      Vector2(950, 300),
      Vector2(300, 600),
      Vector2(1600, 600),
    ];
  }

  // ==========================================
  // REWARDS
  // ==========================================

  /// Reward player after wave
  void _rewardPlayer() {
    // Small health restore
    final healAmount = 20.0;
    final oldHealth = game.character.characterState.health;
    game.character.characterState.health = (game.character.characterState.health + healAmount).clamp(0, 100);
    final actualHeal = game.character.characterState.health - oldHealth;

    if (actualHeal > 0) {
      _eventBus.emit(CharacterHealedEvent(
        characterId: game.character.stats.name,
        healAmount: actualHeal,
        newHealth: game.character.characterState.health,
        healSource: 'wave_complete',
      ));
    }

    // Restore stamina
    game.character.characterState.stamina = game.character.characterState.maxStamina;
  }

  // ==========================================
  // EVENT HANDLERS
  // ==========================================

  void _onEnemyKilled(CharacterKilledEvent event) {
    // Only count AI enemies (not player death)
    if (event.victimId == game.character.stats.name) return;

    enemiesDefeatedThisWave++;
    totalEnemiesDefeated++;

    print('💀 Enemy defeated: $enemiesDefeatedThisWave/$enemiesInWave');
  }

  void _onGameStarted(GameStartedEvent event) {
    print('🎮 Game started: ${event.gameMode} as ${event.characterClass}');
  }

  // ==========================================
  // PUBLIC INTERFACE
  // ==========================================

  /// Force start next wave (skip wait)
  void forceNextWave() {
    if (!isWaveActive) {
      waveBreakTimer = 0;
    }
  }

  /// Get wave status string
  String getWaveStatus() {
    if (isWaveActive) {
      final remaining = enemiesInWave - enemiesDefeatedThisWave;
      return 'Wave $currentWave - $remaining enemies left';
    } else {
      return 'Next wave in ${waveBreakTimer.toInt()}s';
    }
  }

  /// Check if in active wave
  bool get inActiveWave => isWaveActive;

  /// Get wave progress (0.0 to 1.0)
  double get waveProgress {
    if (enemiesInWave == 0) return 0.0;
    return enemiesDefeatedThisWave / enemiesInWave;
  }

  // ==========================================
  // CLEANUP
  // ==========================================

  /// Dispose wave system
  void dispose() {
    // Cancel all subscriptions
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    print('🗑️  WaveSystem: Disposed');
  }
}
