import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:nomercy/game/game_character.dart';

import '../game/action_game.dart';
import '../reward_text.dart';
import 'chest_data.dart';
import 'chest_particle.dart';
import 'chest_reward.dart';

class Chest extends PositionComponent with HasGameReference<ActionGame> {
  final ChestData data;
  bool isOpened = false;
  bool isPlayerNear = false;
  ChestReward? reward;
  double glowTimer = 0;
  double floatOffset = 0;

  Sprite? closedSprite;
  Sprite? openedSprite;

  Chest({
    required Vector2 position,
    required this.data,
  }) : super(position: position) {
    size = Vector2(80, 80); // Increased size for high-res sprites
    anchor = Anchor.center;
    isOpened = data.opened;

    // Generate random reward
    _generateReward();
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    closedSprite = await game.loadSprite('dower_chest.png');
    openedSprite = await game.loadSprite('dower_chest_opened.png');
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
      isPlayerNear = distance < 100; // Adjusted for larger size
    }
  }

  void open(GameCharacter player) {
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
        _showRewardText('+\$${moneyGain}', Colors.yellow);
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
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
      canvas.drawCircle(Offset.zero, 45, glowPaint);
    }

    // Render Sprite
    final sprite = isOpened ? openedSprite : closedSprite;
    if (sprite != null) {
      sprite.render(
        canvas,
        position: Vector2(-size.x / 2, -size.y / 2),
        size: size,
      );
    }

    // "E to open" hint
    if (isPlayerNear && !isOpened) {
      final textPainter = TextPainter(
        text: const TextSpan(
          text: '⬇ Down to Open',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 4),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -size.y / 2 - 20));
    }

    canvas.restore();
  }
}
