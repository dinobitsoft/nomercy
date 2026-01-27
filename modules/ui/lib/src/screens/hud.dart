import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HUD extends PositionComponent with HasGameRef<ActionGame> {
  final GameCharacter character;

  HUD({required this.character, required ActionGame game}) {
    priority = 100;
  }

  @override
  void render(Canvas canvas) {
    const textStyle = TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(blurRadius: 4, color: Colors.black, offset: Offset(2, 2)),
          Shadow(blurRadius: 4, color: Colors.black, offset: Offset(-1, -1)),
        ]
    );
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // --- Stats Row ---
    const double rowY = 20;
    const double textY = 10;

    // Health
    _drawHeart(canvas, const Offset(45, rowY), 22);
    textPainter.text = TextSpan(text: '${character.characterState.health.toInt()}', style: textStyle);
    textPainter.layout();
    textPainter.paint(canvas, const Offset(65, textY));

    // Money
    _drawCoin(canvas, const Offset(130, rowY), 18);
    textPainter.text = TextSpan(text: '${character.stats.money}', style: textStyle);
    textPainter.layout();
    textPainter.paint(canvas, const Offset(150, textY));

    // Kills
    _drawSkull(canvas, const Offset(220, rowY), 18);
    textPainter.text = TextSpan(text: '${gameRef.enemiesDefeated}', style: textStyle);
    textPainter.layout();
    textPainter.paint(canvas, const Offset(240, textY));

    // Health bar
    const double barY = 40;
    canvas.drawRect(
      const Rect.fromLTWH(40, barY, 240, 10),
      Paint()..color = Colors.black.withOpacity(0.5),
    );
    canvas.drawRect(
      const Rect.fromLTWH(41, barY + 1, 238, 8),
      Paint()..color = Colors.red.withOpacity(0.3),
    );

    final healthPercent = (character.characterState.health / 100).clamp(0.0, 1.0);
    if (healthPercent > 0) {
      canvas.drawRect(
        Rect.fromLTWH(41, barY + 1, 238 * healthPercent, 8),
        Paint()..color = healthPercent > 0.3 ? Colors.green : Colors.orange,
      );
    }

    // --- NEW: Stamina bar ---
    const double staminaY = 55;
    canvas.drawRect(
      const Rect.fromLTWH(40, staminaY, 240, 8),
      Paint()..color = Colors.black.withOpacity(0.5),
    );
    canvas.drawRect(
      const Rect.fromLTWH(41, staminaY + 1, 238, 6),
      Paint()..color = Colors.yellow.withOpacity(0.2),
    );

    final staminaPercent = (character.characterState.stamina / character.characterState.maxStamina).clamp(0.0, 1.0);
    if (staminaPercent > 0) {
      Color staminaColor = Colors.yellow;
      if (staminaPercent < 0.3) {
        staminaColor = Colors.orange;
      }
      canvas.drawRect(
        Rect.fromLTWH(41, staminaY + 1, 238 * staminaPercent, 6),
        Paint()..color = staminaColor,
      );
    }

    // Stamina icon
    _drawBolt(canvas, const Offset(25, staminaY + 4), 14);

    if (gameRef.enableMultiplayer && gameRef.totalSpawns > 0) {
      _drawSpawnCounter(canvas);
    }

    // --- Status Indicators ---
    _drawStatusIndicators(canvas);

    // --- Combo Counter ---
    if (character.characterState.comboCount > 1) {
      _drawComboCounter(canvas);
    }

    // --- Attack Button ---
    _drawAttackButton(canvas);

    // --- NEW: Dodge Button ---
    _drawDodgeButton(canvas);

    // --- NEW: Block Button ---
    _drawBlockButton(canvas);
  }

  void _drawSpawnCounter(Canvas canvas) {
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.bold,
      shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
    );
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final spawnText = 'SPAWNS: ${gameRef.availableSpawns} / ${gameRef.totalSpawns}';
    textPainter.text = TextSpan(text: spawnText, style: textStyle);
    textPainter.layout();

    // Position it below the health/stamina bars
    final x = 40.0;
    final y = 75.0;

    // Draw background for spawn counter
    final bgRect = Rect.fromLTWH(x - 5, y - 5, textPainter.width + 10, textPainter.height + 10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(5)),
      Paint()..color = Colors.black.withOpacity(0.4),
    );

    textPainter.paint(canvas, Offset(x, y));
  }

  void _drawStatusIndicators(Canvas canvas) {
    const double statusX = 40;
    const double statusY = 105; // Moved down to make room for spawn counter
    double xOffset = 0;

    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.bold,
      shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
    );
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    if (character.characterState.isStunned) {
      canvas.drawCircle(
        Offset(statusX + xOffset, statusY),
        12,
        Paint()..color = Colors.yellow.withOpacity(0.7),
      );
      textPainter.text = TextSpan(text: '⚡', style: textStyle);
      textPainter.layout();
      textPainter.paint(canvas, Offset(statusX + xOffset - 6, statusY - 8));
      xOffset += 30;
    }

    if (character.characterState.isDodging) {
      canvas.drawCircle(
        Offset(statusX + xOffset, statusY),
        12,
        Paint()..color = Colors.blue.withOpacity(0.7),
      );
      textPainter.text = TextSpan(text: '💨', style: textStyle);
      textPainter.layout();
      textPainter.paint(canvas, Offset(statusX + xOffset - 6, statusY - 8));
      xOffset += 30;
    }

    if (character.characterState.isBlocking) {
      canvas.drawCircle(
        Offset(statusX + xOffset, statusY),
        12,
        Paint()..color = Colors.blue.withOpacity(0.7),
      );
      textPainter.text = TextSpan(text: '🛡', style: textStyle);
      textPainter.layout();
      textPainter.paint(canvas, Offset(statusX + xOffset - 6, statusY - 8));
      xOffset += 30;
    }

    if (character.characterState.isAirborne && character.characterState.airborneTime > 0.5) {
      canvas.drawCircle(
        Offset(statusX + xOffset, statusY),
        12,
        Paint()..color = Colors.purple.withOpacity(0.7),
      );
      textPainter.text = TextSpan(text: '🪂', style: textStyle);
      textPainter.layout();
      textPainter.paint(canvas, Offset(statusX + xOffset - 6, statusY - 8));
    }
  }

  void _drawComboCounter(Canvas canvas) {
    final comboX = gameRef.size.x / 2;
    final comboY = 100.0;

    // Combo background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(comboX, comboY), width: 120, height: 50),
        const Radius.circular(10),
      ),
      Paint()..color = Colors.orange.withOpacity(0.8),
    );

    // Combo text
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: '${character.characterState.comboCount}x COMBO!',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        shadows: [Shadow(blurRadius: 4, color: Colors.black)],
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(comboX - textPainter.width / 2, comboY - textPainter.height / 2),
    );

    // Combo timer bar
    final comboPercent = (character.characterState.comboTimer / character.characterState.comboWindow).clamp(0.0, 1.0);
    canvas.drawRect(
      Rect.fromLTWH(comboX - 55, comboY + 18, 110 * comboPercent, 4),
      Paint()..color = Colors.yellow,
    );
  }

  void _drawAttackButton(Canvas canvas) {
    final buttonX = gameRef.size.x - 80;
    final buttonY = gameRef.size.y - 80;
    const radius = 35.0;

    // Glow effect when ready
    if (character.characterState.attackCooldown <= 0 && character.characterState.stamina >= 15) {
      canvas.drawCircle(
        Offset(buttonX, buttonY),
        radius + 5,
        Paint()..color = Colors.red.withOpacity(0.3),
      );
    }

    canvas.drawCircle(
      Offset(buttonX, buttonY),
      radius + 2,
      Paint()..color = Colors.black.withOpacity(0.3),
    );

    // Cooldown overlay
    if (character.characterState.attackCooldown > 0) {
      canvas.drawCircle(
        Offset(buttonX, buttonY),
        radius,
        Paint()..color = Colors.grey.withOpacity(0.6),
      );
    } else {
      canvas.drawCircle(
        Offset(buttonX, buttonY),
        radius,
        Paint()..color = Colors.red.withOpacity(0.7),
      );
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = const TextSpan(
      text: 'ATK',
      style: TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        shadows: [Shadow(blurRadius: 4, color: Colors.black)],
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(buttonX - textPainter.width / 2, buttonY - textPainter.height / 2),
    );
  }

  void _drawDodgeButton(Canvas canvas) {
    final buttonX = gameRef.size.x - 170;
    final buttonY = gameRef.size.y - 80;
    const radius = 30.0;

    // Glow when ready
    if (character.characterState.dodgeCooldown <= 0 && character.characterState.stamina >= 20) {
      canvas.drawCircle(
        Offset(buttonX, buttonY),
        radius + 5,
        Paint()..color = Colors.blue.withOpacity(0.3),
      );
    }

    canvas.drawCircle(
      Offset(buttonX, buttonY),
      radius + 2,
      Paint()..color = Colors.black.withOpacity(0.3),
    );

    // Cooldown overlay
    if (character.characterState.dodgeCooldown > 0 || character.characterState.stamina < 20) {
      canvas.drawCircle(
        Offset(buttonX, buttonY),
        radius,
        Paint()..color = Colors.grey.withOpacity(0.6),
      );

      // Cooldown timer
      if (character.characterState.dodgeCooldown > 0) {
        final textPainter = TextPainter(textDirection: TextDirection.ltr);
        textPainter.text = TextSpan(
          text: character.characterState.dodgeCooldown.toStringAsFixed(1),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(buttonX - textPainter.width / 2, buttonY - textPainter.height / 2),
        );
      }
    } else {
      canvas.drawCircle(
        Offset(buttonX, buttonY),
        radius,
        Paint()..color = Colors.blue.withOpacity(0.7),
      );

      final textPainter = TextPainter(textDirection: TextDirection.ltr);
      textPainter.text = const TextSpan(
        text: '💨',
        style: TextStyle(fontSize: 20),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(buttonX - textPainter.width / 2, buttonY - textPainter.height / 2),
      );
    }
  }

  void _drawBlockButton(Canvas canvas) {
    final buttonX = gameRef.size.x - 80;
    final buttonY = gameRef.size.y - 170;
    const radius = 30.0;

    canvas.drawCircle(
      Offset(buttonX, buttonY),
      radius + 2,
      Paint()..color = Colors.black.withOpacity(0.3),
    );

    // Active state
    if (character.characterState.isBlocking) {
      canvas.drawCircle(
        Offset(buttonX, buttonY),
        radius,
        Paint()..color = Colors.cyan.withOpacity(0.9),
      );
    } else if (character.characterState.stamina >= 10) {
      canvas.drawCircle(
        Offset(buttonX, buttonY),
        radius,
        Paint()..color = Colors.cyan.withOpacity(0.6),
      );
    } else {
      canvas.drawCircle(
        Offset(buttonX, buttonY),
        radius,
        Paint()..color = Colors.grey.withOpacity(0.6),
      );
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = const TextSpan(
      text: '🛡',
      style: TextStyle(fontSize: 20),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(buttonX - textPainter.width / 2, buttonY - textPainter.height / 2),
    );
  }

  void _drawHeart(Canvas canvas, Offset center, double size) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(FontAwesomeIcons.heart.codePoint),
      style: TextStyle(
        color: Colors.red,
        fontSize: size,
        fontFamily: FontAwesomeIcons.heart.fontFamily,
        package: FontAwesomeIcons.heart.fontPackage,
        shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
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
        package: FontAwesomeIcons.coins.fontPackage,
        shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
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
        package: FontAwesomeIcons.skull.fontPackage,
        shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));
  }

  void _drawBolt(Canvas canvas, Offset center, double size) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(FontAwesomeIcons.bolt.codePoint),
      style: TextStyle(
        color: Colors.yellow,
        fontSize: size,
        fontFamily: FontAwesomeIcons.bolt.fontFamily,
        package: FontAwesomeIcons.bolt.fontPackage,
        shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));
  }
}