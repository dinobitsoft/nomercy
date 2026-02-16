// modules/engine/lib/src/map/platform_factory.dart

import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';

/// Centralized platform creation with quality presets
class PlatformFactory {
  static PlatformFactory? _instance;
  factory PlatformFactory() => _instance ??= PlatformFactory._internal();
  PlatformFactory._internal();

  // ==========================================
  // CONFIGURATION
  // ==========================================

  PlatformQuality quality = PlatformQuality.high;
  bool useEnhancedPlatforms = true;
  bool enableLOD = true; // Level of Detail optimization

  // Performance tracking
  int _platformsCreated = 0;
  int _enhancedCreated = 0;
  int _tiledCreated = 0;

  // ==========================================
  // FACTORY METHOD
  // ==========================================

  /// Create platform based on current quality settings
  PositionComponent createPlatform({
    required Vector2 position,
    required Vector2 size,
    required String platformType,
    int priority = 10,
    PlatformQuality? overrideQuality,
  }) {
    _platformsCreated++;

    final effectiveQuality = overrideQuality ?? quality;

    final platform = _createPlatformByQuality(
      position: position,
      size: size,
      platformType: platformType,
      quality: effectiveQuality,
    );

    platform.priority = priority;

    return platform;
  }

  PositionComponent _createPlatformByQuality({
    required Vector2 position,
    required Vector2 size,
    required String platformType,
    required PlatformQuality quality,
  }) {
    switch (quality) {
      case PlatformQuality.ultra:
        _enhancedCreated++;
        return EnhancedPlatform(
          position: position,
          size: size,
          platformType: platformType,
          useOverlay: true,
          useShadow: true,
          useEdgeHighlight: true,
          weatheringIntensity: 0.8,
        );

      case PlatformQuality.high:
        _enhancedCreated++;
        return EnhancedPlatform(
          position: position,
          size: size,
          platformType: platformType,
          useOverlay: true,
          useShadow: true,
          useEdgeHighlight: false,
          weatheringIntensity: 0.7,
        );

      case PlatformQuality.medium:
        _enhancedCreated++;
        return EnhancedPlatform(
          position: position,
          size: size,
          platformType: platformType,
          useOverlay: true,
          useShadow: false,
          useEdgeHighlight: false,
          weatheringIntensity: 0.5,
        );

      case PlatformQuality.low:
        _enhancedCreated++;
        return EnhancedPlatform(
          position: position,
          size: size,
          platformType: platformType,
          useOverlay: false, // No overlay = faster
          useShadow: false,
          useEdgeHighlight: false,
          weatheringIntensity: 0.0,
        );

      case PlatformQuality.performance:
        _tiledCreated++;
        return TiledPlatform(
          position: position,
          size: size,
          platformType: platformType,
        );
    }
  }

  // ==========================================
  // BATCH CREATION (Optimized)
  // ==========================================

  /// Create multiple platforms efficiently
  List<PositionComponent> createBatch({
    required List<PlatformData> platformDataList,
    PlatformQuality? batchQuality,
  }) {
    final platforms = <PositionComponent>[];

    for (final data in platformDataList) {
      platforms.add(createPlatform(
        position: Vector2(data.x, data.y),
        size: Vector2(data.width, data.height),
        platformType: data.type,
        overrideQuality: batchQuality,
      ));
    }

    return platforms;
  }

  // ==========================================
  // DYNAMIC QUALITY ADJUSTMENT
  // ==========================================

  /// Adjust quality based on performance metrics
  void adjustQualityBasedOnFPS(double currentFPS) {
    if (currentFPS < 30 && quality != PlatformQuality.performance) {
      print('⚠️ Low FPS detected - reducing platform quality');
      quality = quality.downgrade();
    } else if (currentFPS > 55 && quality != PlatformQuality.ultra) {
      print('✅ High FPS - upgrading platform quality');
      quality = quality.upgrade();
    }
  }

  // ==========================================
  // STATISTICS
  // ==========================================

  Map<String, dynamic> getStats() {
    return {
      'total': _platformsCreated,
      'enhanced': _enhancedCreated,
      'tiled': _tiledCreated,
      'currentQuality': quality.toString(),
      'enhancedPercentage': _platformsCreated > 0
          ? (_enhancedCreated / _platformsCreated * 100).toStringAsFixed(1)
          : '0.0',
    };
  }

  void printStats() {
    final stats = getStats();
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🏗️  PLATFORM FACTORY STATISTICS');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('Total Platforms: ${stats['total']}');
    print('Enhanced: ${stats['enhanced']} (${stats['enhancedPercentage']}%)');
    print('Tiled: ${stats['tiled']}');
    print('Quality Level: ${stats['currentQuality']}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  }

  void reset() {
    _platformsCreated = 0;
    _enhancedCreated = 0;
    _tiledCreated = 0;
  }
}

// ==========================================
// QUALITY PRESETS
// ==========================================

enum PlatformQuality {
  ultra,        // All effects enabled
  high,         // Overlay + shadow
  medium,       // Overlay only
  low,          // Base texture only (EnhancedPlatform with no extras)
  performance;  // TiledPlatform fallback

  PlatformQuality upgrade() {
    switch (this) {
      case PlatformQuality.performance: return PlatformQuality.low;
      case PlatformQuality.low: return PlatformQuality.medium;
      case PlatformQuality.medium: return PlatformQuality.high;
      case PlatformQuality.high: return PlatformQuality.ultra;
      case PlatformQuality.ultra: return PlatformQuality.ultra;
    }
  }

  PlatformQuality downgrade() {
    switch (this) {
      case PlatformQuality.ultra: return PlatformQuality.high;
      case PlatformQuality.high: return PlatformQuality.medium;
      case PlatformQuality.medium: return PlatformQuality.low;
      case PlatformQuality.low: return PlatformQuality.performance;
      case PlatformQuality.performance: return PlatformQuality.performance;
    }
  }
}