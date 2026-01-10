import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../action_game.dart';
import '../player.dart';
import '../reward_text.dart';
import 'chest_data.dart';
import 'chest_particle.dart';
import 'chest_reward.dart';

class Chest extends PositionComponent with HasGameRef<ActionGame> {
  final ChestData data;
  bool isOpened = false;
  bool isPlayerNear = false;
  ChestReward? reward;
  double glowTimer = 0;
  double floatOffset = 0;

  Chest({
    required Vector2 position,
    required this.data,
  }) : super(position: position) {
    size = Vector2(50, 50);
    anchor = Anchor.center;
    isOpened = data.opened;

    // Generate random reward
    _generateReward();
  }

  void _generateReward() {
    final random = math.Random();
    final roll = random.nextInt(100);

    if (roll < 40) {
      reward = ChestReward.health;
    } else if (roll < 80) {
      reward = ChestReward.money;
    } else {
      reward = ChestReward.nothing;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!isOpened) {
      glowTimer += dt;
      floatOffset = math.sin(glowTimer * 2) * 3;

      // Check if player is near
      final player = game.player;
      final distance = position.distanceTo(player.position);
      isPlayerNear = distance < 80;
    }
  }

  void open(Player player) {
    if (isOpened) return;

    isOpened = true;

    // Apply reward
    switch (reward!) {
      case ChestReward.health:
        final healthGain = 30.0;
        player.health = math.min(100, player.health + healthGain);
        _showRewardText('+$healthGain HP', Colors.green);
        break;

      case ChestReward.money:
        final moneyGain = 50;
        player.stats.money += moneyGain;
        _showRewardText('+\$$moneyGain', Colors.yellow);
        break;

      case ChestReward.nothing:
        _showRewardText('Empty!', Colors.grey);
        break;
    }

    // Particle effect
    _createOpenEffect();
  }

  void _showRewardText(String text, Color color) {
    final rewardText = RewardText(
      text: text,
      position: position.clone(),
      color: color,
    );
    game.add(rewardText);
  }

  void _createOpenEffect() {
    for (int i = 0; i < 20; i++) {
      final angle = (i / 20) * math.pi * 2;
      final particle = ChestParticle(
        position: position.clone(),
        velocity: Vector2(math.cos(angle), math.sin(angle)) * 150,
        color: Colors.yellow,
      );
      game.add(particle);
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();

    // Float effect for unopened chests
    if (!isOpened) {
      canvas.translate(0, floatOffset);
    }

    // Glow for unopened chests
    if (!isOpened && isPlayerNear) {
      final glowPaint = Paint()
        ..color = Colors.yellow.withOpacity(0.3 + math.sin(glowTimer * 5) * 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: 60, height: 60),
        glowPaint,
      );
    }

    // Chest body
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isOpened
          ? [const Color(0xFF8B7355), const Color(0xFF654321)]
          : [const Color(0xFFDAA520), const Color(0xFFB8860B)],
    );

    final rect = Rect.fromCenter(center: Offset.zero, width: 50, height: 30);
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);

    // Chest border
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF8B6914)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Chest lid
    final lidColor = isOpened
        ? const Color(0xFF555555)
        : const Color(0xFFFFD700);
    canvas.drawRect(
      Rect.fromCenter(center: const Offset(0, -22), width: 50, height: 15),
      Paint()..color = lidColor,
    );
    canvas.drawRect(
      Rect.fromCenter(center: const Offset(0, -22), width: 50, height: 15),
      Paint()
        ..color = const Color(0xFF8B6914)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Lock/Keyhole
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: 10, height: 15),
      Paint()..color = const Color(0xFF4A4A4A),
    );

    // Lock decoration
    canvas.drawCircle(
      Offset.zero,
      5,
      Paint()..color = isOpened ? const Color(0xFF888888) : const Color(0xFFFFD700),
    );
    canvas.drawCircle(
      Offset.zero,
      5,
      Paint()
        ..color = const Color(0xFF8B6914)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // "E to open" hint
    if (isPlayerNear && !isOpened) {
      final textPainter = TextPainter(
        text: const TextSpan(
          text: '⬇ Down to Open',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 4),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -40));
    }

    canvas.restore();
  }
}