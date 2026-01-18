import 'package:flutter/material.dart';
import '../game_mode.dart';
import '../game_screen.dart';
import 'map_generator_config.dart';

class MapSelectionScreen extends StatefulWidget {
  final String selectedCharacterClass;
  final GameMode gameMode;

  const MapSelectionScreen({
    super.key,
    required this.selectedCharacterClass,
    required this.gameMode,
  });

  @override
  State<MapSelectionScreen> createState() => _MapSelectionScreenState();
}

class _MapSelectionScreenState extends State<MapSelectionScreen> {
  bool useProceduralMap = true;
  MapStyle selectedStyle = MapStyle.balanced;
  MapDifficulty selectedDifficulty = MapDifficulty.medium;
  int? customSeed;

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
                      'Select Map',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Map Type Toggle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTypeButton(
                        'Procedural Maps',
                        Icons.auto_awesome,
                        useProceduralMap,
                            () => setState(() => useProceduralMap = true),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildTypeButton(
                        'Pre-made Maps',
                        Icons.map,
                        !useProceduralMap,
                            () => setState(() => useProceduralMap = false),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Content based on selection
              Expanded(
                child: useProceduralMap
                    ? _buildProceduralOptions()
                    : _buildPremadeOptions(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(String label, IconData icon, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[800],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[600]!,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProceduralOptions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Map Style',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),

          // Style selection
          Wrap(
            spacing: 15,
            runSpacing: 15,
            children: MapStyle.values.map((style) {
              return _buildStyleCard(style);
            }).toList(),
          ),

          const SizedBox(height: 30),

          const Text(
            'Difficulty',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),

          // Difficulty selection
          Row(
            children: MapDifficulty.values.map((diff) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: _buildDifficultyButton(diff),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 30),

          // Custom seed option
          Row(
            children: [
              const Text(
                'Custom Seed (optional):',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(width: 20),
              SizedBox(
                width: 150,
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Random',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[600]!),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    customSeed = int.tryParse(value);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),

          // Generate button
          Center(
            child: ElevatedButton(
              onPressed: _startWithProceduralMap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow, size: 32, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    'GENERATE & PLAY',
                    style: TextStyle(fontSize: 24, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleCard(MapStyle style) {
    final isSelected = selectedStyle == style;
    final info = _getStyleInfo(style);

    return GestureDetector(
      onTap: () => setState(() => selectedStyle = style),
      child: Container(
        width: 180,
        height: 160,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? [Colors.blue[700]!, Colors.blue[900]!]
                : [Colors.grey[800]!, Colors.grey[900]!],
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[600]!,
            width: isSelected ? 3 : 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(info['icon'] as IconData, size: 50, color: Colors.white),
            const SizedBox(height: 10),
            Text(
              info['name'] as String,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              info['desc'] as String,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyButton(MapDifficulty difficulty) {
    final isSelected = selectedDifficulty == difficulty;
    final colors = {
      MapDifficulty.easy: Colors.green,
      MapDifficulty.medium: Colors.orange,
      MapDifficulty.hard: Colors.red,
      MapDifficulty.expert: Colors.purple,
    };

    return GestureDetector(
      onTap: () => setState(() => selectedDifficulty = difficulty),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: isSelected ? colors[difficulty] : Colors.grey[800],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? colors[difficulty]! : Colors.grey[600]!,
            width: 2,
          ),
        ),
        child: Text(
          difficulty.name.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildPremadeOptions() {
    final levels = ['level_1', 'level_2', 'level_3'];

    return GridView.builder(
      padding: const EdgeInsets.all(40),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 1.5,
      ),
      itemCount: levels.length,
      itemBuilder: (context, index) {
        return _buildLevelCard(levels[index], index + 1);
      },
    );
  }

  Widget _buildLevelCard(String mapName, int levelNum) {
    return GestureDetector(
      onTap: () => _startWithPremadeMap(mapName),
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
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getStyleInfo(MapStyle style) {
    switch (style) {
      case MapStyle.arena:
        return {
          'name': 'Arena',
          'desc': 'Open combat\nzone',
          'icon': Icons.sports_mma,
        };
      case MapStyle.platformer:
        return {
          'name': 'Platformer',
          'desc': 'Vertical\nchallenge',
          'icon': Icons.stairs,
        };
      case MapStyle.dungeon:
        return {
          'name': 'Dungeon',
          'desc': 'Rooms &\ncorridors',
          'icon': Icons.domain,
        };
      case MapStyle.towers:
        return {
          'name': 'Towers',
          'desc': 'Sky-high\nbattle',
          'icon': Icons.apartment,
        };
      case MapStyle.chaos:
        return {
          'name': 'Chaos',
          'desc': 'Random\nmadness',
          'icon': Icons.shuffle,
        };
      case MapStyle.balanced:
        return {
          'name': 'Balanced',
          'desc': 'Mixed\nlayout',
          'icon': Icons.balance,
        };
    }
  }

  void _startWithProceduralMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(
          selectedCharacterClass: widget.selectedCharacterClass,
          gameMode: widget.gameMode,
          procedural: true,
          mapConfig: MapGeneratorConfig(
            style: selectedStyle,
            difficulty: selectedDifficulty,
            seed: customSeed,
          ),
        ),
      ),
    );
  }

  void _startWithPremadeMap(String mapName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(
          selectedCharacterClass: widget.selectedCharacterClass,
          mapName: mapName,
          gameMode: widget.gameMode,
          procedural: false,
        ),
      ),
    );
  }
}