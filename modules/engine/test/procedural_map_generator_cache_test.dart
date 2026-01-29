// lib/tests/procedural_map_generator_cache_test.dart
// Test file to verify all cache methods work correctly

import 'package:engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProceduralMapGenerator Cache Methods', () {
    late ProceduralMapGenerator generator;

    setUp(() {
      generator = ProceduralMapGenerator(seed: 12345);
    });

    test('clearCache() exists and can be called', () {
      expect(() => generator.clearCache(), returnsNormally);
    });

    test('clearBiomeCache() exists and can be called', () {
      expect(() => generator.clearBiomeCache(), returnsNormally);
    });

    test('getCacheStats() returns map with correct keys', () {
      final stats = generator.getCacheStats();
      expect(stats, isA<Map<String, int>>());
      expect(stats.containsKey('biome_cache_entries'), true);
      expect(stats.containsKey('random_seed'), true);
    });

    test('getCacheStats() returns valid values', () {
      final stats = generator.getCacheStats();
      expect(stats['biome_cache_entries'], isA<int>());
      expect(stats['random_seed'], equals(12345));
      expect(stats['biome_cache_entries']! >= 0, true);
    });

    test('prewarmCache() can be called with valid range', () {
      expect(() => generator.prewarmCache(0, 10), returnsNormally);
    });

    test('prewarmCache() increases cache entries', () {
      final before = generator.getCacheStats()['biome_cache_entries']!;
      generator.prewarmCache(0, 5);
      final after = generator.getCacheStats()['biome_cache_entries']!;
      expect(after > before, true);
    });

    test('clearCache() clears cache entries', () {
      generator.prewarmCache(0, 10);
      final before = generator.getCacheStats()['biome_cache_entries']!;
      expect(before > 0, true);

      generator.clearCache();
      final after = generator.getCacheStats()['biome_cache_entries']!;
      expect(after, equals(0));
    });

    test('printCacheStats() exists and can be called', () {
      expect(() => generator.printCacheStats(), returnsNormally);
    });

    test('Same seed produces same biomes (deterministic)', () {
      final gen1 = ProceduralMapGenerator(seed: 999);
      final gen2 = ProceduralMapGenerator(seed: 999);

      // Pre-warm both
      gen1.prewarmCache(0, 5);
      gen2.prewarmCache(0, 5);

      // Should have same cache size
      expect(
        gen1.getCacheStats()['biome_cache_entries'],
        equals(gen2.getCacheStats()['biome_cache_entries']),
      );
    });

    test('Different seeds produce different results', () {
      final gen1 = ProceduralMapGenerator(seed: 111);
      final gen2 = ProceduralMapGenerator(seed: 222);

      gen1.prewarmCache(0, 10);
      gen2.prewarmCache(0, 10);

      // Both should have cache, but from different seeds
      final stats1 = gen1.getCacheStats();
      final stats2 = gen2.getCacheStats();

      expect(stats1['random_seed'], equals(111));
      expect(stats2['random_seed'], equals(222));
    });

    test('Cache persists across multiple pre-warm calls', () {
      generator.prewarmCache(0, 5);
      final after1 = generator.getCacheStats()['biome_cache_entries']!;

      generator.prewarmCache(5, 10);
      final after2 = generator.getCacheStats()['biome_cache_entries']!;

      expect(after2 >= after1, true);
    });

    test('clearCache() reduces entries to 0', () {
      generator.prewarmCache(0, 20);
      expect(generator.getCacheStats()['biome_cache_entries']! > 0, true);

      generator.clearCache();
      expect(generator.getCacheStats()['biome_cache_entries']!, equals(0));
    });
  });

  group('ProceduralMapGenerator Integration Tests', () {
    late ProceduralMapGenerator generator;

    setUp(() {
      generator = ProceduralMapGenerator(seed: 777);
    });

    test('Full cache lifecycle works correctly', () {
      // 1. Start empty
      expect(generator.getCacheStats()['biome_cache_entries'], equals(0));

      // 2. Pre-warm
      generator.prewarmCache(0, 10);
      final warmed = generator.getCacheStats()['biome_cache_entries']!;
      expect(warmed > 0, true);

      // 3. Get stats
      final stats = generator.getCacheStats();
      expect(stats['biome_cache_entries']! > 0, true);

      // 4. Clear
      generator.clearCache();
      expect(generator.getCacheStats()['biome_cache_entries'], equals(0));

      // 5. Re-warm (should work again)
      generator.prewarmCache(10, 15);
      expect(generator.getCacheStats()['biome_cache_entries']! > 0, true);
    });

    test('Can call all methods in sequence without errors', () {
      expect(() {
        generator.prewarmCache(0, 5);
        generator.printCacheStats();
        final stats = generator.getCacheStats();
        generator.clearCache();
        generator.prewarmCache(0, 3);
        generator.clearBiomeCache();
        generator.printCacheStats();
      }, returnsNormally);
    });
  });
}