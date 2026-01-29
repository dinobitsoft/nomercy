import 'package:engine/engine.dart';

/// Represents a chunk of the infinite world
class WorldChunk {
  final int id;
  int index;
  double startX;
  final double width;

  final List<TiledPlatform> platforms = [];
  bool waveSpawned = false;

  WorldChunk({
    required this.id,
    required this.index,
    required this.startX,
    required this.width,
  });

  double get endX => startX + width;
  double get centerX => startX + width / 2;

  void reset({required int index, required double startX}) {
    this.index = index;
    this.startX = startX;
    platforms.clear();
    waveSpawned = false;
  }
}