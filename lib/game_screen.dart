import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'action_game.dart';
import 'game_mode.dart';

class GameScreen extends StatelessWidget {
  final String selectedCharacterClass;
  final String mapName;
  final bool enableMultiplayer;
  final GameMode gameMode;

  const GameScreen({
    super.key,
    required this.selectedCharacterClass,
    required this.gameMode,
    this.mapName = 'level_1',
    this.enableMultiplayer = false, // Add multiplayer toggle
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: ActionGame(
          selectedCharacterClass: selectedCharacterClass,
          mapName: mapName,
          enableMultiplayer: enableMultiplayer,
          gameMode: gameMode
        ),
      ),
    );
  }
}