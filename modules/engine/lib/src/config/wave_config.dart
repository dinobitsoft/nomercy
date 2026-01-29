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
    this.spawnX = 0,
    this.spawnY = 600,
    required this.enemyCount,
    this.enemyTypes = const [],
    required this.difficulty,
    this.isBossWave = false,
  });

  @override
  String toString() => 'Wave#$waveNumber($enemyCount enemies, '
      'difficulty: ${difficulty.toStringAsFixed(1)}x)';
}