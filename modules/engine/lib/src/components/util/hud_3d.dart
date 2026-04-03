import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// HUD overlay for the 3D game mode.
///
/// Reads health, stamina, kills, and combo state from
/// [ActionGame3D.character3D] instead of [GameCharacter].
class HUD3D extends PositionComponent with HasGameReference<ActionGame3D> {

  HUD3D() {
    priority = 100;
  }

  GameCharacterState get _state => game.character3D.characterState;
  CharacterStats     get _stats => game.character3D.stats;

  @override
  void render(Canvas canvas) {
    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.bold,
      shadows: [
        Shadow(blurRadius: 4, color: Colors.black, offset: Offset(2, 2)),
        Shadow(blurRadius: 4, color: Colors.black, offset: Offset(-1, -1)),
      ],
    );
    final tp = TextPainter(textDirection: TextDirection.ltr);

    // ── Stats row ──────────────────────────────────────────────────────────
    const double rowY = 20;
    const double textY = 10;

    // Health
    _drawIcon(canvas, FontAwesomeIcons.heart, Colors.red, const Offset(45, rowY), 22);
    tp.text = TextSpan(text: '${_state.health.toInt()}', style: textStyle);
    tp.layout();
    tp.paint(canvas, const Offset(65, textY));

    // Money
    _drawIcon(canvas, FontAwesomeIcons.coins, Colors.amber, const Offset(130, rowY), 18);
    tp.text = TextSpan(text: '${_stats.money}', style: textStyle);
    tp.layout();
    tp.paint(canvas, const Offset(150, textY));

    // Kills
    _drawIcon(canvas, FontAwesomeIcons.skull, Colors.grey, const Offset(220, rowY), 18);
    tp.text = TextSpan(text: '${game.enemiesDefeated}', style: textStyle);
    tp.layout();
    tp.paint(canvas, const Offset(240, textY));

    // ── Health bar ─────────────────────────────────────────────────────────
    const double barY = 40;
    canvas.drawRect(
      const Rect.fromLTWH(40, barY, 240, 10),
      Paint()..color = Colors.black.withOpacity(0.5),
    );
    canvas.drawRect(
      const Rect.fromLTWH(41, barY + 1, 238, 8),
      Paint()..color = Colors.red.withOpacity(0.3),
    );

    final hp = (_state.health / 100).clamp(0.0, 1.0);
    if (hp > 0) {
      canvas.drawRect(
        Rect.fromLTWH(41, barY + 1, 238 * hp, 8),
        Paint()..color = hp > 0.3 ? Colors.green : Colors.orange,
      );
    }

    // ── Stamina bar ────────────────────────────────────────────────────────
    const double staminaY = 55;
    canvas.drawRect(
      const Rect.fromLTWH(40, staminaY, 240, 8),
      Paint()..color = Colors.black.withOpacity(0.5),
    );
    canvas.drawRect(
      const Rect.fromLTWH(41, staminaY + 1, 238, 6),
      Paint()..color = Colors.yellow.withOpacity(0.2),
    );

    final sp = (_state.stamina / _state.maxStamina).clamp(0.0, 1.0);
    if (sp > 0) {
      canvas.drawRect(
        Rect.fromLTWH(41, staminaY + 1, 238 * sp, 6),
        Paint()..color = sp < 0.3 ? Colors.orange : Colors.yellow,
      );
    }
    _drawIcon(canvas, FontAwesomeIcons.bolt, Colors.yellow, const Offset(25, staminaY + 4), 14);

    // ── Status indicators ──────────────────────────────────────────────────
    _drawStatusIndicators(canvas);

    // ── Combo counter ──────────────────────────────────────────────────────
    if (_state.comboCount > 1) {
      _drawComboCounter(canvas);
    }

    // ── Action buttons ─────────────────────────────────────────────────────
    _drawAttackButton(canvas);
    _drawDodgeButton(canvas);
    _drawBlockButton(canvas);
  }

  // ── Status indicators ────────────────────────────────────────────────────

  void _drawStatusIndicators(Canvas canvas) {
    const double statusX = 40;
    const double statusY = 80;
    double xOff = 0;

    final style = TextStyle(
      color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold,
      shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
    );
    final tp = TextPainter(textDirection: TextDirection.ltr);

    void indicator(String emoji, Color color) {
      canvas.drawCircle(Offset(statusX + xOff, statusY), 12,
          Paint()..color = color.withOpacity(0.7));
      tp.text = TextSpan(text: emoji, style: style);
      tp.layout();
      tp.paint(canvas, Offset(statusX + xOff - 6, statusY - 8));
      xOff += 30;
    }

    if (_state.isStunned)   indicator('⚡', Colors.yellow);
    if (_state.isDodging)   indicator('💨', Colors.blue);
    if (_state.isBlocking)  indicator('🛡', Colors.blue);
    if (_state.isAirborne && _state.airborneTime > 0.5) {
      indicator('🪂', Colors.purple);
    }
  }

  // ── Combo counter ────────────────────────────────────────────────────────

  void _drawComboCounter(Canvas canvas) {
    final cx = game.size.x / 2;
    const cy = 100.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: 120, height: 50),
        const Radius.circular(10),
      ),
      Paint()..color = Colors.orange.withOpacity(0.8),
    );

    final tp = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: '${_state.comboCount}x COMBO!',
        style: const TextStyle(
          color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
          shadows: [Shadow(blurRadius: 4, color: Colors.black)],
        ),
      )
      ..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));

    final comboPercent = (_state.comboTimer / _state.comboWindow).clamp(0.0, 1.0);
    canvas.drawRect(
      Rect.fromLTWH(cx - 55, cy + 18, 110 * comboPercent, 4),
      Paint()..color = Colors.yellow,
    );
  }

  // ── Action buttons ───────────────────────────────────────────────────────

  void _drawAttackButton(Canvas canvas) {
    final bx = game.size.x - 80;
    final by = game.size.y - 80;
    const r = 35.0;
    final ready = _state.attackCooldown <= 0 && _state.stamina >= 15;

    if (ready) {
      canvas.drawCircle(Offset(bx, by), r + 5,
          Paint()..color = Colors.red.withOpacity(0.3));
    }
    canvas.drawCircle(Offset(bx, by), r + 2,
        Paint()..color = Colors.black.withOpacity(0.3));
    canvas.drawCircle(Offset(bx, by), r,
        Paint()..color = (_state.attackCooldown > 0
            ? Colors.grey : Colors.red).withOpacity(0.7));

    final tp = TextPainter(textDirection: TextDirection.ltr)
      ..text = const TextSpan(
        text: 'ATK',
        style: TextStyle(color: Colors.white, fontSize: 16,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
      )
      ..layout();
    tp.paint(canvas, Offset(bx - tp.width / 2, by - tp.height / 2));
  }

  void _drawDodgeButton(Canvas canvas) {
    final bx = game.size.x - 170;
    final by = game.size.y - 80;
    const r = 30.0;
    final ready = _state.dodgeCooldown <= 0 && _state.stamina >= 20;

    if (ready) {
      canvas.drawCircle(Offset(bx, by), r + 5,
          Paint()..color = Colors.blue.withOpacity(0.3));
    }
    canvas.drawCircle(Offset(bx, by), r + 2,
        Paint()..color = Colors.black.withOpacity(0.3));

    if (!ready) {
      canvas.drawCircle(Offset(bx, by), r,
          Paint()..color = Colors.grey.withOpacity(0.6));
      if (_state.dodgeCooldown > 0) {
        final tp = TextPainter(textDirection: TextDirection.ltr)
          ..text = TextSpan(
            text: _state.dodgeCooldown.toStringAsFixed(1),
            style: const TextStyle(color: Colors.white, fontSize: 12,
                fontWeight: FontWeight.bold),
          )
          ..layout();
        tp.paint(canvas, Offset(bx - tp.width / 2, by - tp.height / 2));
      }
    } else {
      canvas.drawCircle(Offset(bx, by), r,
          Paint()..color = Colors.blue.withOpacity(0.7));
      final tp = TextPainter(textDirection: TextDirection.ltr)
        ..text = const TextSpan(text: '💨', style: TextStyle(fontSize: 20))
        ..layout();
      tp.paint(canvas, Offset(bx - tp.width / 2, by - tp.height / 2));
    }
  }

  void _drawBlockButton(Canvas canvas) {
    final bx = game.size.x - 80;
    final by = game.size.y - 170;
    const r = 30.0;

    canvas.drawCircle(Offset(bx, by), r + 2,
        Paint()..color = Colors.black.withOpacity(0.3));

    final Color color;
    if (_state.isBlocking) {
      color = Colors.cyan.withOpacity(0.9);
    } else if (_state.stamina >= 10) {
      color = Colors.cyan.withOpacity(0.6);
    } else {
      color = Colors.grey.withOpacity(0.6);
    }
    canvas.drawCircle(Offset(bx, by), r, Paint()..color = color);

    final tp = TextPainter(textDirection: TextDirection.ltr)
      ..text = const TextSpan(text: '🛡', style: TextStyle(fontSize: 20))
      ..layout();
    tp.paint(canvas, Offset(bx - tp.width / 2, by - tp.height / 2));
  }

  // ── Icon helper ──────────────────────────────────────────────────────────

  void _drawIcon(Canvas canvas, IconData icon, Color color, Offset center, double size) {
    final tp = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          color: color, fontSize: size,
          fontFamily: icon.fontFamily, package: icon.fontPackage,
          shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
        ),
      )
      ..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }
}
