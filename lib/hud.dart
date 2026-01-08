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
    // Top-left HUD panel (optimized for landscape)
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

    // Money and Kills (horizontal layout)
    textPainter.text = TextSpan(
      text: '\$${player.stats.money}  |  Kills: ${game.enemiesDefeated}',
      style: textStyle,
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(30, 90));

    // Attack button (top right, larger for landscape)
    canvas.drawCircle(
      Offset(game.size.x - 100, 100),
      60,
      Paint()..color = Colors.red.withOpacity(0.6),
    );

    textPainter.text = const TextSpan(
      text: 'ATK',
      style: TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(game.size.x - 125, 85));
  }

  @override
  void update(double dt) {
    super.update(dt);
    position = -game.camera.viewfinder.position + Vector2(0, 0);
  }
}