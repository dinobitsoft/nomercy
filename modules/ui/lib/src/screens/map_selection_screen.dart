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
const int _kIdxGen    = _kStyles + _kDiffs;      // 10
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
          GamepadItem(onSelect: _launchProcedural, column: 0, row: 2),
          GamepadItem(onSelect: _launchInfinite,   column: 1, row: 2),
        ], columns: _kStyles);

      case _MapMode.premade:
        registerItems([
          for (int i = 0; i < _levels.length; i++)
            GamepadItem(
              onSelect: () => _launchPremade(_levels[i]),
              column: i, row: 0,
            ),
        ], columns: 3);

      case _MapMode.infinite:
        registerItems([
          GamepadItem(onSelect: _launchInfinite),
        ]);
    }
  }

  void _setMode(_MapMode m) {
    setState(() => _mode = m);
    _rebuildItems();
  }

  // ── navigation ──────────────────────────────────────────────────────────────
  void _launchProcedural() => Navigator.push(context, MaterialPageRoute(
    builder: (_) => GameScreen(
      selectedCharacterClass: widget.selectedCharacterClass,
      gameMode: widget.gameMode,
      procedural: true,
      mapConfig: MapGeneratorConfig(
          style: _style, difficulty: _difficulty, seed: _customSeed),
    ),
  ));

  void _launchInfinite() => Navigator.push(context, MaterialPageRoute(
    builder: (_) => GameScreen(
      selectedCharacterClass: widget.selectedCharacterClass,
      gameMode: widget.gameMode,
      procedural: false,
      useInfiniteWorld: true,
      mapConfig: MapGeneratorConfig(
          style: _style, difficulty: _difficulty, seed: _customSeed),
    ),
  ));

  void _launchPremade(String mapName) => Navigator.push(context, MaterialPageRoute(
    builder: (_) => GameScreen(
      selectedCharacterClass: widget.selectedCharacterClass,
      mapName: mapName,
      gameMode: widget.gameMode,
    ),
  ));

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
      case _MapMode.procedural: return _buildProcedural();
      case _MapMode.premade:    return _buildPremade();
      case _MapMode.infinite:   return _buildInfinite();
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
          _DifficultyLights(
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

                // Style grid — 6 tiles, fixed height
                SizedBox(
                  height: 84,
                  child: GridView.count(
                    crossAxisCount: _kStyles,
                    crossAxisSpacing: 8,
                    physics: const NeverScrollableScrollPhysics(),
                    children: List.generate(_styles.length, (i) {
                      return GamepadMenuItem(
                        focused: isFocused(i),
                        onTap: () => setState(() => _style = _styles[i]),
                        borderRadius: BorderRadius.circular(10),
                        child: _StyleTile(style: _styles[i], selected: _style == _styles[i]),
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

                // Launch buttons row
                Row(
                  children: [
                    Expanded(
                      child: GamepadMenuItem(
                        focused: isFocused(_kIdxGen),
                        onTap: _launchProcedural,
                        borderRadius: BorderRadius.circular(10),
                        child: _LaunchBtn(
                          label: context.translate('generate_play'),
                          color: Colors.green,
                          icon: Icons.play_arrow,
                          onTap: _launchProcedural,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GamepadMenuItem(
                        focused: isFocused(_kIdxInf),
                        onTap: _launchInfinite,
                        borderRadius: BorderRadius.circular(10),
                        child: _LaunchBtn(
                          label: context.translate('infinite_play'),
                          color: Colors.deepOrange,
                          icon: Icons.all_inclusive,
                          onTap: _launchInfinite,
                        ),
                      ),
                    ),
                  ],
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
            onTap: () => _launchPremade(_levels[i]),
            borderRadius: BorderRadius.circular(15),
            child: _LevelCard(
              mapName: _levels[i],
              levelNum: i + 1,
              label: context.translate('level'),
              onTap: () => _launchPremade(_levels[i]),
            ),
          );
        }),
      ),
    );
  }

  // ── INFINITE ─────────────────────────────────────────────────────────────────
  Widget _buildInfinite() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: GamepadMenuItem(
            focused: isFocused(0),
            onTap: _launchInfinite,
            borderRadius: BorderRadius.circular(20),
            child: GestureDetector(
              onTap: _launchInfinite,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.deepOrange[700]!, Colors.deepOrange[900]!],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white30, width: 2),
                  boxShadow: [
                    BoxShadow(color: Colors.deepOrange.withOpacity(0.3), blurRadius: 24),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.all_inclusive, size: 56, color: Colors.white),
                    const SizedBox(height: 16),
                    Text(context.translate('infinite_map'),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 26,
                            fontWeight: FontWeight.bold, letterSpacing: 2)),
                    const SizedBox(height: 8),
                    const Text('Endless procedural world — run as far as you can',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _launchInfinite,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('LAUNCH',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.deepOrange,
                        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Difficulty Crosslight widget ───────────────────────────────────────────────
class _DifficultyLights extends StatelessWidget {
  final List<MapDifficulty> diffs;
  final MapDifficulty selected;
  final Map<MapDifficulty, Color> colors;
  final int focusStart;
  final bool Function(int) isFocused;
  final void Function(MapDifficulty) onSelect;

  const _DifficultyLights({
    required this.diffs,
    required this.selected,
    required this.colors,
    required this.focusStart,
    required this.isFocused,
    required this.onSelect,
  });

  static const _labels = {
    MapDifficulty.easy:   'EASY',
    MapDifficulty.medium: 'MED',
    MapDifficulty.hard:   'HARD',
    MapDifficulty.expert: 'EXP',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text('DIFF',
              style: TextStyle(
                  color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)),
          const SizedBox(height: 6),
          // Vertical pole line behind lights
          ...List.generate(diffs.length, (i) {
            final diff   = diffs[i];
            final isOn   = selected == diff;
            final color  = colors[diff]!;
            final fi     = focusStart + i;
            final hasFocus = isFocused(fi);

            return Expanded(
              child: GestureDetector(
                onTap: () => onSelect(diff),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      // Radio dot
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOn ? color : Colors.transparent,
                          border: Border.all(
                            color: hasFocus
                                ? const Color(0xFFFFD700)
                                : (isOn ? color : Colors.white30),
                            width: hasFocus ? 2.5 : (isOn ? 2 : 1.5),
                          ),
                          boxShadow: isOn
                              ? [BoxShadow(color: color.withOpacity(0.7), blurRadius: 10, spreadRadius: 2)]
                              : null,
                        ),
                        child: isOn
                            ? Center(
                          child: Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        )
                            : null,
                      ),

                      const SizedBox(width: 5),

                      // Label
                      Text(
                        _labels[diff]!,
                        style: TextStyle(
                          color: isOn ? color : Colors.white38,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Style tile ────────────────────────────────────────────────────────────────
class _StyleTile extends StatelessWidget {
  final MapStyle style;
  final bool selected;

  const _StyleTile({required this.style, required this.selected});

  static (IconData icon, String name) _info(MapStyle style) {
    switch (style) {
      case MapStyle.arena:      return (Icons.sports_mma,  'Arena');
      case MapStyle.platformer: return (Icons.stairs,       'Platform');
      case MapStyle.dungeon:    return (Icons.domain,       'Dungeon');
      case MapStyle.towers:     return (Icons.apartment,    'Towers');
      case MapStyle.chaos:      return (Icons.shuffle,      'Chaos');
      case MapStyle.balanced:   return (Icons.balance,      'Balanced');
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info(style);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: selected
              ? [Colors.blue[700]!, Colors.blue[900]!]
              : [Colors.grey[800]!, Colors.grey[900]!],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: selected ? Colors.blue : Colors.grey[600]!,
            width: selected ? 2 : 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(info.$1, color: Colors.white, size: 20),
          const SizedBox(height: 3),
          Text(info.$2,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ── Launch button ─────────────────────────────────────────────────────────────
class _LaunchBtn extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _LaunchBtn({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 5),
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ── Level card ────────────────────────────────────────────────────────────────
class _LevelCard extends StatelessWidget {
  final String mapName;
  final int levelNum;
  final String label;
  final VoidCallback onTap;

  const _LevelCard({
    required this.mapName,
    required this.levelNum,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue[700]!, Colors.blue[900]!],
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white30, width: 2),
          boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 10)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map, size: 36, color: Colors.white),
            const SizedBox(height: 4),
            Text('$label $levelNum',
                style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(mapName,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}