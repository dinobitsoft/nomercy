import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'action_game.dart';
import 'character_class.dart';

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