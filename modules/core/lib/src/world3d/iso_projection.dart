// modules/core/lib/src/world3d/iso_projection.dart

import 'dart:math' as math;
import 'package:flame/components.dart';

import 'world_pos.dart';

/// Cabinet / oblique projection for a "corridor runner" 3D platformer.
///
/// World axes:
///   X → right on screen
///   Y → up  (inverted to screen Y)
///   Z → depth (into screen / forward)
///
/// Projection:
///   screenX = worldX
///   screenY = −worldY  +  worldZ × kZ
///
/// [kZ] controls how much depth recedes vertically (default 0.40).
/// Increase for a higher camera angle, decrease for flatter perspective.
///
/// Depth sort: higher worldZ (further from camera) is drawn first (lower
/// Flame priority value).  We also factor in worldX to avoid z-fighting
/// on diagonally placed platforms.
class IsoProjection {
  static const double kZ = 0.40;

  /// Project a world position to screen (Flame world-space) coordinates.
  /// [screenOrigin] is where worldPos(0,0,0) maps on the Flame canvas.
  static Vector2 project(WorldPos wp, {Vector2? screenOrigin}) {
    final base = screenOrigin ?? Vector2.zero();
    return Vector2(
      base.x + wp.x,
      base.y - wp.y + wp.z * kZ,
    );
  }

  /// Overload for raw components (avoids allocating WorldPos).
  static Vector2 projectXYZ(double wx, double wy, double wz,
      {Vector2? screenOrigin}) {
    final base = screenOrigin ?? Vector2.zero();
    return Vector2(base.x + wx, base.y - wy + wz * kZ);
  }

  /// Flame render priority for depth sorting.
  /// Lower value → drawn first (behind).
  /// Characters at same Z but different X get sub-sorted correctly.
  static int depthPriority(WorldPos wp) =>
      (wp.z * 100 + wp.x * 0.5).round();

  /// Inverse: given a screen delta (dx, dy), compute world (dx, dz).
  /// Used for touch / mouse picking.
  static (double worldDX, double worldDZ) unprojectXZ(double sdx, double sdy) {
    // screenX = worldX → worldDX = sdx
    // screenY = -worldY + worldZ*kZ → for flat ground (Y=0): worldZ = sdy/kZ
    return (sdx, sdy / kZ);
  }

  // ── Sprite flipping helpers ──────────────────────────────────────────────

  /// Returns true when the character should render as mirrored.
  /// In a corridor runner: facing -Z (toward camera) always shows front.
  /// Facing +X → right, facing -X → left (flip sprite).
  static bool shouldFlipX(double facingAngleXZ) {
    // angle 0 = +X right, π = −X left
    return math.cos(facingAngleXZ) < 0;
  }

  // ── Platform visible size ────────────────────────────────────────────────

  /// Compute the 2D bounding rect of a 3D box after projection.
  /// Used for platform rendered size.
  static ({double w, double h}) projectedPlatformSize(
      double sizeX, double sizeY, double sizeZ) {
    final topLeft     = projectXYZ(0,       sizeY, 0);
    final topRight    = projectXYZ(sizeX,   sizeY, 0);
    final botLeft     = projectXYZ(0,       0,     sizeZ);
    final botRight    = projectXYZ(sizeX,   0,     sizeZ);

    final xs = [topLeft.x, topRight.x, botLeft.x, botRight.x];
    final ys = [topLeft.y, topRight.y, botLeft.y, botRight.y];

    return (
    w: xs.reduce(math.max) - xs.reduce(math.min),
    h: ys.reduce(math.max) - ys.reduce(math.min),
    );
  }
}