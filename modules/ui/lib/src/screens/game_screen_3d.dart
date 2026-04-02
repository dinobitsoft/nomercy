// modules/ui/lib/src/screens/game_screen_3d.dart

import 'package:engine/engine.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// Drop-in replacement for the 2D [GameScreen] that launches [ActionGame3D].
class GameScreen3D extends StatefulWidget {
  final String characterClass;
  final GameMode gameMode;
  final bool procedural;
  final MapGeneratorConfig? mapConfig;

  const GameScreen3D({
    super.key,
    required this.characterClass,
    required this.gameMode,
    this.procedural = true,
    this.mapConfig,
  });

  @override
  State<GameScreen3D> createState() => _GameScreen3DState();
}

class _GameScreen3DState extends State<GameScreen3D> {
  late final ActionGame3D _game;

  @override
  void initState() {
    super.initState();
    _game = ActionGame3D(
      selectedCharacterClass: widget.characterClass,
      gameMode:               widget.gameMode,
      procedural:             widget.procedural,
      mapConfig:              widget.mapConfig,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GameWidget(game: _game),

          // Back button (pause)
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: IconButton(
                  icon: const Icon(Icons.pause, color: Colors.white70, size: 28),
                  onPressed: () => _showPauseMenu(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPauseMenu(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('PAUSED',
            style: TextStyle(color: Colors.white, letterSpacing: 3)),
        actions: [
          TextButton(
            child: const Text('RESUME', style: TextStyle(color: Colors.greenAccent)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('QUIT', style: TextStyle(color: Colors.redAccent)),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

