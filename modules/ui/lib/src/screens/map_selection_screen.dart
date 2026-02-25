import 'package:engine/engine.dart';
import 'package:flutter/material.dart';
import 'package:gamepad/gamepad.dart';
import 'package:ui/ui.dart';

import 'game_screen.dart';
enum _MapMode { procedural, premade, infinite }

// ── Index layout for procedural mode ─────────────────────────────────────────
// [0..5]  styles (row 0, cols 0-5)
// [6..11] diff lights (row 1, but only 4 visible — mapped as cols 0-3)
// [10]    generate button
// [11]    infinite button
//
// Actual flat indices:
//   styles    : 0-5
//   diffs     : 6-9
//   generate  : 10
//   inf launch: 11
const int _kStyles    = 6;
const int _kDiffs     = 4;
const int _kIdxPlay   = _kStyles + _kDiffs;      // 10
const int _kIdxInf    = _kStyles + _kDiffs + 1;  // 11

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
    with GamepadMenuController<MapSelectionScreen> {

  _MapMode      _mode       = _MapMode.procedural;
  MapStyle      _style      = MapStyle.balanced;
  MapDifficulty _difficulty = MapDifficulty.medium;
  int?          _customSeed;

  static final _styles = MapStyle.values;
  static final _diffs  = MapDifficulty.values;
  static const _levels = ['level_1', 'level_2', 'level_3'];

  static const _diffColors = {
    MapDifficulty.easy:   Color(0xFF4CAF50),
    MapDifficulty.medium: Color(0xFFFF9800),
    MapDifficulty.hard:   Color(0xFFF44336),
    MapDifficulty.expert: Color(0xFF9C27B0),
  };

  @override
  void initState() {
    super.initState();
    _rebuildItems();
  }

  void _rebuildItems() {
    switch (_mode) {
      case _MapMode.procedural:
        registerItems([
          for (int i = 0; i < _kStyles; i++)
            GamepadItem(
              onSelect: () { setState(() => _style = _styles[i]); },
              column: i, row: 0,
            ),
          for (int i = 0; i < _kDiffs; i++)
            GamepadItem(
              onSelect: () { setState(() => _difficulty = _diffs[i]); },
              column: i, row: 1,
            ),
          GamepadItem(onSelect: _launch, column: 0, row: 2),
        ], columns: _kStyles);

      case _MapMode.premade:
        registerItems([
          for (int i = 0; i < _levels.length; i++)
            GamepadItem(
              onSelect: () => _launch(_levels[i]),
              column: i, row: 0,
            ),
        ], columns: 3);

      case _MapMode.infinite:
        registerItems([
          for (int i = 0; i < _kStyles; i++)
            GamepadItem(
              onSelect: () { setState(() => _style = _styles[i]); },
              column: i, row: 0,
            ),
          for (int i = 0; i < _kDiffs; i++)
            GamepadItem(
              onSelect: () { setState(() => _difficulty = _diffs[i]); },
              column: i, row: 1,
            ),
          GamepadItem(onSelect: _launch, column: 0, row: 2),
        ], columns: _kStyles);
    }
  }

  void _setMode(_MapMode m) {
    setState(() => _mode = m);
    _rebuildItems();
  }

  // ── navigation ──────────────────────────────────────────────────────────────
  void _launch([String? premadeMap]) {
    switch (_mode) {
      case _MapMode.procedural:
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => GameScreen(
            selectedCharacterClass: widget.selectedCharacterClass,
            gameMode: widget.gameMode,
            procedural: true,
            mapConfig: MapGeneratorConfig(
                style: _style, difficulty: _difficulty, seed: _customSeed),
          ),
        ));
      case _MapMode.premade:
        if (premadeMap == null) return;
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => GameScreen(
            selectedCharacterClass: widget.selectedCharacterClass,
            mapName: premadeMap,
            gameMode: widget.gameMode,
          ),
        ));
      case _MapMode.infinite:
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => GameScreen(
            selectedCharacterClass: widget.selectedCharacterClass,
            gameMode: widget.gameMode,
            procedural: false,
            useInfiniteWorld: true,
            mapConfig: MapGeneratorConfig(
                style: _style, difficulty: _difficulty, seed: _customSeed),
          ),
        ));
    }
  }

  // ── build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey[900]!, Colors.grey[850]!],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 40, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 26, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 16),
                    Text(context.translate('select_map'),
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),

              // Mode tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 6),
                child: Row(children: [
                  Expanded(child: _tab(context.translate('procedural_maps'), Icons.auto_awesome, _MapMode.procedural)),
                  const SizedBox(width: 10),
                  Expanded(child: _tab(context.translate('premade_maps'),    Icons.map,           _MapMode.premade)),
                  const SizedBox(width: 10),
                  Expanded(child: _tab(context.translate('infinite_map'),    Icons.all_inclusive, _MapMode.infinite)),
                ]),
              ),

              // Content — no scroll, fills remaining space
              Expanded(child: _buildContent()),

              const GamepadHintBar(confirmLabel: 'Select'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(String label, IconData icon, _MapMode mode) {
    final selected = _mode == mode;
    return GestureDetector(
      onTap: () => _setMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.blue : Colors.grey[800],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? Colors.blue : Colors.grey[600]!, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_mode) {
      case _MapMode.procedural:
      case _MapMode.infinite:   return _buildProcedural();
      case _MapMode.premade:    return _buildPremade();
    }
  }

  // ── PROCEDURAL ── no scroll, Row: left=crosslight, right=styles+seed+launch ─
  Widget _buildProcedural() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Difficulty crosslight ──────────────────────────────────────────
          DifficultyLights(
            diffs:      _diffs,
            selected:   _difficulty,
            colors:     _diffColors,
            focusStart: _kStyles,       // gamepad flat index of first diff item
            isFocused:  isFocused,
            onSelect:   (d) { setState(() => _difficulty = d); },
          ),

          const SizedBox(width: 20),

          // ── Right panel ───────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Style label
                Text(context.translate('map_style'),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),

                // Style tiles — stretch full width equally
                SizedBox(
                  height: 80,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: List.generate(_styles.length, (i) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                          child: GamepadMenuItem(
                            focused: isFocused(i),
                            onTap: () => setState(() => _style = _styles[i]),
                            borderRadius: BorderRadius.circular(10),
                            child: StyleTile(style: _styles[i], selected: _style == _styles[i]),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                const Spacer(),

                // Seed row
                Row(
                  children: [
                    Text(context.translate('custom_seed'),
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 90, height: 32,
                      child: TextField(
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: context.translate('random_hint'),
                          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 11),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[600]!)),
                          focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue)),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => _customSeed = int.tryParse(v),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Single PLAY button
                GamepadMenuItem(
                  focused: isFocused(_kIdxPlay),
                  onTap: _launch,
                  borderRadius: BorderRadius.circular(10),
                  child: LaunchBtn(
                    label: 'PLAY',
                    color: Colors.green,
                    icon: Icons.play_arrow,
                    onTap: _launch,
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }


  // ── PREMADE ─────────────────────────────────────────────────────────────────
  Widget _buildPremade() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
      child: GridView.count(
        crossAxisCount: 3,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 2.2,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(_levels.length, (i) {
          return GamepadMenuItem(
            focused: isFocused(i),
            onTap: () => _launch(_levels[i]),
            borderRadius: BorderRadius.circular(15),
            child: LevelCard(
              mapName: _levels[i],
              levelNum: i + 1,
              label: context.translate('level'),
              onTap: () => _launch(_levels[i]),
            ),
          );
        }),
      ),
    );
  }

}
