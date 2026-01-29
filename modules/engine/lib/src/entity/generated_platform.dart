import 'package:core/core.dart';
import 'package:flame/components.dart';

class GeneratedPlatform {
  final Vector2 position;
  final Vector2 size;
  final String type;
  final int layer;

  GeneratedPlatform({
    required this.position,
    required this.size,
    required this.type,
    this.layer = 0,
  });

  bool overlaps(GeneratedPlatform other, {double margin = 20}) {
    return (position.x - size.x / 2 - margin < other.position.x + other.size.x / 2 + margin) &&
        (position.x + size.x / 2 + margin > other.position.x - other.size.x / 2 - margin) &&
        (position.y - size.y / 2 - margin < other.position.y + other.size.y / 2 + margin) &&
        (position.y + size.y / 2 + margin > other.position.y - other.size.y / 2 - margin);
  }

  bool isReachableFrom(GeneratedPlatform other) {
    final verticalDist = (position.y - other.position.y).abs();
    final horizontalDist = (position.x - other.position.x).abs();

    if (position.y < other.position.y) {
      return verticalDist <= GameConfig.maxJumpHeight &&
          horizontalDist <= GameConfig.maxJumpDistance;
    } else {
      return horizontalDist <= GameConfig.maxJumpDistance * 1.5;
    }
  }
}