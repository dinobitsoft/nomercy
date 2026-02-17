import 'dart:ui' as ui;

import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class EnhancedPlatform extends GamePlatform {

  ui.Image? overlayTexture;
  ui.Image? edgeTexture;
  Sprite? sprite;  // Now we manage sprite manually
  bool textureLoaded = false;

  // Visual enhancement flags
  final bool useOverlay;
  final bool useShadow;
  final bool useEdgeHighlight;
  final double weatheringIntensity;

  EnhancedPlatform({
  required super.position,
  required super.size,
  required super.platformType,  // Now uses super parameter
  this.useOverlay = true,
  this.useShadow = true,
  this.useEdgeHighlight = false,
  this.weatheringIntensity = 0.7,
  });

  @override
  Future<void> onLoad() async {
  await super.onLoad();

  try {
  // Load base texture
  final baseImage = await game.images.load('$platformType.png');
  sprite = Sprite(baseImage);
  textureLoaded = true;

  // Load overlay
  if (useOverlay) {
  try {
  overlayTexture = await game.images.load('${platformType}_overlay.png');
  print('✅ Loaded overlay for $platformType');
  } catch (e) {
  print('⚠️ No overlay for $platformType');
  }
  }

  // Load edge highlights
  if (useEdgeHighlight) {
  try {
  edgeTexture = await game.images.load('${platformType}_edge.png');
  } catch (e) {
  // Silent fail
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

  // LAYER 1: Base texture
  sprite!.render(
  canvas,
  position: Vector2(-size.x / 2, -size.y / 2),
  size: size,
  );

  // LAYER 2: Overlay
  if (overlayTexture != null) {
  _renderOverlay(canvas);
  }

  // LAYER 3: Edge highlight
  if (edgeTexture != null) {
  _renderEdgeHighlight(canvas);
  }

  // LAYER 4: Depth shadow
  if (useShadow) {
  _renderDepthShadow(canvas);
  }

  // LAYER 5: Border
  _renderBorder(canvas);
  }

  void _renderOverlay(Canvas canvas) {
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
  final shadowPaint = Paint()
  ..color = Colors.black.withOpacity(0.3)
  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

  canvas.drawRect(
  Rect.fromLTWH(
  -size.x / 2,
  size.y / 2 - 5,
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
