import 'package:flutter/material.dart';

// ─── Highlight wrapper widget ─────────────────────────────────────────────────
class GamepadMenuItem extends StatelessWidget {
  final bool focused;
  final VoidCallback? onTap;
  final Widget child;
  final Color focusColor;
  final double borderWidth;
  final BorderRadius? borderRadius;

  const GamepadMenuItem({
    super.key,
    required this.focused,
    required this.child,
    this.onTap,
    this.focusColor = const Color(0xFFFFD700),
    this.borderWidth = 2.5,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(12);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: focused
            ? BoxDecoration(
          borderRadius: br,
          border: Border.all(color: focusColor, width: borderWidth),
          boxShadow: [
            BoxShadow(
              color: focusColor.withOpacity(0.35),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        )
            : BoxDecoration(
          borderRadius: br,
          border: Border.all(color: Colors.transparent, width: borderWidth),
        ),
        child: Stack(
          children: [
            child,
            if (focused)
              Positioned(
                top: 6,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: focusColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '▶',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}