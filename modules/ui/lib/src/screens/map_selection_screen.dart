import 'package:engine/engine.dart';
import 'package:flutter/material.dart';
import 'package:ui/ui.dart';

import 'game_screen.dart';

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
  bool _useInfiniteWorld = false;
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
              // Header - Reduced padding
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 28, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 20),
                    Text(
                      context.translate('select_map'),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Map Type Toggle - Reduced height and padding
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTypeButton(
                        context.translate('procedural_maps'),
                        Icons.auto_awesome,
                        useProceduralMap,
                            () => setState(() => useProceduralMap = true),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildTypeButton(
                        context.translate('premade_maps'),
                        Icons.map,
                        !useProceduralMap,
                            () => setState(() => useProceduralMap = false),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildTypeButton(
                        context.translate('infinite_map'),
                        Icons.map,
                        _useInfiniteWorld,
                            () => setState(() => _useInfiniteWorld = true),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

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
        padding: const EdgeInsets.symmetric(vertical: 10), // Reduced
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
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14, // Reduced
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
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 0),
      physics: const NeverScrollableScrollPhysics(), // Force fit if possible
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Style selection - Compact grid
          SizedBox(
            height: 120, // Fixed height for style cards
            child: GridView.count(
              crossAxisCount: 6,
              crossAxisSpacing: 10,
              mainAxisSpacing: 0,
              physics: const NeverScrollableScrollPhysics(),
              children: MapStyle.values.map((style) {
                return _buildStyleCard(style);
              }).toList(),
            ),
          ),

          const SizedBox(height: 15),

          Text(
            context.translate('difficulty'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18, // Reduced
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Difficulty selection - Compact
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

          const SizedBox(height: 15),

          // Custom seed and Generate button - Side by side
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Text(
                      context.translate('custom_seed'),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 100,
                      height: 35,
                      child: TextField(
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: context.translate('random_hint'),
                          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
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
              ),
              const SizedBox(width: 20),
              // Generate button
              Expanded(
                flex: 1,
                child: ElevatedButton(
                  onPressed: _startWithProceduralMap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_arrow, size: 20, color: Colors.white),
                      const SizedBox(width: 5),
                      Text(
                        context.translate('generate_play'),
                        style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Generate button
              Expanded(
                flex: 1,
                child: ElevatedButton(
                  onPressed: _startWithInfiniteMap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_arrow, size: 20, color: Colors.white),
                      const SizedBox(width: 5),
                      Text(
                        context.translate('infinite_play'),
                        style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? [Colors.blue[700]!, Colors.blue[900]!]
                : [Colors.grey[800]!, Colors.grey[900]!],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[600]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(info['icon'] as IconData, size: 24, color: Colors.white),
            const SizedBox(height: 5),
            Text(
              context.translate(info['name'].toString().toLowerCase()),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              context.translate('${info['name'].toString().toLowerCase()}_desc'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 8,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? colors[difficulty] : Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? colors[difficulty]! : Colors.grey[600]!,
            width: 1.5,
          ),
        ),
        child: Text(
          context.translate(difficulty.name.toLowerCase()),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildPremadeOptions() {
    final levels = ['level_1', 'level_2', 'level_3'];

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 2.2,
      ),
      itemCount: levels.length,
      physics: const NeverScrollableScrollPhysics(),
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
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white30, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map, size: 40, color: Colors.white),
            const SizedBox(height: 5),
            Text(
              '${context.translate('level')} $levelNum',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              mapName,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
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
          'desc': 'Open combat zone',
          'icon': Icons.sports_mma,
        };
      case MapStyle.platformer:
        return {
          'name': 'Platformer',
          'desc': 'Vertical challenge',
          'icon': Icons.stairs,
        };
      case MapStyle.dungeon:
        return {
          'name': 'Dungeon',
          'desc': 'Rooms & corridors',
          'icon': Icons.domain,
        };
      case MapStyle.towers:
        return {
          'name': 'Towers',
          'desc': 'Sky-high battle',
          'icon': Icons.apartment,
        };
      case MapStyle.chaos:
        return {
          'name': 'Chaos',
          'desc': 'Random madness',
          'icon': Icons.shuffle,
        };
      case MapStyle.balanced:
        return {
          'name': 'Balanced',
          'desc': 'Mixed layout',
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

  void _startWithInfiniteMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(
          selectedCharacterClass: widget.selectedCharacterClass,
          gameMode: widget.gameMode,
          procedural: false,
          useInfiniteWorld: true,
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
