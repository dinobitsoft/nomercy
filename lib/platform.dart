import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'action_game.dart';

class Platform extends SpriteComponent with HasGameRef<ActionGame> {
  final String platformType;
  bool textureLoaded = false;

  Platform({
    required Vector2 position,
    required Vector2 size,
    this.platformType = 'brick',
  }) : super(position: position, size: size) {
    anchor = Anchor.center;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    try {
      // Load texture based on platform type
      final textureName = '$platformType.png';
      final image = await game.images.load(textureName);

      // Create sprite from image
      sprite = Sprite(image);
      textureLoaded = true;
    } catch (e) {
      print('Could not load texture for $platformType: $e');
      textureLoaded = false;
    }
  }

  @override
  void render(Canvas canvas) {
    if (textureLoaded && sprite != null) {
      // Render textured sprite
      super.render(canvas);

      // Optional: Add border for clarity
      final borderPaint = Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
        borderPaint,
      );
    } else {
      // Fallback: render solid color
      _renderFallback(canvas);
    }
  }

  void _renderFallback(Canvas canvas) {
    Color color;
    switch (platformType) {
      case 'brick':
        color = const Color(0xFF8B4513);
        break;
      case 'ground':
        color = const Color(0xFF228B22);
        break;
      default:
        color = const Color(0xFF666666);
    }

    final paint = Paint()..color = color;
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
      paint,
    );

    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
      borderPaint,
    );
  }
}