// pubspec.yaml dependencies:
// dependencies:
//   flutter:
//     sdk: flutter
//   flame: ^1.17.0
//   flame_forge2d: ^0.17.0
//   socket_io_client: ^2.0.3
//
// flutter:
//   assets:
//     - assets/images/knight.png
//     - assets/images/thief.png
//     - assets/images/wizard.png
//     - assets/images/trader.png
//     - assets/images/knight_attack.png
//     - assets/images/thief_attack.png
//     - assets/images/wizard_attack.png
//     - assets/images/trader_attack.png

// main.dart
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'dart:math' as math;

import 'package:nomercy/player.dart';

import 'action_game.dart';
import 'character_class.dart';
import 'character_stats.dart';
import 'game_map.dart';
import 'game_screen.dart';

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

// Character Classes




// Character Selection Screen
class CharacterSelectionScreen extends StatefulWidget {
  const CharacterSelectionScreen({super.key});

  @override
  State<CharacterSelectionScreen> createState() => _CharacterSelectionScreenState();
}

class _CharacterSelectionScreenState extends State<CharacterSelectionScreen> {
  CharacterClass? selectedClass;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey[900]!, Colors.grey[800]!],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text(
                'Choose Your Character',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  padding: const EdgeInsets.all(20),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: CharacterClass.values.map((charClass) {
                    final stats = CharacterStats.fromClass(charClass);
                    return _buildCharacterCard(charClass, stats);
                  }).toList(),
                ),
              ),
              if (selectedClass != null)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: ElevatedButton(
                    onPressed: () => _startGame(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                    ),
                    child: const Text('START GAME', style: TextStyle(fontSize: 20, color: Colors.white)),
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
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? stats.color : Colors.transparent,
            width: 3,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              charClass.name.toUpperCase(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Weapon: ${stats.weaponName}', style: const TextStyle(fontSize: 12)),
            const Spacer(),
            _statRow('Power', stats.power),
            _statRow('Magic', stats.magic),
            _statRow('Dexterity', stats.dexterity),
            _statRow('Intelligence', stats.intelligence),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String name, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(fontSize: 11)),
          Text(value.toInt().toString(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
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
