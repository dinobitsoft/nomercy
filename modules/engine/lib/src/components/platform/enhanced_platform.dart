import 'dart:ui' as ui;

import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class EnhancedPlatform extends SpriteComponent with HasGameReference<ActionGame> {
  final String platformType;
  bool textureLoaded = false;
  ui.Image? overlayTexture;

  EnhancedPlatform({
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
      // Load main texture
      final textureName = '$platformType.png';
      final image = await game.images.load(textureName);
      sprite = Sprite(image);
      textureLoaded = true;

      // Try to load overlay (cracks, moss, etc.)
      try {
        overlayTexture = await game.images.load('${platformType}_overlay.png');
      } catch (e) {
        // Overlay is optional
      }
    } catch (e) {
      print('Could not load texture for $platformType: $e');
      textureLoaded = false;
    }
  }

  @override
  void render(Canvas canvas) {
    if (textureLoaded && sprite != null) {
      // Render base texture
      super.render(canvas);

      // Render overlay if available
      if (overlayTexture != null) {
        final overlayPaint = Paint()..color = Colors.white.withOpacity(0.7);
        canvas.drawImageRect(
          overlayTexture!,
          Rect.fromLTWH(0, 0, overlayTexture!.width.toDouble(), overlayTexture!.height.toDouble()),
          Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
          overlayPaint,
        );
      }

      // Add depth with shadow
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawRect(
        Rect.fromLTWH(-size.x / 2, size.y / 2 - 5, size.x, 5),
        shadowPaint,
      );

      // Border
      final borderPaint = Paint()
        ..color = Colors.black.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
        borderPaint,
      );
    } else {
      _renderFallback(canvas);
    }
  }

  void _renderFallback(Canvas canvas) {
    Color baseColor;
    Color accentColor;

    switch (platformType) {
      case 'brick':
        baseColor = const Color(0xFF8B4513);
        accentColor = const Color(0xFF654321);
        break;
      case 'ground':
        baseColor = const Color(0xFF228B22);
        accentColor = const Color(0xFF1A6B1A);
        break;
      default:
        baseColor = const Color(0xFF666666);
        accentColor = const Color(0xFF444444);
    }

    // Draw base
    final paint = Paint()..color = baseColor;
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
      paint,
    );

    // Draw pattern
    if (platformType == 'brick') {
      _drawBrickPattern(canvas, accentColor);
    } else if (platformType == 'ground') {
      _drawGroundPattern(canvas, accentColor);
    }

    // Border
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
      borderPaint,
    );
  }

  void _drawBrickPattern(Canvas canvas, Color accentColor) {
    final paint = Paint()
      ..color = accentColor
      ..strokeWidth = 2;

    // Draw brick lines
    final brickWidth = 60.0;
    final brickHeight = 20.0;

    for (double y = -size.y / 2; y < size.y / 2; y += brickHeight) {
      // Horizontal line
      canvas.drawLine(
        Offset(-size.x / 2, y),
        Offset(size.x / 2, y),
        paint,
      );

      // Vertical lines (alternating pattern)
      final offset = ((y / brickHeight) % 2 == 0) ? 0.0 : brickWidth / 2;
      for (double x = -size.x / 2 + offset; x < size.x / 2; x += brickWidth) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x, y + brickHeight),
          paint,
        );
      }
    }
  }

  void _drawGroundPattern(Canvas canvas, Color accentColor) {
    final paint = Paint()..color = accentColor;

    // Draw grass/dirt texture
    for (int i = 0; i < 20; i++) {
      final x = -size.x / 2 + (i * size.x / 20);
      final height = 3 + (i % 3) * 2;

      canvas.drawRect(
        Rect.fromLTWH(x, -size.y / 2, size.x / 20, height.toDouble()),
        paint,
      );
    }
  }
}
