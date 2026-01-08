import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';

class Platform extends PositionComponent {
  final String platformType;

  Platform({
    required Vector2 position,
    required Vector2 size,
    this.platformType = 'brick',
  }) : super(position: position, size: size) {
    anchor = Anchor.center;
  }

  @override
  void render(Canvas canvas) {
    Color color;
    switch (platformType) {
      case 'brick':
        color = const Color(0xFF8B4513); // Brown
        break;
      case 'ground':
        color = const Color(0xFF228B22); // Green
        break;
      default:
        color = const Color(0xFF666666); // Gray
    }

    final paint = Paint()..color = color;
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
      paint,
    );

    // Draw border
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