import 'dart:async';

import 'package:flame/components.dart';

import 'action_game.dart';
import 'game/bot_tactic.dart';
import 'game/character/knight.dart';
import 'game/character/thief.dart';
import 'game/character/trader.dart';
import 'game/character/wizard.dart';
import 'game/game_character.dart';
import 'game/tactic/aggressive_tactic.dart';
import 'game/tactic/balanced_tactic.dart';
import 'game/tactic/berserker_tactic.dart';
import 'game/tactic/defensive_tactic.dart';
import 'game/tactic/tactical_tactic.dart';
import 'game_mode.dart';
import 'player_type.dart';

class GameManager extends Component with HasGameRef<ActionGame> {
  final GameMode mode;

  // Wave system
  int currentWave = 0;
  int enemiesInWave = 0;
  int enemiesDefeatedThisWave = 0;
  bool isWaveActive = false;
  double waveBreakTimer = 0;
  final double waveBreakDuration = 5.0; // 5 seconds between waves

  // Difficulty scaling
  int totalEnemiesDefeated = 0;
  double difficultyMultiplier = 1.0;
  bool hasUpgradedBots = false;

  // Boss system
  bool isBossFight = false;
  GameCharacter? currentBoss;

  // Spawn positions
  final List<Vector2> spawnPoints = [];

  GameManager({this.mode = GameMode.survival}) {
    priority = 10; // Update before most components
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Initialize spawn points (corners and edges of map)
    spawnPoints.addAll([
      Vector2(100, 600),   // Left side
      Vector2(1800, 600),  // Right side
      Vector2(950, 300),   // Top center
      Vector2(300, 600),   // Left-center
      Vector2(1600, 600),  // Right-center
    ]);

    // Start the game based on mode
    _startGameMode();
  }

  void _startGameMode() {
    switch (mode) {
      case GameMode.survival:
        _startSurvivalMode();
        break;
      case GameMode.campaign:
        _startCampaignMode();
        break;
      case GameMode.bossFight:
        _startBossFight();
        break;
      case GameMode.training:
        _startTrainingMode();
        break;
    }
  }

  void _startSurvivalMode() {
    print('=== SURVIVAL MODE STARTED ===');
    print('Defeat waves of enemies!');
    currentWave = 0;
    _startNextWave();
  }

  void _startCampaignMode() {
    print('=== CAMPAIGN MODE STARTED ===');
    // Campaign has predefined waves and bosses
    currentWave = 1;
    _startCampaignWave(1);
  }

  void _startBossFight() {
    print('=== BOSS FIGHT STARTED ===');
    isBossFight = true;
    spawnBoss();
  }

  void _startTrainingMode() {
    print('=== TRAINING MODE ===');
    print('Practice against a passive enemy');
    spawnTrainingDummy();
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Update based on mode
    switch (mode) {
      case GameMode.survival:
        _updateSurvivalMode(dt);
        break;
      case GameMode.campaign:
        _updateCampaignMode(dt);
        break;
      case GameMode.bossFight:
        _updateBossFight(dt);
        break;
      case GameMode.training:
      // Training mode doesn't need updates
        break;
    }

    // Check for difficulty upgrades
    _checkDifficultyUpgrade();
  }

  void _updateSurvivalMode(double dt) {
    // Check if wave is complete
    if (isWaveActive && game.enemies.isEmpty) {
      _completeWave();
    }

    // Count down wave break
    if (!isWaveActive && waveBreakTimer > 0) {
      waveBreakTimer -= dt;
      if (waveBreakTimer <= 0) {
        _startNextWave();
      }
    }
  }

  void _updateCampaignMode(double dt) {
    // Similar to survival but with specific wave definitions
    if (isWaveActive && game.enemies.isEmpty) {
      _completeCampaignWave();
    }

    if (!isWaveActive && waveBreakTimer > 0) {
      waveBreakTimer -= dt;
      if (waveBreakTimer <= 0) {
        _startNextCampaignWave();
      }
    }
  }

  void _updateBossFight(double dt) {
    // Check if boss is defeated
    if (currentBoss != null && !game.enemies.contains(currentBoss)) {
      _defeatBoss();
    }
  }

  // ============= WAVE SYSTEM =============

  void _startNextWave() {
    currentWave++;
    enemiesDefeatedThisWave = 0;
    isWaveActive = true;

    print('\n╔════════════════════════════╗');
    print('║   WAVE $currentWave STARTING!    ║');
    print('╚════════════════════════════╝\n');

    // Spawn wave
    spawnEnemyWave(currentWave);

    // Every 5 waves, spawn a mini-boss
    if (currentWave % 5 == 0) {
      print('🔥 MINI-BOSS WAVE! 🔥');
      spawnMiniBoss();
    }
  }

  void _completeWave() {
    isWaveActive = false;
    waveBreakTimer = waveBreakDuration;

    print('\n✅ WAVE $currentWave COMPLETE!');
    print('Next wave in ${waveBreakDuration.toInt()} seconds...\n');

    // Reward player
    _rewardPlayer();
  }

  void spawnEnemyWave(int waveNumber) {
    // Calculate number of enemies based on wave
    final baseEnemies = 2;
    final bonusEnemies = (waveNumber / 3).floor();
    enemiesInWave = baseEnemies + bonusEnemies;
    enemiesInWave = enemiesInWave.clamp(2, 8); // Max 8 enemies per wave

    print('Spawning $enemiesInWave enemies...');

    // Define available tactics (unlock more as waves progress)
    final availableTactics = <BotTactic>[
      AggressiveTactic(),
      if (waveNumber >= 2) BalancedTactic(),
      if (waveNumber >= 3) DefensiveTactic(),
      if (waveNumber >= 4) TacticalTactic(),
      if (waveNumber >= 6) BerserkerTactic(),
    ];

    final availableClasses = ['knight', 'thief', 'wizard', 'trader'];

    for (int i = 0; i < enemiesInWave; i++) {
      // Random class and tactic
      final randomClass = availableClasses[i % availableClasses.length];
      final randomTactic = availableTactics[i % availableTactics.length];

      // Get spawn position
      final spawnPos = spawnPoints[i % spawnPoints.length];

      // Create enemy
      final enemy = _createCharacter(
        randomClass,
        spawnPos.clone(),
        PlayerType.bot,
        botTactic: randomTactic,
      );

      // Scale difficulty
      _scaleEnemyDifficulty(enemy, waveNumber);

      game.add(enemy);
      game.world.add(enemy);
      game.enemies.add(enemy);

      print('  - Spawned ${randomTactic.name} $randomClass at ${spawnPos.x.toInt()}, ${spawnPos.y.toInt()}');
    }
  }

  void spawnMiniBoss() {
    final miniBossClasses = ['knight', 'wizard'];
    final randomClass = miniBossClasses[currentWave % miniBossClasses.length];

    final miniBoss = _createCharacter(
      randomClass,
      Vector2(950, 400), // Center top
      PlayerType.bot,
      botTactic: BerserkerTactic(),
    );

    // Mini-boss stats (2x health, 1.3x damage)
    miniBoss.health = 200;
    miniBoss.stats.attackDamage *= 1.3;
    miniBoss.maxStamina = 130;
    miniBoss.stamina = 130;

    game.add(miniBoss);
    game.world.add(miniBoss);
    game.enemies.add(miniBoss);
    enemiesInWave++; // Count mini-boss

    print('  ⚠️  MINI-BOSS: ${randomClass.toUpperCase()}');
  }

  // ============= BOSS SYSTEM =============

  void spawnBoss() {
    print('\n╔══════════════════════════════╗');
    print('║  ⚔️  BOSS BATTLE BEGINS!  ⚔️  ║');
    print('╚══════════════════════════════╝\n');

    // Create boss (super tough knight)
    final boss = Knight(
      position: Vector2(950, 400),
      playerType: PlayerType.bot,
      botTactic: BerserkerTactic(),
    );

    // Boss stats (3x health, 1.5x damage, more stamina)
    boss.health = 300;
    boss.stats.attackDamage *= 1.5;
    boss.maxStamina = 200;
    boss.stamina = 200;
    boss.stats.power *= 1.5;
    boss.stats.dexterity *= 1.2;

    currentBoss = boss;

    game.add(boss);
    game.world.add(boss);
    game.enemies.add(boss);

    print('BOSS HEALTH: ${boss.health}');
    print('BOSS DAMAGE: ${boss.stats.attackDamage}');
  }

  void _defeatBoss() {
    print('\n╔══════════════════════════════╗');
    print('║  🎉  BOSS DEFEATED! 🎉       ║');
    print('╚══════════════════════════════╝\n');

    currentBoss = null;
    isBossFight = false;

    // Massive rewards
    game.player.stats.money += 500;
    game.player.health = 100; // Full heal

    print('💰 Reward: 500 gold!');
    print('❤️  Full health restored!');
  }

  // ============= CAMPAIGN MODE =============

  void _startCampaignWave(int waveNum) {
    currentWave = waveNum;
    isWaveActive = true;

    // Predefined campaign waves
    switch (waveNum) {
      case 1:
        print('CAMPAIGN WAVE 1: Tutorial - 2 Basic Knights');
        _spawnSpecificEnemies([
          {'class': 'knight', 'tactic': AggressiveTactic(), 'pos': 0},
          {'class': 'knight', 'tactic': AggressiveTactic(), 'pos': 1},
        ]);
        break;
      case 2:
        print('CAMPAIGN WAVE 2: Ranged Challenge - 3 Thieves');
        _spawnSpecificEnemies([
          {'class': 'thief', 'tactic': BalancedTactic(), 'pos': 0},
          {'class': 'thief', 'tactic': TacticalTactic(), 'pos': 2},
          {'class': 'thief', 'tactic': DefensiveTactic(), 'pos': 4},
        ]);
        break;
      case 3:
        print('CAMPAIGN WAVE 3: Magic Users - 2 Wizards');
        _spawnSpecificEnemies([
          {'class': 'wizard', 'tactic': DefensiveTactic(), 'pos': 1},
          {'class': 'wizard', 'tactic': TacticalTactic(), 'pos': 3},
        ]);
        break;
      case 4:
        print('CAMPAIGN WAVE 4: Mixed Squad - 4 Enemies');
        _spawnSpecificEnemies([
          {'class': 'knight', 'tactic': AggressiveTactic(), 'pos': 0},
          {'class': 'thief', 'tactic': TacticalTactic(), 'pos': 1},
          {'class': 'wizard', 'tactic': DefensiveTactic(), 'pos': 3},
          {'class': 'trader', 'tactic': BalancedTactic(), 'pos': 4},
        ]);
        break;
      case 5:
        print('CAMPAIGN WAVE 5: BOSS FIGHT!');
        spawnBoss();
        break;
      default:
        print('CAMPAIGN COMPLETE! Switching to survival...');
        // Switch to survival mode
        _startSurvivalMode();
    }
  }

  void _spawnSpecificEnemies(List<Map<String, dynamic>> configs) {
    enemiesInWave = configs.length;

    for (final config in configs) {
      final enemy = _createCharacter(
        config['class'] as String,
        spawnPoints[config['pos'] as int].clone(),
        PlayerType.bot,
        botTactic: config['tactic'] as BotTactic,
      );

      game.add(enemy);
      game.world.add(enemy);
      game.enemies.add(enemy);
    }
  }

  void _completeCampaignWave() {
    isWaveActive = false;
    waveBreakTimer = waveBreakDuration;

    print('✅ Campaign Wave $currentWave Complete!');
    _rewardPlayer();
  }

  void _startNextCampaignWave() {
    _startCampaignWave(currentWave + 1);
  }

  // ============= DIFFICULTY SCALING =============

  void _checkDifficultyUpgrade() {
    totalEnemiesDefeated = game.enemiesDefeated;

    // Every 10 kills, increase difficulty
    if (totalEnemiesDefeated >= 10 && !hasUpgradedBots) {
      updateBotDifficulty();
      hasUpgradedBots = true;
    }

    // Every 25 kills, another upgrade
    if (totalEnemiesDefeated >= 25 && hasUpgradedBots) {
      _upgradeAllBots();
    }
  }

  void updateBotDifficulty() {
    print('\n⚡ DIFFICULTY INCREASED! ⚡');
    print('Enemies are now smarter and stronger!\n');

    difficultyMultiplier += 0.2;

    // Upgrade all existing bots
    for (final enemy in game.enemies) {
      if (enemy.botTactic is! BerserkerTactic) {
        // Switch to smarter tactics
        enemy.botTactic = TacticalTactic();
        print('${enemy.stats.name} became Tactical!');
      }
    }
  }

  void _upgradeAllBots() {
    for (final enemy in game.enemies) {
      enemy.health = (enemy.health * 1.1).clamp(0, 150);
      enemy.stats.attackDamage *= 1.1;
    }
    print('⚡ All enemies upgraded: +10% health and damage!');
  }

  void _scaleEnemyDifficulty(GameCharacter enemy, int wave) {
    // Scale based on wave number
    final healthBonus = 1 + (wave - 1) * 0.1; // +10% per wave
    final damageBonus = 1 + (wave - 1) * 0.08; // +8% per wave

    enemy.health = (100 * healthBonus * difficultyMultiplier).clamp(50, 200);
    enemy.stats.attackDamage *= damageBonus * difficultyMultiplier;

    // Higher waves get more stamina
    if (wave >= 5) {
      enemy.maxStamina = 120;
      enemy.stamina = 120;
    }
  }

  // ============= TRAINING MODE =============

  void spawnTrainingDummy() {
    final dummy = Knight(
      position: Vector2(800, 600),
      playerType: PlayerType.bot,
      botTactic: DefensiveTactic(), // Only defends
    );

    // Dummy doesn't attack back (override in actual implementation)
    dummy.health = 1000; // Lots of health for practice

    game.add(dummy);
    game.world.add(dummy);
    game.enemies.add(dummy);

    print('Training dummy spawned - practice your combos!');
  }

  // ============= REWARDS =============

  void _rewardPlayer() {
    final goldReward = 50 + (currentWave * 10);
    game.player.stats.money += goldReward;

    // Small health restore
    game.player.health = (game.player.health + 20).clamp(0, 100);

    print('💰 Earned $goldReward gold!');
    print('❤️  +20 Health restored!');
  }

  // ============= HELPER =============

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

  // ============= PUBLIC INTERFACE =============

  void onEnemyDefeated() {
    enemiesDefeatedThisWave++;
    totalEnemiesDefeated++;
  }

  void forceNextWave() {
    if (!isWaveActive) {
      waveBreakTimer = 0;
    }
  }

  String getWaveStatus() {
    if (isWaveActive) {
      final remaining = enemiesInWave - enemiesDefeatedThisWave;
      return 'Wave $currentWave - $remaining enemies left';
    } else {
      return 'Wave Break - Next wave in ${waveBreakTimer.toInt()}s';
    }
  }
}