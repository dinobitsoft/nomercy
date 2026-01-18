import 'package:flutter/material.dart';

import 'game_mode.dart';
import 'game_screen.dart';

class LevelSelectionScreen extends StatefulWidget {
  final String selectedCharacterClass;

  const LevelSelectionScreen({super.key, required this.selectedCharacterClass});

  @override
  State<LevelSelectionScreen> createState() => _LevelSelectionScreenState();
}

class _LevelSelectionScreenState extends State<LevelSelectionScreen> {
  bool enableMultiplayer = false;

  @override
  Widget build(BuildContext context) {
    final levels = ['level_1', 'level_2', 'level_3'];

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
                      icon: const Icon(Icons.arrow_back, size: 32),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 20),
                    const Text(
                      'Select Level',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    // Multiplayer toggle
                    _buildMultiplayerToggle(),
                  ],
                ),
              ),

              // Level grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(40),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: 1.8,
                  ),
                  itemCount: levels.length,
                  itemBuilder: (context, index) {
                    return _buildLevelCard(context, levels[index], index + 1);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMultiplayerToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: enableMultiplayer ? Colors.green : Colors.grey,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people,
            color: enableMultiplayer ? Colors.green : Colors.grey,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            'MULTIPLAYER',
            style: TextStyle(
              color: enableMultiplayer ? Colors.green : Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: enableMultiplayer,
            onChanged: (value) {
              setState(() {
                enableMultiplayer = value;
              });
            },
            activeColor: Colors.green,
            inactiveThumbColor: Colors.grey,
          ),
        ],
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
              selectedCharacterClass: widget.selectedCharacterClass,
              mapName: mapName,
              // enableMultiplayer: enableMultiplayer,
              gameMode: GameMode.survival, //TODO: fix by passing as parameter
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue[700]!, Colors.blue[900]!],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white30, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map, size: 60, color: Colors.white),
            const SizedBox(height: 10),
            Text(
              'Level $levelNum',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              mapName,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            if (enableMultiplayer)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green, width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi, color: Colors.green, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'ONLINE',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}