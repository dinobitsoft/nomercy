import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../action_game.dart';

class RewardText extends PositionComponent with HasGameRef<ActionGame> {
  final String text;
  final Color color;
  double lifetime = 2.0;
  double opacity = 1.0;

  RewardText({
    required this.text,
    required Vector2 position,
    required this.color,
  }) : super(position: position);

  @override
  void update(double dt) {
    super.update(dt);

    position.y -= 50 * dt;  // Float up
    lifetime -= dt;
    opacity = lifetime / 2.0;

    if (lifetime <= 0) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color.withOpacity(opacity),
          fontSize: 24,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(opacity),
              blurRadius: 4,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
  }
}
