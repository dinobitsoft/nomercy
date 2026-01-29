import 'dart:math' as math;
import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Utility extensions for infinite map system
extension InfiniteMapDebugExtensions on InfiniteMapManager {
  /// Get human-readable map info
  String getMapInfo() {
    final stats = getStats();
    return '''
┌─────────────────────────────────────┐
│ 🗺️  INFINITE MAP INFO               │
├─────────────────────────────────────┤
│ Seed: ${stats['currentChunk']}
│ Distance: ${stats['distanceTraveled']}px
│ Chunks: ${stats['activeChunks']} active
│ Platforms: ${stats['totalPlatforms']} visible
│ Waves: ${stats['totalWavesSpawned']} spawned
└─────────────────────────────────────┘
''';
  }

  /// Check if position is at chunk boundary
  bool isAtChunkBoundary(Vector2 position, {double threshold = 400}) {
    const chunkWidth = 2400.0;
    final localX = position.x % chunkWidth;
    return localX < threshold || localX > chunkWidth - threshold;
  }

  /// Get current chunk index
  int getCurrentChunkIndex(Vector2 position) {
    const chunkWidth = 2400.0;
    return (position.x / chunkWidth).floor();
  }

  /// Estimate difficulty at position
  double getEstimatedDifficulty(Vector2 position) {
    const chunkWidth = 2400.0;
    final chunkIndex = (position.x / chunkWidth).floor();
    return 1.0 + (chunkIndex.abs() * 0.15);
  }
}

/// Debug visualization component
class InfiniteMapDebugHUD extends PositionComponent with HasGameReference<ActionGame> {
  late TextComponent chunkText;
  late TextComponent positionText;
  late TextComponent statsText;

  @override
  void onMount() {
    super.onMount();

    chunkText = TextComponent(
      text: '',
      position: Vector2(10, 10),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.cyan,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(chunkText);

    positionText = TextComponent(
      text: '',
      position: Vector2(10, 40),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.lime,
          fontSize: 14,
        ),
      ),
    );
    add(positionText);

    statsText = TextComponent(
      text: '',
      position: Vector2(10, 70),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.yellow,
          fontSize: 12,
        ),
      ),
    );
    add(statsText);
  }

  @override
  void update(double dt) {
    super.update(dt);

    final charPos = game.character.position;
    final chunkIndex = game.infiniteMapManager.getCurrentChunkIndex(charPos);
    final difficulty = game.infiniteMapManager.getEstimatedDifficulty(charPos);

    chunkText.text = '📍 Chunk: $chunkIndex';
    positionText.text = '🎯 Pos: (${charPos.x.toInt()}, ${charPos.y.toInt()})';
    statsText.text = '⚔️ Difficulty: ${difficulty.toStringAsFixed(2)}x';
  }
}

/// Chunk boundary visualizer (debug only)
class ChunkBoundaryVisualizer extends PositionComponent with HasGameReference<ActionGame> {
  @override
  void render(Canvas canvas) {
    const chunkWidth = 2400.0;
    const cullingMargin = 1500.0;

    final playerPos = game.character.position;
    final visibleMinX = playerPos.x - cullingMargin;
    final visibleMaxX = playerPos.x + game.size.x + cullingMargin;

    // Calculate chunk boundaries
    final startChunk = (visibleMinX / chunkWidth).floor();
    final endChunk = (visibleMaxX / chunkWidth).floor();

    for (int i = startChunk; i <= endChunk; i++) {
      final x = i * chunkWidth;
      final isCurrentChunk =
          i == (playerPos.x / chunkWidth).floor();

      final paint = Paint()
        ..color = isCurrentChunk ? Colors.green : Colors.red
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      // Draw vertical line at chunk boundary
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, 2000),
        paint,
      );

      // Label chunk
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'C$i',
          style: TextStyle(
            color: isCurrentChunk ? Colors.green : Colors.red,
            fontSize: 12,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x + 10, 20),
      );
    }
  }
}

/// Wave spawn zone visualizer
class WaveZoneVisualizer extends PositionComponent with HasGameReference<ActionGame> {
  @override
  void render(Canvas canvas) {
    const chunkWidth = 2400.0;
    final manager = game.infiniteMapManager;

    // Show all active wave zones
    for (final chunk in manager.loadedChunks.values) {
      if (chunk.shouldSpawnWave && !chunk.waveSpawned) {
        final rect = Rect.fromLTWH(
          chunk.startX,
          500,
          chunk.width,
          100,
        );

        canvas.drawRect(
          rect,
          Paint()
            ..color = Colors.orange.withOpacity(0.3)
            ..style = PaintingStyle.fill,
        );

        canvas.drawRect(
          rect,
          Paint()
            ..color = Colors.orange
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke,
        );

        // Label
        final textPainter = TextPainter(
          text: TextSpan(
            text: 'Wave ${chunk.waveNumber}',
            style: const TextStyle(
              color: Colors.orange,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(chunk.startX + 20, 530),
        );
      }
    }
  }
}

/// Platform grid overlay (for level design)
class PlatformGridOverlay extends PositionComponent with HasGameReference<ActionGame> {
  static const double gridSize = 100.0;

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1;

    final camera = game.camera;
    final viewBounds = camera.visibleWorldRect;

    // Draw vertical grid lines
    var x = (viewBounds.left / gridSize).floor() * gridSize;
    while (x < viewBounds.right) {
      canvas.drawLine(
        Offset(x, viewBounds.top),
        Offset(x, viewBounds.bottom),
        paint,
      );
      x += gridSize;
    }

    // Draw horizontal grid lines
    var y = (viewBounds.top / gridSize).floor() * gridSize;
    while (y < viewBounds.bottom) {
      canvas.drawLine(
        Offset(viewBounds.left, y),
        Offset(viewBounds.right, y),
        paint,
      );
      y += gridSize;
    }
  }
}

/// Performance monitor for infinite map
class InfiniteMapPerformanceMonitor extends PositionComponent {
  final List<double> _frameTimings = [];
  final List<int> _platformCounts = [];
  static const int bufferSize = 60; // 1 second at 60fps

  double _lastChunkLoadTime = 0;
  int _chunksLoadedLastFrame = 0;

  @override
  void update(double dt) {
    super.update(dt);

    _frameTimings.add(dt * 1000); // Convert to ms
    if (_frameTimings.length > bufferSize) {
      _frameTimings.removeAt(0);
    }
  }

  double getAverageFrameTime() {
    if (_frameTimings.isEmpty) return 0;
    return _frameTimings.reduce((a, b) => a + b) / _frameTimings.length;
  }

  double getMaxFrameTime() {
    return _frameTimings.isEmpty ? 0 : _frameTimings.reduce((a, b) => a > b ? a : b);
  }

  @override
  void render(Canvas canvas) {
    if (_frameTimings.isEmpty) return;

    final avg = getAverageFrameTime();
    final max = getMaxFrameTime();

    final text = TextPainter(
      text: TextSpan(
        text: 'Frame: ${avg.toStringAsFixed(2)}ms (max: ${max.toStringAsFixed(2)}ms)',
        style: const TextStyle(
          color: Colors.cyan,
          fontSize: 12,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    text.layout();
    text.paint(canvas, const Offset(10, 100));

    // Draw frame time graph
    _drawFrameTimeGraph(canvas);
  }

  void _drawFrameTimeGraph(Canvas canvas) {
    const graphWidth = 200.0;
    const graphHeight = 50.0;
    const x = 10.0;
    const y = 130.0;

    // Background
    canvas.drawRect(
      Rect.fromLTWH(x, y, graphWidth, graphHeight),
      Paint()..color = Colors.black.withOpacity(0.5),
    );

    // Plot frame times
    if (_frameTimings.isNotEmpty) {
      final maxTime = math.max(20, getMaxFrameTime() * 1.2); // At least 20ms scale
      final step = graphWidth / _frameTimings.length;

      for (int i = 0; i < _frameTimings.length - 1; i++) {
        final x1 = x + (i * step);
        final y1 = y + graphHeight - ((_frameTimings[i] / maxTime) * graphHeight);

        final x2 = x + ((i + 1) * step);
        final y2 = y + graphHeight - ((_frameTimings[i + 1] / maxTime) * graphHeight);

        canvas.drawLine(
          Offset(x1, y1),
          Offset(x2, y2),
          Paint()
            ..color = _getFrameTimeColor(_frameTimings[i])
            ..strokeWidth = 2,
        );
      }
    }

    // Border
    canvas.drawRect(
      Rect.fromLTWH(x, y, graphWidth, graphHeight),
      Paint()
        ..color = Colors.cyan
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
  }

  Color _getFrameTimeColor(double frameTime) {
    if (frameTime < 16.67) return Colors.green; // 60fps
    if (frameTime < 33.33) return Colors.yellow; // 30fps
    return Colors.red; // <30fps
  }
}

/// Biome information display
class BiomeInfoDisplay extends PositionComponent with HasGameReference<ActionGame> {
  @override
  void render(Canvas canvas) {
    final charPos = game.character.position;
    const chunkWidth = 2400.0;
    final chunkIndex = (charPos.x / chunkWidth).floor();

    // Estimate biome (simplified)
    BiomeType biome;
    final biomeRegion = chunkIndex ~/ 4;

    if (biomeRegion < 2) {
      biome = BiomeType.forest;
    } else if (biomeRegion < 5) {
      biome = chunkIndex % 2 == 0 ? BiomeType.mountain : BiomeType.lava;
    } else {
      final roll = chunkIndex % 3;
      if (roll == 0) {
        biome = BiomeType.shadow;
      } else if (roll == 1) {
        biome = BiomeType.ice;
      } else {
        biome = BiomeType.storm;
      }
    }

    final text = TextPainter(
      text: TextSpan(
        text: '🏔️ ${biome.name.toUpperCase()}',
        style: TextStyle(
          color: _getBiomeColor(biome),
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    text.layout();
    text.paint(canvas, const Offset(10, 200));
  }

  Color _getBiomeColor(BiomeType biome) {
    switch (biome) {
      case BiomeType.forest:
        return Colors.green;
      case BiomeType.mountain:
        return Colors.grey;
      case BiomeType.lava:
        return Colors.red;
      case BiomeType.shadow:
        return Colors.purple;
      case BiomeType.ice:
        return Colors.blue;
      case BiomeType.storm:
        return Colors.indigo;
    }
  }
}

/// Quick-start debug setup
extension DebugSetup on ActionGame {
  /// Add all debug visualizations
  void addInfiniteMapDebugVisualizations() {
    camera.viewport.add(InfiniteMapDebugHUD());
    camera.viewport.add(ChunkBoundaryVisualizer());
    camera.viewport.add(WaveZoneVisualizer());
    camera.viewport.add(PlatformGridOverlay());
    camera.viewport.add(InfiniteMapPerformanceMonitor());
    camera.viewport.add(BiomeInfoDisplay());

    print('✅ Debug visualizations added. Remove in production!');
  }

  /// Print detailed infinite map report
  void printInfiniteMapReport() {
    print(infiniteMapManager.getMapInfo());
    infiniteMapManager.printStats();
  }
}