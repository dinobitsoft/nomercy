import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'action_game.dart';

class GameScreen extends StatelessWidget {
  final String selectedCharacterClass;
  final String mapName;

  const GameScreen({
    super.key,
    required this.selectedCharacterClass,
    this.mapName = 'level_1',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: ActionGame(
          selectedCharacterClass: selectedCharacterClass,
          mapName: mapName,
        ),
      ),
    );
  }
}