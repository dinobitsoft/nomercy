class WaveData {
  final int waveNumber;
  final int enemyCount;
  final double difficulty;
  final List<String>? enemyTypes;

  WaveData({
    required this.waveNumber,
    required this.enemyCount,
    required this.difficulty,
    this.enemyTypes,
  });
}