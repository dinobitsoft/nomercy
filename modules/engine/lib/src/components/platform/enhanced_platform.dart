import 'dart:ui' as ui;
import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class EnhancedPlatform extends SpriteComponent
    with HasGameReference<ActionGame> {

  final String platformType;
  bool textureLoaded = false;
  ui.Image? overlayTexture;
  ui.Image? edgeTexture;  // NEW: Edge highlights

  // Visual enhancement flags
  final bool useOverlay;
  final bool useShadow;
  final bool useEdgeHighlight;
  final double weatheringIntensity;  // 0.0 - 1.0

  EnhancedPlatform({
    required Vector2 position,
    required Vector2 size,
    this.platformType = 'brick',
    this.useOverlay = true,
    this.useShadow = true,
    this.useEdgeHighlight = false,
    this.weatheringIntensity = 0.7,
  }) : super(position: position, size: size) {
    anchor = Anchor.center;
    priority = 10;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    try {
      // STEP 1: Load base texture
      final baseImage = await game.images.load('$platformType.png');
      sprite = Sprite(baseImage);
      textureLoaded = true;

      // STEP 2: Load overlay (optional but recommended)
      if (useOverlay) {
        try {
          overlayTexture = await game.images.load('${platformType}_overlay.png');
          print('✅ Loaded overlay for $platformType');
        } catch (e) {
          print('⚠️ No overlay for $platformType (fallback to base only)');
        }
      }

      // STEP 3: Load edge highlights (optional polish)
      if (useEdgeHighlight) {
        try {
          edgeTexture = await game.images.load('${platformType}_edge.png');
        } catch (e) {
          // Silent fail - edge is pure polish
        }
      }

    } catch (e) {
      print('❌ Failed to load $platformType textures: $e');
      textureLoaded = false;
    }
  }

  @override
  void render(Canvas canvas) {
    if (!textureLoaded || sprite == null) {
      _renderFallback(canvas);
      return;
    }

    // LAYER 1: Base texture (always present)
    super.render(canvas);

    // LAYER 2: Overlay details (breaks repetition)
    if (overlayTexture != null) {
      _renderOverlay(canvas);
    }

    // LAYER 3: Edge highlights (polish)
    if (edgeTexture != null) {
      _renderEdgeHighlight(canvas);
    }

    // LAYER 4: Depth shadow (3D effect)
    if (useShadow) {
      _renderDepthShadow(canvas);
    }

    // LAYER 5: Border (definition)
    _renderBorder(canvas);
  }

  void _renderOverlay(Canvas canvas) {
    // Apply weathering intensity
    final overlayPaint = Paint()
      ..color = Colors.white.withOpacity(weatheringIntensity);

    canvas.drawImageRect(
      overlayTexture!,
      Rect.fromLTWH(
          0, 0,
          overlayTexture!.width.toDouble(),
          overlayTexture!.height.toDouble()
      ),
      Rect.fromCenter(
          center: Offset.zero,
          width: size.x,
          height: size.y
      ),
      overlayPaint,
    );
  }

  void _renderEdgeHighlight(Canvas canvas) {
    final edgePaint = Paint()
      ..color = Colors.white.withOpacity(0.3);

    canvas.drawImageRect(
      edgeTexture!,
      Rect.fromLTWH(0, 0, edgeTexture!.width.toDouble(), edgeTexture!.height.toDouble()),
      Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
      edgePaint,
    );
  }

  void _renderDepthShadow(Canvas canvas) {
    // Bottom shadow for depth perception
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawRect(
      Rect.fromLTWH(
          -size.x / 2,
          size.y / 2 - 5,  // 5px shadow at bottom
          size.x,
          5
      ),
      shadowPaint,
    );
  }

  void _renderBorder(Canvas canvas) {
    final borderPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
      borderPaint,
    );
  }

  void _renderFallback(Canvas canvas) {
    // Fallback when textures fail to load
    final color = _getFallbackColor();

    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
      Paint()..color = color,
    );

    _renderBorder(canvas);
  }

  Color _getFallbackColor() {
    switch (platformType) {
      case 'brick': return const Color(0xFF8B4513);
      case 'ground': return const Color(0xFF228B22);
      case 'stone': return const Color(0xFF808080);
      case 'wood': return const Color(0xFFDEB887);
      default: return const Color(0xFF666666);
    }
  }
}