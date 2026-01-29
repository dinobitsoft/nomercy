import 'package:engine/engine.dart';
import 'package:flame/components.dart';

class WorldChunk {
  final int index;
  final double startX;
  final double width;

  // Runtime data
  final List<TiledPlatform> platformRefs = [];
  late List<Vector2> platformData;
  late List<WaveConfig> waveConfigs;

  // Wave configuration
  bool shouldSpawnWave = false;
  bool waveSpawned = false;
  double waveSpawnX = 0;
  int waveNumber = 0;
  double waveDifficulty = 1.0;

  WorldChunk({
    required this.index,
    required this.startX,
    required this.width,
  }) {
    platformData = [];
    waveConfigs = [];
  }

  /// Factory for empty chunks (pool reuse)
  factory WorldChunk.empty() => WorldChunk(
    index: -1,
    startX: 0,
    width: 0,
  );

  /// Reset chunk state for reuse
  void reset({
    required int index,
    required double startX,
    required double width,
  }) {
    // Note: Don't reset index, startX, width - they're immutable
    // Instead, create proper constructor for reuse
    clearResources();
    shouldSpawnWave = false;
    waveSpawned = false;
    waveNumber = 0;
    waveDifficulty = 1.0;
  }

  /// Clear resources
  void clearResources() {
    platformRefs.clear();
    platformData.clear();
    waveConfigs.clear();
  }

  double get endX => startX + width;
  double get centerX => startX + width / 2;

  @override
  String toString() => 'Chunk#$index(${startX.toInt()}-${endX.toInt()})';
}