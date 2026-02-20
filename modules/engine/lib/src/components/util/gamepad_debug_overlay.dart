import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Add to camera.viewport in ActionGame.onLoad() to diagnose PS controller:
///   camera.viewport.add(GamepadDebugOverlay());
///
/// Shows:
///   • Last 20 raw gamepads events (type / key / value)
///   • Current joystickDelta, button states
///   • Learned axis X/Y keys
///
/// Remove once mapping is confirmed.
class GamepadDebugOverlay extends PositionComponent with HasGameRef<ActionGame> {
  GamepadDebugOverlay() {
    priority = 999;
  }

  @override
  void render(Canvas canvas) {
    final gp = gameRef.gamepadManager;

    final lines = <String>[
      '─── GAMEPAD DEBUG ───',
      'connected: ${gp.isGamepadConnected}',
      'joystick: (${gp.joystickDelta.x.toStringAsFixed(2)}, ${gp.joystickDelta.y.toStringAsFixed(2)})',
      'jump:${gp.isJumpPressed}  attack:${gp.isAttackPressed}',
      'block:${gp.isBlockPressed}  dodge:${gp.isDodgePressed}',
      '─── RAW EVENTS ───',
      ...gp.rawLog.reversed.take(14),
    ];

    double y = 10;
    for (final line in lines) {
      final tp = TextPainter(
        text: TextSpan(
          text: line,
          style: const TextStyle(
            color: Colors.lime,
            fontSize: 11,
            fontFamily: 'monospace',
            shadows: [Shadow(color: Colors.black, blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(8, y));
      y += 14;
    }
  }
}