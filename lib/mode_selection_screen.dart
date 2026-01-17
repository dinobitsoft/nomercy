import 'package:flutter/material.dart';
import 'game_manager.dart';
import 'game_mode.dart';
import 'game_screen.dart';

class ModeSelectionScreen extends StatelessWidget {
  final String selectedCharacterClass;

  const ModeSelectionScreen({
    super.key,
    required this.selectedCharacterClass,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey[900]!, Colors.grey[800]!],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 32, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 20),
                    const Text(
                      'Select Game Mode',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Mode Cards
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  padding: const EdgeInsets.all(40),
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  children: [
                    _buildModeCard(
                      context,
                      'Survival',
                      'Endless waves of enemies\nHow long can you survive?',
                      Icons.shield,
                      Colors.orange,
                      GameMode.survival,
                    ),
                    _buildModeCard(
                      context,
                      'Campaign',
                      'Story mode with boss fights\nComplete all waves!',
                      Icons.book,
                      Colors.blue,
                      GameMode.campaign,
                    ),
                    _buildModeCard(
                      context,
                      'Boss Fight',
                      'Face a powerful boss\nCan you defeat it?',
                      Icons.dangerous,
                      Colors.red,
                      GameMode.bossFight,
                    ),
                    _buildModeCard(
                      context,
                      'Training',
                      'Practice mode\nPerfect your skills',
                      Icons.fitness_center,
                      Colors.green,
                      GameMode.training,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard(
      BuildContext context,
      String title,
      String description,
      IconData icon,
      Color color,
      GameMode mode,
      ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GameScreen(
              selectedCharacterClass: selectedCharacterClass,
              mapName: 'level_1',
              gameMode: mode,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.8),
              color.withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white30, width: 3),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.white),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Update your GameScreen to accept gameMode parameter:
/*
class GameScreen extends StatelessWidget {
  final String selectedCharacterClass;
  final String mapName;
  final GameMode gameMode; // NEW

  const GameScreen({
    super.key,
    required this.selectedCharacterClass,
    this.mapName = 'level_1',
    this.gameMode = GameMode.survival, // NEW
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: ActionGame(
          selectedCharacterClass: selectedCharacterClass,
          mapName: mapName,
          gameMode: gameMode, // NEW - Pass mode to game
        ),
      ),
    );
  }
}
*/