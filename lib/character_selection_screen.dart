import 'package:flutter/material.dart';

import 'character_class.dart';
import 'character_stats.dart';
import 'level_selection_screen.dart';
import 'gamepad_manager.dart';

class CharacterSelectionScreen extends StatefulWidget {
  const CharacterSelectionScreen({super.key});

  @override
  State<CharacterSelectionScreen> createState() => _CharacterSelectionScreenState();
}

class _CharacterSelectionScreenState extends State<CharacterSelectionScreen> {
  CharacterClass? selectedClass;

  @override
  void initState() {
    super.initState();
    // Initial check for already connected gamepads
    GamepadManager().checkConnection();
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
          child: Stack(
            children: [
              Row(
                children: [
                  // Left side - Title and info
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Choose Your\nCharacter',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (selectedClass != null) ...[
                            ElevatedButton(
                              onPressed: () => _startGame(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 30,
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'START GAME',
                                    style: TextStyle(fontSize: 24, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Right side - Character grid
                  Expanded(
                    flex: 3,
                    child: GridView.count(
                      crossAxisCount: 2,
                      padding: const EdgeInsets.all(50),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.2,
                      children: CharacterClass.values.map((charClass) {
                        final stats = CharacterStats.fromClass(charClass);
                        return _buildCharacterCard(charClass, stats);
                      }).toList(),
                    ),
                  ),
                ],
              ),
              
              // Gamepad Connection Indicator
              Positioned(
                top: 20,
                right: 20,
                child: ValueListenableBuilder<bool>(
                  valueListenable: GamepadManager().connected,
                  builder: (context, isConnected, child) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isConnected ? Colors.green : Colors.grey,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.videogame_asset_outlined,
                            color: isConnected ? Colors.green : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isConnected ? 'GAMEPAD READY' : 'NO GAMEPAD',
                            style: TextStyle(
                              color: isConnected ? Colors.green : Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCharacterCard(CharacterClass charClass, CharacterStats stats) {
    final isSelected = selectedClass == charClass;
    return GestureDetector(
      onTap: () => setState(() => selectedClass = charClass),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? stats.color.withOpacity(0.3) : Colors.grey[800],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? stats.color : Colors.transparent,
            width: 4,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: stats.color.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 2,
            )
          ]
              : [],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              charClass.name.toUpperCase(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Weapon: ${stats.weaponName}',
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statColumn('PWR', stats.power),
                _statColumn('MAG', stats.magic),
                _statColumn('DEX', stats.dexterity),
                _statColumn('INT', stats.intelligence),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statColumn(String label, double value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[400],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.toInt().toString(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  void _startGame(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LevelSelectionScreen(
          characterClass: selectedClass!,
        ),
      ),
    );
  }
}
