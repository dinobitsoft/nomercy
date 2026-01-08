// Add this to your Flutter game's main.dart

// 1. Create a new file: lib/map_loader.dart
import 'dart:convert';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/components.dart';
import 'package:nomercy/player.dart';
import 'package:nomercy/projectile.dart';

import 'action_game.dart';
import 'character_class.dart';
import 'character_stats.dart';
import 'enemy.dart';

// Map data structures
class GameMap {
  final String name;
  final double width;
  final double height;
  final List<PlatformData> platforms;
  final SpawnPoint playerSpawn;

  GameMap({
    required this.name,
    required this.width,
    required this.height,
    required this.platforms,
    required this.playerSpawn,
  });

  factory GameMap.fromJson(Map<String, dynamic> json) {
    return GameMap(
      name: json['name'] ?? 'unnamed',
      width: (json['width'] ?? 1200).toDouble(),
      height: (json['height'] ?? 800).toDouble(),
      platforms: (json['platforms'] as List)
          .map((p) => PlatformData.fromJson(p))
          .toList(),
      playerSpawn: SpawnPoint.fromJson(json['playerSpawn']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'width': width,
      'height': height,
      'platforms': platforms.map((p) => p.toJson()).toList(),
      'playerSpawn': playerSpawn.toJson(),
    };
  }
}

class PlatformData {
  final int id;
  final String type; // 'brick', 'ground'
  final double x;
  final double y;
  final double width;
  final double height;

  PlatformData({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory PlatformData.fromJson(Map<String, dynamic> json) {
    return PlatformData(
      id: json['id'] ?? 0,
      type: json['type'] ?? 'brick',
      x: (json['x'] ?? 0).toDouble(),
      y: (json['y'] ?? 0).toDouble(),
      width: (json['width'] ?? 120).toDouble(),
      height: (json['height'] ?? 20).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    };
  }
}

class SpawnPoint {
  final double x;
  final double y;

  SpawnPoint({required this.x, required this.y});

  factory SpawnPoint.fromJson(Map<String, dynamic> json) {
    return SpawnPoint(
      x: (json['x'] ?? 100).toDouble(),
      y: (json['y'] ?? 600).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'x': x, 'y': y};
  }
}

// Map Loader class
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
      playerSpawn: SpawnPoint(x: 100, y: 600),
    );
  }
}

// 3. Update Platform component to support different types:



// 4. Update GameScreen to accept map name:

class GameScreen extends StatelessWidget {
  final CharacterClass characterClass;
  final String mapName;

  const GameScreen({
    super.key,
    required this.characterClass,
    this.mapName = 'level_1',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: ActionGame(
          characterClass: characterClass,
          mapName: mapName,
        ),
      ),
    );
  }
}

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

class LevelSelectionScreen extends StatelessWidget {
  final CharacterClass characterClass;

  const LevelSelectionScreen({super.key, required this.characterClass});

  @override
  Widget build(BuildContext context) {
    final levels = ['level_1', 'level_2'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Level'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey[900]!, Colors.grey[800]!],
          ),
        ),
        child: GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
          ),
          itemCount: levels.length,
          itemBuilder: (context, index) {
            return _buildLevelCard(context, levels[index], index + 1);
          },
        ),
      ),
    );
  }

  Widget _buildLevelCard(BuildContext context, String mapName, int levelNum) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GameScreen(
              characterClass: characterClass,
              mapName: mapName,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[700]!, Colors.blue[900]!],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white30, width: 2),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.map, size: 48, color: Colors.white),
              const SizedBox(height: 8),
              Text(
                'Level $levelNum',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                mapName,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
