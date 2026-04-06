// modules/core/lib/src/world3d/iso_projection.dart

import 'dart:math' as math;
import 'package:flame/components.dart';

import 'world_pos.dart';

/// Oblique projection for a "corridor runner" 3D platformer.
///
/// World axes:
///   X → right on screen
///   Y → up  (inverted to screen Y)
///   Z → depth (into screen / forward)
///
/// Projection:
///   screenX = worldX  +  worldZ × kZX
///   screenY = −worldY +  worldZ × kZY
///
/// [kZX] = −0.30: depth shifts left on screen (camera is to the upper-right).
/// [kZY] = +0.40: depth shifts down on screen (floor recedes toward horizon).
///
/// With both components, the three world axes project to three distinct
/// screen directions — X→right, Y→up, Z→lower-left — so all box faces
/// (top, front, right) occupy different screen regions and a 3D parallelepiped
/// is clearly visible.
///
/// Depth sort: higher worldZ (further from camera) is drawn first (lower
/// Flame priority value).  We also factor in worldX to avoid z-fighting
/// on diagonally placed platforms.
class IsoProjection {
  /// Horizontal screen shift per world-unit of Z (negative = leftward).
  static const double kZX = -0.30;
  /// Vertical screen shift per world-unit of Z (positive = downward).
  static const double kZY =  0.40;

  /// Project a world position to screen (Flame world-space) coordinates.
  /// [screenOrigin] is where worldPos(0,0,0) maps on the Flame canvas.
  static Vector2 project(WorldPos wp, {Vector2? screenOrigin}) {
    final base = screenOrigin ?? Vector2.zero();
    return Vector2(
      base.x + wp.x + wp.z * kZX,
      base.y - wp.y + wp.z * kZY,
    );
  }

  /// Overload for raw components (avoids allocating WorldPos).
  static Vector2 projectXYZ(double wx, double wy, double wz,
      {Vector2? screenOrigin}) {
    final base = screenOrigin ?? Vector2.zero();
    return Vector2(base.x + wx + wz * kZX, base.y - wy + wz * kZY);
  }

  /// Flame render priority for depth sorting.
  /// Lower value → drawn first (behind).
  /// Characters at same Z but different X get sub-sorted correctly.
  static int depthPriority(WorldPos wp) =>
      (wp.z * 100 + wp.x * 0.5).round();

  /// Inverse: given a screen delta (dx, dy), compute world (dx, dz).
  /// Used for touch / mouse picking (flat ground, worldY = 0).
  static (double worldDX, double worldDZ) unprojectXZ(double sdx, double sdy) {
    // screenY = wz * kZY  →  wz = sdy / kZY
    // screenX = wx + wz * kZX  →  wx = sdx - wz * kZX
    final wz = sdy / kZY;
    return (sdx - wz * kZX, wz);
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