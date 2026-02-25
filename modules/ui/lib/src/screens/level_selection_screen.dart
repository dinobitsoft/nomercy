import 'package:engine/engine.dart';
import 'package:flutter/material.dart';
import 'game_screen.dart';
import 'package:gamepad/gamepad.dart';

class LevelSelectionScreen extends StatefulWidget {
  final String selectedCharacterClass;

  const LevelSelectionScreen({super.key, required this.selectedCharacterClass});

  @override
  State<LevelSelectionScreen> createState() => _LevelSelectionScreenState();
}

class _LevelSelectionScreenState extends State<LevelSelectionScreen>
    with GamepadMenuController {

  bool enableMultiplayer = false;

  static const _levels = ['level_1', 'level_2', 'level_3'];

  @override
  void initState() {
    super.initState();
    _rebuildItems();
  }

  void _rebuildItems() {
    registerItems([
      for (int i = 0; i < _levels.length; i++)
        GamepadItem(
          onSelect: () => _launch(_levels[i]),
          column: i,
          row: 0,
        ),
    ], columns: 3);
  }

  void _launch(String mapName) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => GameScreen(
        selectedCharacterClass: widget.selectedCharacterClass,
        mapName: mapName,
        enableMultiplayer: enableMultiplayer,
        gameMode: GameMode.survival,
      ),
    ));
  }

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
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 28, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 20),
                    const Text(
                      'SELECT LEVEL',
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const Spacer(),
                    _buildMultiplayerToggle(),
                  ],
                ),
              ),

              Expanded(
                child: GridView.count(
                  crossAxisCount: 3,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 2.2,
                  physics: const NeverScrollableScrollPhysics(),
                  children: List.generate(_levels.length, (i) {
                    return GamepadMenuItem(
                      focused: isFocused(i),
                      onTap: () => _launch(_levels[i]),
                      borderRadius: BorderRadius.circular(15),
                      child: _buildLevelCard(_levels[i], i + 1),
                    );
                  }),
                ),
              ),

              const GamepadHintBar(confirmLabel: 'Launch Level'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMultiplayerToggle() {
    return GestureDetector(
      onTap: () => setState(() { enableMultiplayer = !enableMultiplayer; }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: enableMultiplayer ? Colors.green : Colors.grey,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people,
                color: enableMultiplayer ? Colors.green : Colors.grey, size: 20),
            const SizedBox(width: 8),
            Text('MULTIPLAYER',
                style: TextStyle(
                    color: enableMultiplayer ? Colors.green : Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            Switch(
              value: enableMultiplayer,
              onChanged: (v) => setState(() { enableMultiplayer = v; }),
              activeColor: Colors.green,
              inactiveThumbColor: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelCard(String mapName, int levelNum) {
    return GestureDetector(
      onTap: () => _launch(mapName),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue[700]!, Colors.blue[900]!],
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white30, width: 2),
          boxShadow: [
            BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 10, spreadRadius: 1),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map, size: 40, color: Colors.white),
            const SizedBox(height: 5),
            Text('Level $levelNum',
                style: const TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(mapName, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}