// modules/core/lib/src/world3d/world_pos.dart

import 'dart:math' as math;

/// 3D world coordinate.
/// X = right, Y = up (gravity pulls -Y), Z = depth (forward into screen).
class WorldPos {
  double x, y, z;

  WorldPos(this.x, this.y, this.z);
  WorldPos.zero()  : x = 0, y = 0, z = 0;
  WorldPos.xy(double x, double y) : this(x, y, 0);

  WorldPos clone() => WorldPos(x, y, z);

  void setFrom(WorldPos other) { x = other.x; y = other.y; z = other.z; }
  void setZero()               { x = 0;       y = 0;       z = 0;       }

  WorldPos operator +(WorldPos o) => WorldPos(x + o.x, y + o.y, z + o.z);
  WorldPos operator -(WorldPos o) => WorldPos(x - o.x, y - o.y, z - o.z);
  WorldPos operator *(double s)   => WorldPos(x * s,   y * s,   z * s);

  void addScaled(WorldPos v, double s) {
    x += v.x * s;
    y += v.y * s;
    z += v.z * s;
  }

  double get length => math.sqrt(x * x + y * y + z * z);
  double get lengthXZ => math.sqrt(x * x + z * z);

  @override
  String toString() => 'WorldPos(${x.toStringAsFixed(1)}, '
      '${y.toStringAsFixed(1)}, ${z.toStringAsFixed(1)})';
}

/// 3D axis-aligned bounding box.
class AABB3D {
  final double minX, maxX;
  final double minY, maxY;
  final double minZ, maxZ;

  const AABB3D({
    required this.minX, required this.maxX,
    required this.minY, required this.maxY,
    required this.minZ, required this.maxZ,
  });

  factory AABB3D.fromCenter({
    required WorldPos center,
    required double sizeX,
    required double sizeY,
    required double sizeZ,
  }) => AABB3D(
    minX: center.x - sizeX / 2, maxX: center.x + sizeX / 2,
    minY: center.y - sizeY / 2, maxY: center.y + sizeY / 2,
    minZ: center.z - sizeZ / 2, maxZ: center.z + sizeZ / 2,
  );

  bool overlapsXZ(AABB3D o) =>
      minX < o.maxX && maxX > o.minX &&
          minZ < o.maxZ && maxZ > o.minZ;

  bool overlapsXYZ(AABB3D o) =>
      overlapsXZ(o) &&
          minY < o.maxY && maxY > o.minY;

  double get centerX => (minX + maxX) / 2;
  double get centerY => (minY + maxY) / 2;
  double get centerZ => (minZ + maxZ) / 2;
}