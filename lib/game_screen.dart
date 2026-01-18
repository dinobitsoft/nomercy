import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'action_game.dart';
import 'game_mode.dart';
import 'map/map_generator_config.dart';

class GameScreen extends StatelessWidget {
  final String selectedCharacterClass;
  final String? mapName;
  final GameMode gameMode;
  final bool procedural;
  final MapGeneratorConfig? mapConfig;
  final bool enableMultiplayer;

  const GameScreen({
    super.key,
    required this.selectedCharacterClass,
    this.mapName,
    this.gameMode = GameMode.survival,
    this.procedural = false,
    this.mapConfig,
    this.enableMultiplayer = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Game
          GameWidget(
            game: ActionGame(
              selectedCharacterClass: selectedCharacterClass,
              mapName: mapName ?? 'level_1',
              gameMode: gameMode,
              procedural: procedural,
              mapConfig: mapConfig,
              enableMultiplayer: enableMultiplayer,
            ),
          ),

          // Pause button
          Positioned(
            top: 40,
            left: 20,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.pause, size: 32, color: Colors.white),
                onPressed: () {
                  _showPauseMenu(context);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPauseMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Game Paused',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (procedural && mapConfig != null) ...[
              Text(
                'Map Style: ${mapConfig!.style.name}',
                style: const TextStyle(color: Colors.white70),
              ),
              Text(
                'Difficulty: ${mapConfig!.difficulty.name}',
                style: const TextStyle(color: Colors.white70),
              ),
              Text(
                'Seed: ${mapConfig!.seed}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ] else ...[
              Text(
                'Map: $mapName',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Resume'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Exit game
            },
            child: const Text('Quit', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}