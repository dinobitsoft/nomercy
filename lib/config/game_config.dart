// lib/config/game_config.dart

/// Core game configuration - immutable constants
class GameConfig {
  GameConfig._(); // Private constructor

  // === PHYSICS ===
  static const double gravity = 1000.0;
  static const double maxFallSpeed = 800.0;
  static const double groundFriction = 0.85;
  static const double airResistance = 0.98;

  // === CHARACTER ===
  static const double characterWidth = 240.0;
  static const double characterHeight = 240.0;
  static const double characterBaseHealth = 100.0;
  static const double characterBaseStamina = 100.0;
  static const double lowHealthThreshold = 0.2; // 20%

  // === COMBAT ===
  static const double attackCommitTime = 0.3;
  static const double attackCooldown = 0.5;
  static const double dodgeDuration = 0.3;
  static const double dodgeCooldown = 2.0;
  static const double blockStaminaDrain = 10.0;
  static const double comboWindow = 1.5;

  // === MOVEMENT ===
  static const double jumpVelocity = -300.0;
  static const double jumpStaminaCost = 20.0;
  static const double dodgeStaminaCost = 20.0;
  static const double hardLandingThreshold = 400.0;
  static const double landingRecoveryTime = 0.25;

  // === PROJECTILES ===
  static const double projectileSpeed = 400.0;
  static const double projectileLifetime = 3.0;
  static const int maxProjectilesPerCharacter = 10;

  // === CAMERA ===
  static const double cameraZoom = 1.2;
  static const double cameraWidth = 1280.0;
  static const double cameraHeight = 720.0;
  static const double cameraSmoothness = 0.1;

  // === PERFORMANCE ===
  static const int targetFPS = 60;
  static const double fixedUpdateInterval = 1.0 / 60.0;
  static const int maxParticles = 100;
  static const bool enableShadows = true;
  static const bool enableParticles = true;

  // === NETWORKING ===
  static const String serverUrl = 'http://10.0.2.2:3000';
  static const double networkUpdateRate = 10.0; // Hz
  static const double networkTimeout = 5.0;
  static const int maxPlayers = 8;

  // === AUDIO ===
  static const double masterVolume = 0.8;
  static const double musicVolume = 0.6;
  static const double sfxVolume = 1.0;

  // === UI ===
  static const double joystickRadius = 50.0;
  static const double buttonRadius = 35.0;
  static const double hudMargin = 40.0;
}

// lib/config/balance_config.dart

/// Game balance configuration - tunable values
/// Can be modified without recompilation in production
class BalanceConfig {
  // Character stats multipliers
  static const Map<String, double> characterMultipliers = {
    'knight': 1.0,
    'thief': 0.9,
    'wizard': 0.85,
    'trader': 0.95,
  };

  // Damage scaling
  static const double baseDamage = 15.0;
  static const double comboDamageMultiplier = 0.2; // +20% per combo
  static const double criticalHitChance = 0.1; // 10%
  static const double criticalHitMultiplier = 2.0;

  // Enemy scaling
  static const double enemyHealthPerWave = 10.0; // +10 HP per wave
  static const double enemyDamagePerWave = 0.08; // +8% damage per wave
  static const int enemiesPerWaveBase = 2;
  static const int enemiesPerWaveIncrement = 1; // Every 3 waves

  // Economy
  static const int goldPerKill = 20;
  static const int goldPerWave = 50;
  static const double itemDropChance = 0.4; // 40%
  static const double weaponDropChance = 0.2; // 20%

  // Loot tables
  static const Map<String, double> dropRates = {
    'health_potion': 0.4,
    'weapon_common': 0.15,
    'weapon_rare': 0.04,
    'weapon_legendary': 0.01,
  };

  // Difficulty modifiers
  static const Map<String, Map<String, double>> difficultyMods = {
    'easy': {
      'playerDamage': 1.2,
      'enemyDamage': 0.8,
      'enemyHealth': 0.8,
      'dropRate': 1.5,
    },
    'normal': {
      'playerDamage': 1.0,
      'enemyDamage': 1.0,
      'enemyHealth': 1.0,
      'dropRate': 1.0,
    },
    'hard': {
      'playerDamage': 0.9,
      'enemyDamage': 1.3,
      'enemyHealth': 1.4,
      'dropRate': 0.7,
    },
    'expert': {
      'playerDamage': 0.8,
      'enemyDamage': 1.6,
      'enemyHealth': 1.8,
      'dropRate': 0.5,
    },
  };

  /// Get difficulty modifier
  static double getDifficultyMod(String difficulty, String stat) {
    return difficultyMods[difficulty]?[stat] ?? 1.0;
  }

  /// Calculate scaled enemy stats
  static Map<String, double> getEnemyStats(int wave, String difficulty) {
    final baseMod = getDifficultyMod(difficulty, 'enemyHealth');
    final damageMod = getDifficultyMod(difficulty, 'enemyDamage');

    return {
      'health': (100 + wave * enemyHealthPerWave) * baseMod,
      'damage': baseDamage * (1 + wave * enemyDamagePerWave) * damageMod,
    };
  }

  /// Calculate drop chance
  static double getDropChance(String difficulty, String itemType) {
    final baseRate = dropRates[itemType] ?? 0.0;
    final difficultyMod = getDifficultyMod(difficulty, 'dropRate');
    return baseRate * difficultyMod;
  }
}

// lib/config/debug_config.dart

/// Debug configuration - only active in debug builds
class DebugConfig {
  static const bool enabled = true; // Set to false in production

  // Visual debugging
  static const bool showCollisionBoxes = false;
  static const bool showVelocityVectors = false;
  static const bool showFPS = true;
  static const bool showPoolStats = true;
  static const bool showAIDebug = false;

  // Performance monitoring
  static const bool logFrameTime = false;
  static const bool logMemoryUsage = false;
  static const bool logNetworkLatency = false;

  // Gameplay cheats (debug only)
  static const bool godMode = false;
  static const bool infiniteStamina = false;
  static const bool oneHitKill = false;
  static const bool unlimitedMoney = false;

  // Testing
  static const bool skipIntro = true;
  static const bool fastWaves = false;
  static const int startingWave = 1;
  static const String forceCharacter = ''; // Empty = player choice

  /// Log debug message
  static void log(String message) {
    if (enabled) {
      print('🐛 [DEBUG] $message');
    }
  }

  /// Log performance metric
  static void logPerformance(String metric, double value) {
    if (enabled && logFrameTime) {
      print('⚡ [PERF] $metric: ${value.toStringAsFixed(2)}');
    }
  }
}
