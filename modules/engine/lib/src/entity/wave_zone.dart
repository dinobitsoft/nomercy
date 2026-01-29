/// Represents a wave spawning zone
class WaveZone {
  final int chunkIndex;
  final double spawnX;
  final int waveNumber;
  final double difficulty;
  final int enemyCount;
  bool triggered = false;

  WaveZone({
    required this.chunkIndex,
    required this.spawnX,
    required this.waveNumber,
    required this.difficulty,
    required this.enemyCount,
  });
}