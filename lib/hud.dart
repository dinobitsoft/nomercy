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
    canvas.drawRect(
      const Rect.fromLTWH(10, 10, 250, 140),
      Paint()..color = Colors.black.withOpacity(0.7),
    );

    const textStyle = TextStyle(color: Colors.white, fontSize: 14);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    textPainter.text = TextSpan(text: 'HP: ${player.health.toInt()}', style: textStyle);
    textPainter.layout();
    textPainter.paint(canvas, const Offset(20, 20));

    canvas.drawRect(
      const Rect.fromLTWH(20, 45, 200, 15),
      Paint()..color = Colors.red,
    );
    canvas.drawRect(
      Rect.fromLTWH(20, 45, 200 * (player.health / 100), 15),
      Paint()..color = Colors.green,
    );

    textPainter.text = TextSpan(text: 'Money: \$${player.stats.money}', style: textStyle);
    textPainter.layout();
    textPainter.paint(canvas, const Offset(20, 70));

    textPainter.text = TextSpan(text: 'Kills: ${game.enemiesDefeated}', style: textStyle);
    textPainter.layout();
    textPainter.paint(canvas, const Offset(20, 95));

    textPainter.text = const TextSpan(text: 'Tap red button to attack', style: TextStyle(color: Colors.yellow, fontSize: 12));
    textPainter.layout();
    textPainter.paint(canvas, const Offset(20, 120));

    canvas.drawCircle(
      Offset(game.size.x - 60, 60),
      40,
      Paint()..color = Colors.red.withOpacity(0.5),
    );
    textPainter.text = const TextSpan(text: 'ATK', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold));
    textPainter.layout();
    textPainter.paint(canvas, Offset(game.size.x - 80, 52));

    canvas.drawRect(
      Rect.fromLTWH(game.size.x - 220, 130, 210, 160),
      Paint()..color = Colors.black.withOpacity(0.7),
    );

    textPainter.text = const TextSpan(text: 'Stats (Upgrade: \$50)', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold));
    textPainter.layout();
    textPainter.paint(canvas, Offset(game.size.x - 210, 140));

    final statsNames = ['Power', 'Magic', 'Dexterity', 'Intelligence'];
    final statsValues = [
      player.stats.power.toInt(),
      player.stats.magic.toInt(),
      player.stats.dexterity.toInt(),
      player.stats.intelligence.toInt(),
    ];

    for (int i = 0; i < statsNames.length; i++) {
      final yPos = 165.0 + i * 30.0;

      textPainter.text = TextSpan(
        text: '${statsNames[i]}: ${statsValues[i]}',
        style: const TextStyle(color: Colors.white, fontSize: 11),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(game.size.x - 210, yPos));

      canvas.drawRect(
        Rect.fromLTWH(game.size.x - 80, yPos, 60, 20),
        Paint()..color = player.stats.money >= 50 ? Colors.green : Colors.grey,
      );

      textPainter.text = const TextSpan(
        text: '+5 (\$50)',
        style: TextStyle(color: Colors.white, fontSize: 9),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(game.size.x - 75, yPos + 3));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    position = -game.camera.viewfinder.position + Vector2(0, 0);
  }
}