import 'package:flutter/material.dart';
import 'package:flame/components.dart';

import 'package:nomercy/player.dart';
import 'action_game.dart';

class HUD extends PositionComponent with HasGameRef<ActionGame> {
  final Player player;
  final ActionGame game;

  HUD({required this.player, required this.game}) {
    priority = 100;
  }

  @override
  void render(Canvas canvas) {
    // Top-left HUD panel
    canvas.drawRect(
      const Rect.fromLTWH(20, 20, 280, 100),
      Paint()..color = Colors.black.withOpacity(0.7),
    );

    const textStyle = TextStyle(color: Colors.white, fontSize: 16);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Health
    textPainter.text = TextSpan(text: 'HP: ${player.health.toInt()}', style: textStyle);
    textPainter.layout();
    textPainter.paint(canvas, const Offset(30, 30));

    // Health bar
    canvas.drawRect(
      const Rect.fromLTWH(30, 60, 240, 20),
      Paint()..color = Colors.red,
    );
    canvas.drawRect(
      Rect.fromLTWH(30, 60, 240 * (player.health / 100), 20),
      Paint()..color = Colors.green,
    );

    // Money and Kills
    textPainter.text = TextSpan(
      text: '\$${player.stats.money}  |  Kills: ${game.enemiesDefeated}',
      style: textStyle,
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(30, 90));

    // Attack button - Updated to bottom right and 2x smaller
    // Logic position: Vector2(size.x - 80, size.y - 80)
    final buttonX = game.size.x - 80;
    final buttonY = game.size.y - 80;
    final radius = 30.0; // 2 times smaller than original 60
    
    canvas.drawCircle(
      Offset(buttonX, buttonY),
      radius,
      Paint()..color = Colors.red.withOpacity(0.6),
    );

    textPainter.text = const TextSpan(
      text: 'ATK',
      style: TextStyle(
        color: Colors.white,
        fontSize: 14, // Smaller font for smaller button
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(buttonX - 14, buttonY - 8));
  }
}
