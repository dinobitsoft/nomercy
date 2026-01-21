import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'action_game.dart';

class TiledPlatform extends PositionComponent with HasGameReference<ActionGame> {
  final String platformType;
  ui.Image? texture;
  bool textureLoaded = false;

  TiledPlatform({
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
      // Load tiling texture
      final textureName = '${platformType}_tile.png';
      texture = await game.images.load(textureName);
      textureLoaded = true;
    } catch (e) {
      // Try loading regular texture
      try {
        final textureName = '$platformType.png';
        texture = await game.images.load(textureName);
        textureLoaded = true;
      } catch (e2) {
        print('Could not load texture for $platformType: $e2');
        textureLoaded = false;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (textureLoaded && texture != null) {
      // Draw tiled texture
      _drawTiledTexture(canvas);

      // Draw border
      final borderPaint = Paint()
        ..color = Colors.black.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
        borderPaint,
      );
    } else {
      // Fallback rendering
      _renderFallback(canvas);
    }
  }

  void _drawTiledTexture(Canvas canvas) {
    if (texture == null) return;

    final textureWidth = texture!.width.toDouble();
    final textureHeight = texture!.height.toDouble();

    // Calculate how many tiles we need
    final tilesX = (size.x / textureWidth).ceil();
    final tilesY = (size.y / textureHeight).ceil();

    // Draw tiles
    canvas.save();
    canvas.translate(-size.x / 2, -size.y / 2);

    for (int x = 0; x < tilesX; x++) {
      for (int y = 0; y < tilesY; y++) {
        final destRect = Rect.fromLTWH(
          x * textureWidth,
          y * textureHeight,
          textureWidth,
          textureHeight,
        );

        final srcRect = Rect.fromLTWH(
          0,
          0,
          textureWidth,
          textureHeight,
        );

        canvas.drawImageRect(texture!, srcRect, destRect, Paint());
      }
    }

    canvas.restore();
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