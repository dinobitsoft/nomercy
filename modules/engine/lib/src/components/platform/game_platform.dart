// modules/engine/lib/src/components/platform/game_platform.dart

import 'package:engine/engine.dart';
import 'package:flame/components.dart';

/// Abstract base class for all game platforms
/// This allows polymorphism between TiledPlatform and EnhancedPlatform
abstract class GamePlatform extends PositionComponent
    with HasGameReference<ActionGame> {

  final String platformType;

  GamePlatform({
    required Vector2 position,
    required Vector2 size,
    required this.platformType,
  }) : super(
    position: position,
    size: size,
    anchor: Anchor.center,
  );

  /// Common interface for collision detection
  bool collidesWithPoint(Vector2 point) {
    final left = position.x - size.x / 2;
    final right = position.x + size.x / 2;
    final top = position.y - size.y / 2;
    final bottom = position.y + size.y / 2;

    return point.x >= left &&
        point.x <= right &&
        point.y >= top &&
        point.y <= bottom;
  }

  /// Common interface for getting platform bounds
  ({double left, double right, double top, double bottom}) getBounds() {
    return (
    left: position.x - size.x / 2,
    right: position.x + size.x / 2,
    top: position.y - size.y / 2,
    bottom: position.y + size.y / 2,
    );
  }
}