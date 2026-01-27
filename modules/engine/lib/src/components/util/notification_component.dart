import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class NotificationComponent extends PositionComponent {
  final String message;
  final Color color;
  final IconData? icon;
  double lifetime;
  double opacity = 1.0;

  NotificationComponent({
    required this.message,
    required this.color,
    required this.lifetime,
    this.icon,
    required Vector2 position,
  }) : super(position: position) {
    priority = 999; // Always on top
  }

  @override
  void update(double dt) {
    super.update(dt);

    lifetime -= dt;
    position.y -= 30 * dt; // Float up

    // Fade out in last 0.5 seconds
    if (lifetime < 0.5) {
      opacity = lifetime / 0.5;
    }

    if (lifetime <= 0) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: message,
        style: TextStyle(
          color: color.withOpacity(opacity),
          fontSize: 20,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(opacity),
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );
  }
}