import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:nomercy/player.dart';
import 'action_game.dart';

class HUD extends PositionComponent with HasGameRef<ActionGame> {
  final Player player;

  HUD({required this.player, required ActionGame game}) {
    priority = 100;
  }

  @override
  void render(Canvas canvas) {
    // Top-left HUD panel background - height shrunk as everything is in one line
    canvas.drawRect(
      const Rect.fromLTWH(20, 20, 280, 90),
      Paint()..color = Colors.black.withOpacity(0.7),
    );

    const textStyle = TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        shadows: [Shadow(blurRadius: 2, color: Colors.black, offset: Offset(1, 1))]
    );
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // --- Stats Row (Health, Money, Kills in one line) ---
    
    // Health
    _drawHeart(canvas, const Offset(45, 45), 22);
    textPainter.text = TextSpan(text: '${player.health.toInt()}', style: textStyle);
    textPainter.layout();
    textPainter.paint(canvas, const Offset(65, 35));

    // Money
    _drawCoin(canvas, const Offset(130, 45), 18);
    textPainter.text = TextSpan(text: '${player.stats.money}', style: textStyle);
    textPainter.layout();
    textPainter.paint(canvas, const Offset(150, 35));

    // Kills
    _drawSkull(canvas, const Offset(220, 45), 18);
    textPainter.text = TextSpan(text: '${gameRef.enemiesDefeated}', style: textStyle);
    textPainter.layout();
    textPainter.paint(canvas, const Offset(240, 35));

    // Health bar background (positioned below the stats line)
    canvas.drawRect(
      const Rect.fromLTWH(40, 70, 240, 12),
      Paint()..color = Colors.red.withOpacity(0.2),
    );
    // Dynamic Health bar fill
    final healthPercent = (player.health / 100).clamp(0.0, 1.0);
    canvas.drawRect(
      Rect.fromLTWH(40, 70, 240 * healthPercent, 12),
      Paint()..color = healthPercent > 0.3 ? Colors.green : Colors.orange,
    );

    // --- Attack Button Rendering ---
    _drawAttackButton(canvas);
  }

  void _drawAttackButton(Canvas canvas) {
    final buttonX = gameRef.size.x - 80;
    final buttonY = gameRef.size.y - 80;
    const radius = 35.0;

    canvas.drawCircle(
      Offset(buttonX, buttonY),
      radius,
      Paint()..color = Colors.red.withOpacity(0.6),
    );

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = const TextSpan(
      text: 'ATK',
      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(buttonX - textPainter.width / 2, buttonY - textPainter.height / 2));
  }

  void _drawHeart(Canvas canvas, Offset center, double size) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(FontAwesomeIcons.heart.codePoint),
      style: TextStyle(
        color: Colors.red,
        fontSize: size,
        fontFamily: FontAwesomeIcons.heart.fontFamily,
        package: FontAwesomeIcons.heart.fontFamily == null ? null : FontAwesomeIcons.heart.fontPackage,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));
  }

  void _drawCoin(Canvas canvas, Offset center, double size) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(FontAwesomeIcons.coins.codePoint),
      style: TextStyle(
        color: Colors.amber[300],
        fontSize: size,
        fontFamily: FontAwesomeIcons.coins.fontFamily,
        package: FontAwesomeIcons.coins.fontFamily == null ? null : FontAwesomeIcons.coins.fontPackage,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));
  }

  void _drawSkull(Canvas canvas, Offset center, double size) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(FontAwesomeIcons.skull.codePoint),
      style: TextStyle(
        color: Colors.grey[300],
        fontSize: size,
        fontFamily: FontAwesomeIcons.skull.fontFamily,
        package: FontAwesomeIcons.skull.fontFamily == null ? null : FontAwesomeIcons.skull.fontPackage,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));
  }
}
