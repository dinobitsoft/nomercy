import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class ChestParticle extends PositionComponent with HasGameReference<ActionGame> {
  Vector2 velocity;
  final Color color;
  double lifetime = 1.0;
  double chestSize = 4;

  ChestParticle({
    required Vector2 position,
    required this.velocity,
    required this.color,
  }) : super(position: position);

  @override
  void update(double dt) {
    super.update(dt);

    position += velocity * dt;
    velocity.y += 300 * dt;  // Gravity
    velocity *= 0.98;  // Friction

    lifetime -= dt;
    chestSize = 4 * (lifetime / 1.0);

    if (lifetime <= 0) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(
      Offset.zero,
      chestSize,
      Paint()..color = color.withOpacity(lifetime / 1.0),
    );
  }
}