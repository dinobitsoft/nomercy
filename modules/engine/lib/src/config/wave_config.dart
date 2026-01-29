class WaveConfig {
  final int waveNumber;
  final double spawnX;
  final double spawnY;
  final int enemyCount;
  final List<String> enemyTypes;
  final double difficulty;
  final bool isBossWave;

  WaveConfig({
    required this.waveNumber,
    required this.spawnX,
    required this.spawnY,
    required this.enemyCount,
    required this.enemyTypes,
    required this.difficulty,
    this.isBossWave = false,
  });

  @override
  String toString() => 'Wave#$waveNumber($enemyCount enemies, '
      'difficulty: ${difficulty.toStringAsFixed(1)}x)';
}