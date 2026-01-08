import 'package:flutter/material.dart';

import 'character_selection_screen.dart';

void main() {
  runApp(const GameApp());
}

class GameApp extends StatelessWidget {
  const GameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '2D Action Game',
      theme: ThemeData.dark(),
      home: const CharacterSelectionScreen(),
    );
  }
}
