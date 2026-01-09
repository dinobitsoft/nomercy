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

    // Attack button (visual only here, logic is in ActionGame.onTapDown)
    // Note: Since this is now in the viewport, coordinates should be relative to the viewport size.
    // However, ActionGame uses game.size.x in onTapDown for the click logic.
    // We'll keep the rendering consistent with the logic.
    final buttonX = game.size.x - 100;
    
    canvas.drawCircle(
      Offset(buttonX, 100),
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
    textPainter.paint(canvas, Offset(buttonX - 25, 85));
  }
  
  // Removed manual positioning logic from update() as we'll add this to the camera's viewport
}
