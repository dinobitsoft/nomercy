enum BiomeType {
  forest(
    groundType: 'ground',
    platformType: 'brick',
    platformDensity: 0.8,
    heightVariation: 100,
    enemyDifficulty: 1.0,
  ),
  mountain(
    groundType: 'ground',
    platformType: 'brick',
    platformDensity: 0.6,
    heightVariation: 300,
    enemyDifficulty: 1.2,
  ),
  lava(
    groundType: 'brick',
    platformType: 'brick',
    platformDensity: 0.5,
    heightVariation: 200,
    enemyDifficulty: 1.5,
  ),
  shadow(
    groundType: 'brick',
    platformType: 'ground',
    platformDensity: 0.7,
    heightVariation: 150,
    enemyDifficulty: 1.8,
  ),
  ice(
    groundType: 'brick',
    platformType: 'brick',
    platformDensity: 0.4,
    heightVariation: 250,
    enemyDifficulty: 2.0,
  ),
  storm(
    groundType: 'brick',
    platformType: 'brick',
    platformDensity: 0.6,
    heightVariation: 180,
    enemyDifficulty: 2.2,
  );

  final String groundType;
  final String platformType;
  final double platformDensity;
  final double heightVariation;
  final double enemyDifficulty;

  const BiomeType({
    required this.groundType,
    required this.platformType,
    required this.platformDensity,
    required this.heightVariation,
    required this.enemyDifficulty,
  });
}