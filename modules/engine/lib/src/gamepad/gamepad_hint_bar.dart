import 'package:flutter/material.dart';

// ─── Gamepad hint bar widget ──────────────────────────────────────────────────
class GamepadHintBar extends StatelessWidget {
  final bool showBack;
  final bool showConfirm;
  final String confirmLabel;
  final String backLabel;

  const GamepadHintBar({
    super.key,
    this.showBack = true,
    this.showConfirm = true,
    this.confirmLabel = 'Select',
    this.backLabel = 'Back',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (showConfirm) ...[
            _hint('A', confirmLabel, Colors.green),
            const SizedBox(width: 16),
          ],
          if (showBack) ...[_hint('B', backLabel, Colors.red)],
          const SizedBox(width: 16),
          _hint('↕', 'Navigate', Colors.white54),
        ],
      ),
    );
  }

  Widget _hint(String button, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          child: Text(
            button,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}
