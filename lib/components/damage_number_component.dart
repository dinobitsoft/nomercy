import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/material.dart';

class DamageNumberComponent extends PositionComponent {
  final double damage;
  final bool isCritical;
  final Color color;
  double lifetime = 1.5;
  double opacity = 1.0;
  final Vector2 velocity;

  DamageNumberComponent({
    required this.damage,
    required this.isCritical,
    required this.color,
    required Vector2 position,
  })  : velocity = Vector2(0, -100),
        super(position: position) {
    priority = 998;
  }

  @override
  void update(double dt) {
    super.update(dt);

    position += velocity * dt;
    velocity.y += 50 * dt; // Gravity

    lifetime -= dt;
    if (lifetime < 0.5) {
      opacity = lifetime / 0.5;
    }

    if (lifetime <= 0) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final fontSize = isCritical ? 32.0 : 24.0;
    final text = isCritical ? '${damage.toInt()}!' : damage.toInt().toString();

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color.withOpacity(opacity),
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(opacity),
              blurRadius: 6,
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