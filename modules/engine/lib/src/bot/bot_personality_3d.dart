// modules/engine/lib/src/bot/bot_personality_3d.dart

/// Personality presets for 3D bot enemies.
///
/// Kept in engine so [EnemyCharacter3D] and [ActionGame3D.spawnEnemy3D] can
/// reference the enum without depending on the `ai` module.
enum BotPersonality3D {
  /// Charges straight at the player, attacks immediately, never retreats.
  aggressor,

  /// Approaches from the side, strafes to find openings, uses dodge.
  flanker,

  /// Maintains optimal firing distance, kites backwards when crowded.
  ranged,

  /// Opportunistic — only commits when the player is busy, retreats hard on hit.
  coward,
}
