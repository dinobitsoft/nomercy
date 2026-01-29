import 'dart:math' as math;
import 'dart:ui';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';

/// Procedural generation system with multiple generation strategies
class ProceduralMapGenerator {
  final math.Random random;
  final int seed;

  // Generation parameters
  static const int octaves = 3;
  static const double persistence = 0.5;
  static const double lacunarity = 2.0;
  static const double scale = 50.0;

  // Biome system
  final Map<int, BiomeType> _biomeCache = {};
  static const int biomeChangeInterval = 4; // Change biome every N chunks

  ProceduralMapGenerator({int? seed})
      : seed = seed ?? DateTime.now().millisecondsSinceEpoch,
        random = math.Random(seed ?? DateTime.now().millisecondsSinceEpoch);

  /// Generate platforms for a chunk using Perlin-like noise
  List<PlatformData> generateChunk(
      int chunkIndex,
      double chunkStartX,
      double chunkWidth,
      ) {
    final platforms = <PlatformData>[];

    // Determine biome for this chunk
    final biome = _getBiomeForChunk(chunkIndex);

    // Add ground platform
    final groundHeight = _calculateGroundHeight(chunkIndex, biome);
    platforms.add(PlatformData(
      x: chunkStartX + chunkWidth / 2,
      y: groundHeight,
      width: chunkWidth,
      height: 60,
      type: biome.groundType,
    ));

    // Generate floating platforms
    final platformCount = _getPlatformCountForBiome(biome);
    for (int i = 0; i < platformCount; i++) {
      final x = chunkStartX + 200 + random.nextDouble() * (chunkWidth - 400);
      final noiseValue = _perlinNoise(x / scale, chunkIndex.toDouble());
      final y = 300 + noiseValue * 400;

      // Check biome-specific constraints
      if (!_shouldSkipPlatform(platforms, x, y, biome)) {
        platforms.add(PlatformData(
          x: x,
          y: y,
          width: 150 + random.nextDouble() * 150,
          height: 30,
          type: biome.platformType,
        ));
      }
    }

    return platforms;
  }

  /// Get or calculate biome for chunk
  BiomeType _getBiomeForChunk(int chunkIndex) {
    if (_biomeCache.containsKey(chunkIndex)) {
      return _biomeCache[chunkIndex]!;
    }

    final biomeRegion = chunkIndex ~/ biomeChangeInterval;
    final biomeRoll = random.nextDouble();

    BiomeType biome;
    if (biomeRegion < 2) {
      // Early game: forest biome
      biome = BiomeType.forest;
    } else if (biomeRegion < 5) {
      // Mid game: variety
      biome = biomeRoll < 0.5 ? BiomeType.mountain : BiomeType.lava;
    } else {
      // Late game: challenge zones
      biome = biomeRoll < 0.4
          ? BiomeType.shadow
          : (biomeRoll < 0.7 ? BiomeType.ice : BiomeType.storm);
    }

    _biomeCache[chunkIndex] = biome;
    return biome;
  }

  /// Calculate ground height using noise
  double _calculateGroundHeight(int chunkIndex, BiomeType biome) {
    final noiseValue = _perlinNoise(chunkIndex / 4.0, 0);
    final baseHeight = 1000.0;
    final heightVariation = biome.heightVariation;

    return baseHeight + (noiseValue * heightVariation);
  }

  /// Simplified Perlin noise implementation
  double _perlinNoise(double x, double y) {
    double result = 0.0;
    double amplitude = 1.0;
    double frequency = 1.0;
    double maxValue = 0.0;

    for (int i = 0; i < octaves; i++) {
      result += _smoothNoise(x * frequency, y * frequency) * amplitude;
      maxValue += amplitude;

      amplitude *= persistence;
      frequency *= lacunarity;
    }

    return result / maxValue;
  }

  /// Smoothstep interpolation noise
  double _smoothNoise(double x, double y) {
    final xi = x.floor();
    final yi = y.floor();
    final xf = x - xi;
    final yf = y - yi;

    // Interpolation
    final u = xf * xf * (3.0 - 2.0 * xf);
    final v = yf * yf * (3.0 - 2.0 * yf);

    // Hash-based pseudorandom (using seed)
    final n00 = _hash(xi, yi);
    final n10 = _hash(xi + 1, yi);
    final n01 = _hash(xi, yi + 1);
    final n11 = _hash(xi + 1, yi + 1);

    final nx0 = _lerp(n00, n10, u);
    final nx1 = _lerp(n01, n11, u);
    return _lerp(nx0, nx1, v);
  }

  /// Hash function for noise generation
  double _hash(int x, int y) {
    var h = seed ^ (x.hashCode ^ y.hashCode);
    h = ((h >> 16) ^ h) * 0x45d9f3b;
    h = ((h >> 16) ^ h) * 0x45d9f3b;
    return (h & 0x3fffffff) / 0x3fffffff;
  }

  /// Linear interpolation
  double _lerp(double a, double b, double t) {
    return a + (b - a) * t;
  }

  /// Check if platform placement is valid
  bool _shouldSkipPlatform(
      List<PlatformData> existing,
      double x,
      double y,
      BiomeType biome,
      ) {
    // Cluster avoidance
    final tooClose = existing.any((p) =>
    (p.x - x).abs() < 120 && (p.y - y).abs() < 80);

    if (tooClose) return true;

    // Biome-specific density
    final densityThreshold = 0.2 * (1.0 - biome.platformDensity);
    if (random.nextDouble() < densityThreshold) return true;

    return false;
  }

  /// Get platform count for biome
  int _getPlatformCountForBiome(BiomeType biome) {
    final baseCount = (3 + random.nextInt(4) * biome.platformDensity).toInt();
    return baseCount.clamp(2, 8);
  }

  /// Clear all generation caches
  void clearCache() {
    final previousSize = _biomeCache.length;
    _biomeCache.clear();
    print('🧹 ProceduralMapGenerator: Cleared biome cache ($previousSize entries)');
  }

  /// Clear biome cache specifically
  void clearBiomeCache() {
    _biomeCache.clear();
    print('🧹 Biome cache cleared');
  }

  /// Get cache statistics
  Map<String, int> getCacheStats() {
    return {
      'biome_cache_entries': _biomeCache.length,
      'random_seed': seed,
    };
  }

  /// Pre-generate cache for range of chunks (performance optimization)
  void prewarmCache(int startChunk, int endChunk) {
    final count = endChunk - startChunk + 1;
    for (int i = startChunk; i <= endChunk; i++) {
      _getBiomeForChunk(i);
    }
    print('✅ ProceduralMapGenerator: Prewarmed cache for $count chunks '
        '($startChunk-$endChunk)');
  }

  /// Print cache statistics
  void printCacheStats() {
    final stats = getCacheStats();
    print('\n📊 ProceduralMapGenerator Cache Stats:');
    print('  Biome Cache Entries: ${stats['biome_cache_entries']}');
    print('  Random Seed: ${stats['random_seed']}');
  }
}

/// Chunk quadtree for spatial queries (optimization for large maps)
class ChunkQuadtree {
  final _root = QuadtreeNode(
    bounds: Rect.fromLTWH(0, 0, double.infinity, double.infinity),
  );

  void insert(WorldChunk chunk) {
    _root.insert(chunk);
  }

  void remove(WorldChunk chunk) {
    _root.remove(chunk);
  }

  List<WorldChunk> query(Vector2 position, double range) {
    return _root.query(
      Rect.fromCircle(center: Offset(position.x, position.y), radius: range),
    );
  }

  void clear() {
    _root.clear();
  }
}

/// Quadtree node for spatial partitioning
class QuadtreeNode {
  final Rect bounds;
  final List<WorldChunk> objects = [];
  List<QuadtreeNode>? children;

  static const int maxObjects = 4;
  static const int maxDepth = 8;
  int depth = 0;

  QuadtreeNode({required this.bounds, this.depth = 0});

  void insert(WorldChunk chunk) {
    if (!_boundsContain(chunk)) return;

    if (objects.length < maxObjects || depth >= maxDepth) {
      objects.add(chunk);
    } else {
      _subdivide();
      for (final child in children!) {
        child.insert(chunk);
      }
    }
  }

  void remove(WorldChunk chunk) {
    objects.remove(chunk);
    if (children != null) {
      for (final child in children!) {
        child.remove(chunk);
      }
    }
  }

  List<WorldChunk> query(Rect area) {
    final result = <WorldChunk>[];

    if (!bounds.overlaps(area)) {
      return result;
    }

    result.addAll(objects);

    if (children != null) {
      for (final child in children!) {
        result.addAll(child.query(area));
      }
    }

    return result;
  }

  void clear() {
    objects.clear();
    if (children != null) {
      for (final child in children!) {
        child.clear();
      }
      children = null;
    }
  }

  void _subdivide() {
    final halfWidth = bounds.width / 2;
    final halfHeight = bounds.height / 2;

    children = [
      // Top-left
      QuadtreeNode(
        bounds: Rect.fromLTWH(bounds.left, bounds.top, halfWidth, halfHeight),
        depth: depth + 1,
      ),
      // Top-right
      QuadtreeNode(
        bounds: Rect.fromLTWH(bounds.left + halfWidth, bounds.top, halfWidth, halfHeight),
        depth: depth + 1,
      ),
      // Bottom-left
      QuadtreeNode(
        bounds: Rect.fromLTWH(bounds.left, bounds.top + halfHeight, halfWidth, halfHeight),
        depth: depth + 1,
      ),
      // Bottom-right
      QuadtreeNode(
        bounds: Rect.fromLTWH(bounds.left + halfWidth, bounds.top + halfHeight, halfWidth, halfHeight),
        depth: depth + 1,
      ),
    ];
  }

  bool _boundsContain(WorldChunk chunk) {
    return bounds.overlaps(
      Rect.fromLTWH(chunk.startX, 0, chunk.width, double.infinity),
    );
  }
}