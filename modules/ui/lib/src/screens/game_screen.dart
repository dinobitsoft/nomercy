import 'package:engine/engine.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:ui/ui.dart';

class GameScreen extends StatefulWidget {
  final String selectedCharacterClass;
  final String? mapName;
  final GameMode gameMode;
  final bool procedural;
  final MapGeneratorConfig? mapConfig;
  final bool enableMultiplayer;
  final String? roomId;

  const GameScreen({
    super.key,
    required this.selectedCharacterClass,
    this.mapName,
    this.gameMode = GameMode.survival,
    this.procedural = false,
    this.mapConfig,
    this.enableMultiplayer = false,
    this.roomId,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late ActionGame _game;

  @override
  void initState() {
    super.initState();
    _game = ActionGame(
      selectedCharacterClass: widget.selectedCharacterClass,
      mapName: widget.mapName ?? 'level_1',
      gameMode: widget.gameMode,
      procedural: widget.procedural,
      mapConfig: widget.mapConfig,
      enableMultiplayer: widget.enableMultiplayer,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Game
          GameWidget(
            game: _game,
          ),

          // Pause button
          Positioned(
            top: 100,
            left: 20,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.backpack, size: 32, color: Colors.white),
                onPressed: () async {
                  _game.pauseEngine();

                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InventoryScreen(
                        inventory: _game.inventory,
                        equippedWeapon: _game.equippedWeapon,
                        playerStats: _game.character.stats,
                        onEquipWeapon: (weapon) {
                          _game.equipWeapon(weapon);
                        },
                        onSellItem: (item) {
                          _game.sellItem(item);
                        },
                        onBuyWeapon: (weapon) {
                          _game.buyWeapon(weapon);
                        },
                      ),
                    ),
                  );

                  _game.resumeEngine();
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
            if (widget.procedural && widget.mapConfig != null) ...[
              Text(
                'Map Style: ${widget.mapConfig!.style.name}',
                style: const TextStyle(color: Colors.white70),
              ),
              Text(
                'Difficulty: ${widget.mapConfig!.difficulty.name}',
                style: const TextStyle(color: Colors.white70),
              ),
              Text(
                'Seed: ${widget.mapConfig!.seed}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ] else ...[
              Text(
                'Map: ${widget.mapName}',
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