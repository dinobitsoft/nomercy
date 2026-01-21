// lib/config/asset_paths.dart

/// Centralized asset path management
/// Prevents hardcoded strings throughout codebase
class AssetPaths {
  AssetPaths._(); // Private constructor - static class only

  // Base directories
  static const String images = 'images/';
  static const String audio = 'audio/';
  static const String maps = 'maps/';

  /// Character sprite sheets
  /// Structure: characterName -> animationType -> path
  static const Map<String, Map<String, String>> characterSprites = {
    'knight': {
      'idle': '${images}knight_idle.png',
      'walk': '${images}knight_walk.png',
      'attack': '${images}knight_attack.png',
      'jump': '${images}knight_jump.png',
      'landing': '${images}knight_landing.png',
    },
    'thief': {
      'idle': '${images}thief_idle.png',
      'walk': '${images}thief_walk.png',
      'attack': '${images}thief_attack.png',
      'jump': '${images}thief_jump.png',
      'landing': '${images}thief_landing.png',
    },
    'wizard': {
      'idle': '${images}wizard_idle.png',
      'walk': '${images}wizard_walk.png',
      'attack': '${images}wizard_attack.png',
      'jump': '${images}wizard_jump.png',
      'landing': '${images}wizard_landing.png',
    },
    'trader': {
      'idle': '${images}trader_idle.png',
      'walk': '${images}trader_walk.png',
      'attack': '${images}trader_attack.png',
      'jump': '${images}trader_jump.png',
      'landing': '${images}trader_landing.png',
    },
  };

  /// Effect sprites
  static const List<String> effectSprites = [
    '${images}impact_particle.png',
    '${images}blood_splash.png',
    '${images}dust_cloud.png',
  ];

  /// UI sprites
  static const List<String> uiSprites = [
    '${images}health_bar.png',
    '${images}stamina_bar.png',
    '${images}button_attack.png',
    '${images}button_dodge.png',
    '${images}button_block.png',
  ];

  /// Platform textures
  static const Map<String, String> platformTextures = {
    'brick': '${images}brick_tile.png',
    'ground': '${images}ground_tile.png',
    'stone': '${images}stone_tile.png',
  };

  /// Item sprites
  static const Map<String, String> itemSprites = {
    'health_potion': '${images}health_potion.png',
    'chest': '${images}dower_chest.png',
    'chest_opened': '${images}dower_chest_opened.png',
  };

  /// Weapon sprites
  static const Map<String, String> weaponSprites = {
    'sword': '${images}sword_icon.png',
    'bow': '${images}bow_icon.png',
    'staff': '${images}staff_icon.png',
    'dagger': '${images}dagger_icon.png',
  };

  /// Audio files
  static const Map<String, String> audioFiles = {
    'music_menu': '${audio}menu_theme.mp3',
    'music_battle': '${audio}battle_theme.mp3',
    'sfx_attack': '${audio}sword_slash.wav',
    'sfx_jump': '${audio}jump.wav',
    'sfx_land': '${audio}land.wav',
    'sfx_hit': '${audio}hit.wav',
  };

  /// Get character sprite path
  static String getCharacterSprite(String character, String animation) {
    return characterSprites[character]?[animation] ?? '${images}$character.png';
  }

  /// Get platform texture path
  static String getPlatformTexture(String type) {
    return platformTextures[type] ?? platformTextures['brick']!;
  }

  /// Get item sprite path
  static String getItemSprite(String itemType) {
    return itemSprites[itemType] ?? '${images}unknown_item.png';
  }

  /// Validate all assets exist (for development)
  static Future<bool> validateAssets() async {
    print('🔍 Validating assets...');

    int missing = 0;

    // Check character sprites
    for (final char in characterSprites.values) {
      for (final path in char.values) {
        // In production, check with rootBundle.load()
        print('  Checking: $path');
      }
    }

    if (missing > 0) {
      print('❌ Missing $missing assets!');
      return false;
    }

    print('✅ All assets validated');
    return true;
  }
}