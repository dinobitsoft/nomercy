import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'dart:math' as math;

import 'action_game.dart';

class ImpactEffect extends PositionComponent with HasGameReference<ActionGame> {
  final Color color;
  double lifetime = 0.3;
  final List<ParticleData> particles = [];

  ImpactEffect({required super.position, required this.color}) {
    // Create particles
    for (int i = 0; i < 12; i++) {
      final angle = (i / 12) * math.pi * 2;
      particles.add(ParticleData(
        velocity: Vector2(math.cos(angle), math.sin(angle)) * 100,
        size: math.Random().nextDouble() * 4 + 2,
      ));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    lifetime -= dt;

    // Update particles
    for (final particle in particles) {
      particle.position += particle.velocity * dt;
      particle.velocity *= 0.95;  // Friction
      particle.size *= 0.95;
    }

    if (lifetime <= 0) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final opacity = lifetime / 0.3;

    for (final particle in particles) {
      canvas.drawCircle(
        Offset(particle.position.x, particle.position.y),
        particle.size,
        Paint()..color = color.withOpacity(opacity),
      );
    }
  }
}

class ParticleData {
  Vector2 position = Vector2.zero();
  Vector2 velocity;
  double size;

  ParticleData({required this.velocity, required this.size});
}