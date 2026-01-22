import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:nomercy/managers/performance_monitor.dart';

/// FPS Counter overlay component
class FPSCounter extends PositionComponent {
  final PerformanceMonitor _monitor = PerformanceMonitor();
  
  final Map<Color, TextPaint> _paints = {
    Colors.green: TextPaint(
      style: const TextStyle(
        color: Colors.green,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace',
      ),
    ),
    Colors.orange: TextPaint(
      style: const TextStyle(
        color: Colors.orange,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace',
      ),
    ),
    Colors.red: TextPaint(
      style: const TextStyle(
        color: Colors.red,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace',
      ),
    ),
  };

  FPSCounter() {
    position = Vector2(10, 10);
    priority = 1000; // Always on top
  }

  @override
  void render(Canvas canvas) {
    final fps = _monitor.fps;
    final frameTime = _monitor.frameTimeMs;

    // Color based on performance
    Color color = Colors.green;
    if (fps < 30) {
      color = Colors.red;
    } else if (fps < 50) {
      color = Colors.orange;
    }

    final paint = _paints[color] ?? _paints[Colors.green]!;

    final text = 'FPS: ${fps.toStringAsFixed(1)}\n'
        'Frame: ${frameTime.toStringAsFixed(1)}ms';

    paint.render(canvas, text, Vector2.zero());
  }
}
