import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/services.dart';
import '../config/asset_paths.dart';

/// Centralized resource management with caching and preloading
/// Singleton pattern ensures only one instance exists
class ResourceManager {
  static final ResourceManager _instance = ResourceManager._internal();
  factory ResourceManager() => _instance;
  ResourceManager._internal();

  // Cache maps
  final Map<String, ui.Image> _imageCache = {};
  final Map<String, SpriteSheet> _spriteSheetCache = {};
  final Map<String, SpriteAnimation> _animationCache = {};
  final Map<String, ByteData> _audioCache = {};

  bool _isInitialized = false;
  int _totalAssets = 0;
  int _loadedAssets = 0;

  /// Loading progress (0.0 to 1.0)
  double get loadingProgress =>
      _totalAssets == 0 ? 0.0 : _loadedAssets / _totalAssets;

  /// Preload all essential game assets
  Future<void> preloadAssets() async {
    if (_isInitialized) return;

    print('🎮 Starting asset preload...');

    // Calculate total assets to load
    _totalAssets = AssetPaths.characterSprites.length +
        AssetPaths.effectSprites.length +
        AssetPaths.uiSprites.length;
    _loadedAssets = 0;

    // Preload character sprites
    await _preloadCharacterAssets();

    // Preload effects and particles
    await _preloadEffectAssets();

    // Preload UI elements
    await _preloadUIAssets();

    _isInitialized = true;
    print('✅ Asset preload complete! Loaded $_loadedAssets assets');
  }

  /// Preload character sprite sheets
  Future<void> _preloadCharacterAssets() async {
    for (final charName in AssetPaths.characterSprites.keys) {
      final paths = AssetPaths.characterSprites[charName]!;

      // Load idle sprite sheet
      if (paths['idle'] != null) {
        await _loadSpriteSheet(
          '${charName}_idle',
          paths['idle']!,
          frameWidth: 160,
          frameHeight: 160,
        );
      }

      // Load walk sprite sheet
      if (paths['walk'] != null) {
        await _loadSpriteSheet(
          '${charName}_walk',
          paths['walk']!,
          frameWidth: 160,
          frameHeight: 160,
        );
      }

      // Load attack sprite sheet
      if (paths['attack'] != null) {
        await _loadSpriteSheet(
          '${charName}_attack',
          paths['attack']!,
          frameWidth: 160,
          frameHeight: 160,
        );
      }

      // Load jump sprite sheet
      if (paths['jump'] != null) {
        await _loadSpriteSheet(
          '${charName}_jump',
          paths['jump']!,
          frameWidth: 160,
          frameHeight: 160,
        );
      }

      // Load landing sprite sheet
      if (paths['landing'] != null) {
        await _loadSpriteSheet(
          '${charName}_landing',
          paths['landing']!,
          frameWidth: 160,
          frameHeight: 160,
        );
      }

      _loadedAssets++;
      print('  📦 Loaded $charName sprites (${_loadedAssets}/$_totalAssets)');
    }
  }

  /// Preload effect sprites
  Future<void> _preloadEffectAssets() async {
    for (final effectPath in AssetPaths.effectSprites) {
      await _loadImage(effectPath);
      _loadedAssets++;
    }
  }

  /// Preload UI sprites
  Future<void> _preloadUIAssets() async {
    for (final uiPath in AssetPaths.uiSprites) {
      await _loadImage(uiPath);
      _loadedAssets++;
    }
  }

  /// Load sprite sheet and cache it
  Future<SpriteSheet> _loadSpriteSheet(
      String key,
      String path, {
        required int frameWidth,
        required int frameHeight,
      }) async {
    if (_spriteSheetCache.containsKey(key)) {
      return _spriteSheetCache[key]!;
    }

    final image = await _loadImage(path);
    final spriteSheet = SpriteSheet(
      image: image,
      srcSize: Vector2(frameWidth.toDouble(), frameHeight.toDouble()),
    );

    _spriteSheetCache[key] = spriteSheet;
    return spriteSheet;
  }

  /// Load image and cache it
  Future<ui.Image> _loadImage(String path) async {
    if (_imageCache.containsKey(path)) {
      return _imageCache[path]!;
    }

    final image = await Flame.images.load(path);
    _imageCache[path] = image;
    return image;
  }

  /// Get cached animation (creates if not exists)
  SpriteAnimation getAnimation(
      String characterName,
      String animationType, {
        required double stepTime,
        bool loop = true,
      }) {
    final key = '${characterName}_${animationType}';

    if (_animationCache.containsKey(key)) {
      return _animationCache[key]!;
    }

    final spriteSheet = _spriteSheetCache[key];
    if (spriteSheet == null) {
      throw Exception('Sprite sheet not found: $key');
    }

    // Determine frame count from sprite sheet
    final frameCount = (spriteSheet.image.width / spriteSheet.srcSize.x).floor();

    final animation = spriteSheet.createAnimation(
      row: 0,
      stepTime: stepTime,
      to: frameCount,
      loop: loop,
    );

    _animationCache[key] = animation;
    return animation;
  }

  /// Get single sprite from cache
  Sprite? getSprite(String path) {
    final image = _imageCache[path];
    return image != null ? Sprite(image) : null;
  }

  /// Get image from cache
  ui.Image? getImage(String path) {
    return _imageCache[path];
  }

  /// Clear all caches (for memory management)
  void clearCache() {
    _imageCache.clear();
    _spriteSheetCache.clear();
    _animationCache.clear();
    _audioCache.clear();
    _isInitialized = false;
    print('🧹 Resource cache cleared');
  }

  /// Dispose of specific character assets
  void disposeCharacterAssets(String characterName) {
    _animationCache.removeWhere((key, _) => key.startsWith(characterName));
    _spriteSheetCache.removeWhere((key, _) => key.startsWith(characterName));
    print('🗑️ Disposed $characterName assets');
  }
}

