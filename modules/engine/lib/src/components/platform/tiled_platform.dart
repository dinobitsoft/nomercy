import 'dart:ui' as ui;

import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Refactored TiledPlatform - Rectangle adjusts to fit texture tiles
/// Instead of scaling tiles, we adjust the platform size to accommodate whole tiles
class TiledPlatform extends GamePlatform {
  ui.Image? texture;
  bool textureLoaded = false;

  // Original requested size
  final Vector2 _requestedSize;

  // Actual size after fitting to tiles
  Vector2 _fittedSize = Vector2.zero();

  // Tile layout
  int _tilesX = 1;
  int _tilesY = 1;

  TiledPlatform({
    required super.position,
    required super.size,
    required super.platformType,
  }) : _requestedSize = size.clone();

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    try {
      // Load tiling texture
      final textureName = '${platformType}_tile.png';
      texture = await game.images.load(textureName);
      textureLoaded = true;

      // Adjust size to fit tiles after texture loads
      _adjustSizeToFitTexture();
    } catch (e) {
      // Try loading regular texture
      try {
        final textureName = '$platformType.png';
        texture = await game.images.load(textureName);
        textureLoaded = true;
        _adjustSizeToFitTexture();
      } catch (e2) {
        print('Could not load texture for $platformType: $e2');
        textureLoaded = false;
      }
    }
  }

  /// NEW: Adjust platform size to fit whole tiles perfectly
  void _adjustSizeToFitTexture() {
    if (texture == null) return;

    final textureWidth = texture!.width.toDouble();
    final textureHeight = texture!.height.toDouble();

    // Calculate how many tiles fit in requested size
    _tilesX = (_requestedSize.x / textureWidth).round().clamp(1, 50);
    _tilesY = (_requestedSize.y / textureHeight).round().clamp(1, 20);

    // Special handling for ground platforms (single row)
    if (platformType == 'ground') {
      _tilesY = 1;
    }

    // Calculate fitted size (exact multiple of tile dimensions)
    _fittedSize.x = _tilesX * textureWidth;
    _fittedSize.y = _tilesY * textureHeight;

    // Update component size to fitted size
    size = _fittedSize.clone();

    print('📐 Platform adjusted: requested ${_requestedSize.x.toInt()}x${_requestedSize.y.toInt()} '
        '→ fitted ${_fittedSize.x.toInt()}x${_fittedSize.y.toInt()} '
        '($_tilesX×$_tilesY tiles)');
  }

  @override
  void render(Canvas canvas) {
    if (textureLoaded && texture != null) {
      // Draw tiled texture with NO scaling - 1:1 pixel mapping
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

  /// REFACTORED: Draw tiles at 1:1 scale (no stretching)
  void _drawTiledTexture(Canvas canvas) {
    if (texture == null) return;

    final textureWidth = texture!.width.toDouble();
    final textureHeight = texture!.height.toDouble();

    // Draw tiles at original size
    canvas.save();
    canvas.translate(-size.x / 2, -size.y / 2);

    for (int x = 0; x < _tilesX; x++) {
      for (int y = 0; y < _tilesY; y++) {
        // Destination rectangle (1:1 with texture size)
        final destRect = Rect.fromLTWH(
          x * textureWidth,
          y * textureHeight,
          textureWidth,
          textureHeight,
        );

        // Source rectangle (full texture)
        final srcRect = Rect.fromLTWH(
          0,
          0,
          textureWidth,
          textureHeight,
        );

        // Draw without scaling - crisp pixel-perfect rendering
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

  /// Get the size difference between requested and fitted
  Vector2 getSizeDelta() => _fittedSize - _requestedSize;

  /// Check if size was adjusted
  bool get wasAdjusted => (_fittedSize - _requestedSize).length > 0.1;
}