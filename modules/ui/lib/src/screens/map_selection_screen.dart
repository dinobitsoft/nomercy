import 'package:engine/engine.dart';
import 'package:flutter/material.dart';
import 'package:gamepad/gamepad.dart';

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

class _MapSelectionScreenState extends State<MapSelectionScreen>
    with GamepadMenuController {

  bool useProceduralMap = true;
  bool _useInfiniteWorld = false;
  MapStyle selectedStyle = MapStyle.balanced;
  MapDifficulty selectedDifficulty = MapDifficulty.medium;
  int? customSeed;

  // For procedural: items are styles (6) + difficulties (4) + generate button (1)
  // For premade: items are level cards (3)
  static final _styles     = MapStyle.values;
  static final _diffs      = MapDifficulty.values;
  static const _levels     = ['level_1', 'level_2', 'level_3'];

  @override
  void initState() {
    super.initState();
    _rebuildItems();
  }

  void _rebuildItems() {
    if (useProceduralMap) {
      // Layout: row0 = styles (6 cols), row1 = diffs (4 cols), row2 = generate btn
      final items = <GamepadItem>[
        // Styles
        for (int i = 0; i < _styles.length; i++)
          GamepadItem(
            onSelect: () { setState(() { selectedStyle = _styles[i]; _rebuildItems(); }); },
            column: i, row: 0,
          ),
        // Difficulties
        for (int i = 0; i < _diffs.length; i++)
          GamepadItem(
            onSelect: () { setState(() { selectedDifficulty = _diffs[i]; _rebuildItems(); }); },
            column: i, row: 1,
          ),
        // Generate button (wide, single col)
        GamepadItem(onSelect: _startWithProceduralMap, column: 0, row: 2),
      ];
      registerItems(items, columns: 6); // max cols = 6 (styles row)
    } else {
      registerItems([
        for (int i = 0; i < _levels.length; i++)
          GamepadItem(
            onSelect: () => _startWithPremadeMap(_levels[i]),
            column: i, row: 0,
          ),
      ], columns: 3);
    }
  }

  void _startWithProceduralMap() {
    final config = MapGeneratorConfig(
      style: selectedStyle,
      difficulty: selectedDifficulty,
      seed: customSeed,
    );
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => GameScreen(
        selectedCharacterClass: widget.selectedCharacterClass,
        gameMode: widget.gameMode,
        procedural: true,
        useInfiniteWorld: _useInfiniteWorld,
        mapConfig: config,
      ),
    ));
  }

  void _startWithPremadeMap(String mapName) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => GameScreen(
        selectedCharacterClass: widget.selectedCharacterClass,
        mapName: mapName,
        gameMode: widget.gameMode,
      ),
    ));
  }

  // Compute the flat index for a style card
  int _styleIndex(int i) => i;
  // Compute the flat index for a diff card
  int _diffIndex(int i) => _styles.length + i;
  // Generate button flat index
  int get _genBtnIndex => _styles.length + _diffs.length;

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
              // ── Header ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
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
                          fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const Spacer(),
                    // Map type toggle
                    _buildTypeToggle(),
                  ],
                ),
              ),

              // ── Content ────────────────────────────────────────────────────
              Expanded(
                child: useProceduralMap
                    ? _buildProceduralOptions()
                    : _buildPremadeOptions(),
              ),

              const GamepadHintBar(confirmLabel: 'Select'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeToggle() {
    return Row(
      children: [
        _typeBtn(context.translate('procedural_maps'), Icons.auto_awesome, useProceduralMap, () {
          setState(() { useProceduralMap = true; _rebuildItems(); });
        }),
        const SizedBox(width: 10),
        _typeBtn(context.translate('premade_maps'), Icons.map, !useProceduralMap, () {
          setState(() { useProceduralMap = false; _rebuildItems(); });
        }),
      ],
    );
  }

  Widget _typeBtn(String label, IconData icon, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? Colors.blue : Colors.grey[800],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? Colors.blue : Colors.grey[600]!, width: 2),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildProceduralOptions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.translate('map_style'),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          // Style grid
          SizedBox(
            height: 110,
            child: GridView.count(
              crossAxisCount: 6,
              crossAxisSpacing: 10,
              physics: const NeverScrollableScrollPhysics(),
              children: List.generate(_styles.length, (i) {
                final idx = _styleIndex(i);
                return GamepadMenuItem(
                  focused: isFocused(idx),
                  onTap: () { setState(() { selectedStyle = _styles[i]; _rebuildItems(); }); },
                  borderRadius: BorderRadius.circular(10),
                  child: _buildStyleCard(_styles[i]),
                );
              }),
            ),
          ),

          const SizedBox(height: 15),
          Text(context.translate('difficulty'),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          // Difficulty row
          Row(
            children: List.generate(_diffs.length, (i) {
              final idx = _diffIndex(i);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: GamepadMenuItem(
                    focused: isFocused(idx),
                    onTap: () { setState(() { selectedDifficulty = _diffs[i]; _rebuildItems(); }); },
                    borderRadius: BorderRadius.circular(8),
                    child: _buildDifficultyButton(_diffs[i]),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 15),

          // Seed + Generate
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Text(context.translate('custom_seed'),
                        style: const TextStyle(color: Colors.white, fontSize: 13)),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 100,
                      height: 35,
                      child: TextField(
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: context.translate('random_hint'),
                          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                          enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[600]!)),
                          focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue)),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => customSeed = int.tryParse(v),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: GamepadMenuItem(
                  focused: isFocused(_genBtnIndex),
                  onTap: _startWithProceduralMap,
                  borderRadius: BorderRadius.circular(10),
                  child: ElevatedButton(
                    onPressed: _startWithProceduralMap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(context.translate('generate_play'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    final info = _getStyleInfo(style);
    final isSelected = selectedStyle == style;
    return GestureDetector(
      onTap: () => setState(() { selectedStyle = style; _rebuildItems(); }),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? (info['color'] as Color).withOpacity(0.3) : Colors.grey[800],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? (info['color'] as Color) : Colors.grey[600]!,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(info['icon'] as IconData, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(info['name'] as String,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
    final color = colors[difficulty]!;
    return GestureDetector(
      onTap: () => setState(() { selectedDifficulty = difficulty; _rebuildItems(); }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.3) : Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey[600]!,
            width: 1.5,
          ),
        ),
        child: Text(
          context.translate(difficulty.name.toLowerCase()),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildPremadeOptions() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 2.2,
      ),
      itemCount: _levels.length,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (_, i) {
        return GamepadMenuItem(
          focused: isFocused(i),
          onTap: () => _startWithPremadeMap(_levels[i]),
          borderRadius: BorderRadius.circular(15),
          child: _buildLevelCard(_levels[i], i + 1),
        );
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
            BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 10, spreadRadius: 1),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map, size: 40, color: Colors.white),
            const SizedBox(height: 5),
            Text('${context.translate('level')} $levelNum',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(mapName, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getStyleInfo(MapStyle style) {
    switch (style) {
      case MapStyle.arena:      return {'name': context.translate('arena'),     'icon': Icons.sports_mma,       'color': Colors.red};
      case MapStyle.platformer: return {'name': context.translate('platformer'),'icon': Icons.layers,           'color': Colors.blue};
      case MapStyle.dungeon:    return {'name': context.translate('dungeon'),   'icon': Icons.castle,           'color': Colors.purple};
      case MapStyle.towers:     return {'name': context.translate('towers'),    'icon': Icons.apartment,        'color': Colors.orange};
      case MapStyle.chaos:      return {'name': context.translate('chaos'),     'icon': Icons.auto_awesome,     'color': Colors.pink};
      case MapStyle.balanced:   return {'name': context.translate('balanced'),  'icon': Icons.balance,          'color': Colors.green};
    }
  }
}