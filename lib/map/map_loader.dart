import 'dart:convert';

import 'package:flutter/services.dart';

import 'game_map.dart';

class MapLoader {
  static Future<GameMap> loadMap(String mapName) async {
    try {
      // Load JSON from assets
      final jsonString = await rootBundle.loadString('assets/maps/$mapName.json');
      final jsonData = json.decode(jsonString);
      return GameMap.fromJson(jsonData);
    } catch (e) {
      print('Error loading map: $e');
      // Return default map if loading fails
      return _getDefaultMap();
    }
  }

  static GameMap _getDefaultMap() {
    return GameMap(
      name: 'default',
      width: 1200,
      height: 800,
      platforms: [
        PlatformData(
          id: 1,
          type: 'ground',
          x: 0,
          y: 750,
          width: 1200,
          height: 50,
        ),
      ],
      playerSpawn: SpawnPoint(x: 100, y: 600), chests: [],
    );
  }
}

// 3. Update Platform component to support different types:



// 4. Update GameScreen to accept map name:

// 5. Update pubspec.yaml to include maps folder:
/*
flutter:
  assets:
    - assets/images/knight.png
    - assets/images/thief.png
    - assets/images/wizard.png
    - assets/images/trader.png
    - assets/images/knight_attack.png
    - assets/images/thief_attack.png
    - assets/images/wizard_attack.png
    - assets/images/trader_attack.png
    - assets/maps/           # Add this line
    - assets/maps/level_1.json
    - assets/maps/level_2.json
*/

// 6. Optional: Create a level selection screen
