// modules/core/lib/src/config/game_config_3d.dart

/// 3D-specific physics and world constants.
/// Extends (does not replace) the existing [GameConfig] values.
/// Y axis is "up"; gravity acts in the -Y direction (velocity.y decreases).
abstract final class GameConfig3D {
  GameConfig3D._();

  // ── Physics ────────────────────────────────────────────────────────────────

  /// Gravity (positive: applied as velocity.y -= gravity * dt each frame).
  static const double gravity      = 1000.0;
  static const double maxFallSpeed = 900.0;   // max downward speed (positive)

  /// Jump initial upward velocity (positive = up).
  static const double jumpVelocity       = 620.0;
  static const double doubleJumpVelocity = 520.0;
  static const double jumpStaminaCost    = 20.0;

  // ── Movement ──────────────────────────────────────────────────────────────

  /// Horizontal strafe (X) and forward/back (Z) speeds.
  static const double walkSpeedX = 280.0;
  static const double walkSpeedZ = 280.0;
  static const double runSpeedX  = 450.0;
  static const double runSpeedZ  = 450.0;

  /// Friction / resistance multipliers (applied per frame).
  static const double groundFrictionXZ = 0.82;
  static const double airResistanceXZ  = 0.97;
  static const double landingFriction  = 0.60;
  static const double stopThreshold    = 6.0;

  // ── Platform geometry ─────────────────────────────────────────────────────

  /// Default depth (Z thickness) of a platform box.
  static const double platformDepthZ   = 160.0;
  static const double platformHeight   = 80.0;    // Y thickness — tall enough to show 3D faces
  static const double groundSurfaceY   = 0.0;     // World Y of ground top face

  /// Snap window: character within this many world-units above a platform
  /// top counts as "landing" rather than passing through.
  static const double landSnapWindow   = 8.0;

  /// Maximum obstacle height (world-units) the character can step up onto
  /// automatically while walking, without needing to jump.
  static const double stepUpMax        = 75.0;

  // ── World / chunk ─────────────────────────────────────────────────────────

  /// Characters run along +Z; chunks tile in Z direction.
  static const double chunkDepthZ      = 3200.0;
  static const double chunkWidthX      = 1200.0;

  /// World Y of the infinite ground surface top face.
  static const double infiniteGroundY  = 0.0;

  /// Height of the infinite ground slab (visual only).
  static const double groundSlabHeight = 80.0;

  // ── Character geometry ────────────────────────────────────────────────────

  static const double characterSizeX   = 80.0;
  static const double characterSizeY   = 200.0;
  static const double characterSizeZ   = 60.0;

  // ── Camera ────────────────────────────────────────────────────────────────

  /// How far behind the player (in Z) the camera sits for 3rd-person feel.
  static const double cameraZOffset    = -600.0;  // camera is behind player

  /// Lerp speed for camera following.
  static const double cameraLerpSpeed  = 6.0;

  // ── Combat ────────────────────────────────────────────────────────────────

  static const double attackRangeZ = 180.0;   // forward reach
  static const double attackRangeX = 120.0;   // side reach
}