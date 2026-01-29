enum MapStyle {
  arena,
  platformer,
  dungeon,
  towers,
  chaos,
  balanced,
}

enum MapDifficulty {
  easy,
  medium,
  hard,
  expert,
}

class MapGeneratorConfig {
  final MapStyle style;
  final MapDifficulty difficulty;
  final double width;
  final double height;
  final int minPlatforms;
  final int maxPlatforms;
  final int chestCount;
  final bool ensureConnectivity;
  final int seed;
  final double startX;

  MapGeneratorConfig({
    this.style = MapStyle.balanced,
    this.difficulty = MapDifficulty.medium,
    this.width = 2400,
    this.height = 1200,
    this.minPlatforms = 8,
    this.maxPlatforms = 15,
    this.chestCount = 3,
    this.ensureConnectivity = true,
    int? seed,
    required this.startX,
  }) : seed = seed ?? DateTime.now().millisecondsSinceEpoch;
}

