import 'package:engine/engine.dart';
import 'package:flutter/material.dart';
import 'package:gamepad/gamepad.dart';
import 'package:ui/ui.dart';

import 'game_screen.dart';

enum _MapMode { procedural, premade, infinite }

const int _kStyles  = 6;
const int _kDiffs   = 4;
const int _kIdxPlay = _kStyles + _kDiffs; // 10

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
    with GamepadRouteAware<MapSelectionScreen> {

  _MapMode      _mode       = _MapMode.procedural;
  MapStyle      _style      = MapStyle.balanced;
  MapDifficulty _difficulty = MapDifficulty.medium;
  int?          _customSeed;

  int _focus = 0;

  static final _styles = MapStyle.values;
  static final _diffs  = MapDifficulty.values;
  static const _levels = ['level_1', 'level_2', 'level_3'];

  static const _diffColors = {
    MapDifficulty.easy:   Color(0xFF4CAF50),
    MapDifficulty.medium: Color(0xFFFF9800),
    MapDifficulty.hard:   Color(0xFFF44336),
    MapDifficulty.expert: Color(0xFF9C27B0),
  };

  int get _itemCount => _mode == _MapMode.premade
      ? _levels.length
      : _kStyles + _kDiffs + 1;

  // ── GamepadRouteAware override — only called when this route is active ───
  @override
  void onGamepadEvent(GamepadNavEvent event) {
    switch (event) {
      case GamepadNavEvent.up:
        _moveFocus(0, -1);
      case GamepadNavEvent.down:
        _moveFocus(0, 1);
      case GamepadNavEvent.left:
        _moveFocus(-1, 0);
      case GamepadNavEvent.right:
        _moveFocus(1, 0);
      case GamepadNavEvent.confirm:
        _activate();
      case GamepadNavEvent.back:
        Navigator.maybePop(context);
      default:
        break;
    }
  }

  void _moveFocus(int dc, int dr) {
    if (_mode == _MapMode.premade) {
      final next = (_focus + dc + dr + _levels.length) % _levels.length;
      setState(() => _focus = next);
      return;
    }

    int row, col;
    if (_focus < _kStyles) {
      row = 0; col = _focus;
    } else if (_focus < _kStyles + _kDiffs) {
      row = 1; col = _focus - _kStyles;
    } else {
      row = 2; col = 0;
    }

    row = (row + dr + 3) % 3;
    final maxCol = row == 0 ? _kStyles : row == 1 ? _kDiffs : 1;
    col = (col + dc + maxCol) % maxCol;

    setState(() {
      if (row == 0)      _focus = col;
      else if (row == 1) _focus = _kStyles + col;
      else               _focus = _kStyles + _kDiffs;
    });
  }

  void _activate() {
    if (_mode == _MapMode.premade) {
      _launch(_levels[_focus]);
      return;
    }
    if (_focus < _kStyles) {
      setState(() => _style = _styles[_focus]);
    } else if (_focus < _kStyles + _kDiffs) {
      setState(() => _difficulty = _diffs[_focus - _kStyles]);
    } else {
      _launch();
    }
  }

  bool _isFocused(int index) => _focus == index;

  void _setMode(_MapMode m) {
    setState(() { _mode = m; _focus = 0; });
  }

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
                      icon: const Icon(Icons.arrow_back,
                          size: 26, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 16),
                    Text(context.translate('select_map'),
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ],
                ),
              ),

              // Mode tabs
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 40, vertical: 6),
                child: Row(children: [
                  Expanded(
                      child: _tab(
                          context.translate('procedural_maps'),
                          Icons.auto_awesome,
                          _MapMode.procedural)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _tab(context.translate('premade_maps'),
                          Icons.map, _MapMode.premade)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _tab(
                          context.translate('infinite_map'),
                          Icons.all_inclusive,
                          _MapMode.infinite)),
                ]),
              ),

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
          border: Border.all(
              color: selected ? Colors.blue : Colors.grey[600]!, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_mode) {
      case _MapMode.procedural:
      case _MapMode.infinite:
        return _buildProcedural();
      case _MapMode.premade:
        return _buildPremade();
    }
  }

  Widget _buildProcedural() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DifficultyLights(
            diffs: _diffs,
            selected: _difficulty,
            colors: _diffColors,
            focusStart: _kStyles,
            isFocused: _isFocused,
            onSelect: (d) { setState(() => _difficulty = d); },
          ),

          const SizedBox(width: 20),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.translate('map_style'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),

                SizedBox(
                  height: 80,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: List.generate(_styles.length, (i) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                          child: GamepadMenuItem(
                            focused: _isFocused(i),
                            onTap: () =>
                                setState(() => _style = _styles[i]),
                            borderRadius: BorderRadius.circular(10),
                            child: StyleTile(
                                style: _styles[i],
                                selected: _style == _styles[i]),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                const Spacer(),

                Row(
                  children: [
                    Text(context.translate('custom_seed'),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 90,
                      height: 32,
                      child: TextField(
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: context.translate('random_hint'),
                          hintStyle: TextStyle(
                              color: Colors.grey[500], fontSize: 11),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 0),
                          enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Colors.grey[600]!)),
                          focusedBorder: const OutlineInputBorder(
                              borderSide:
                              BorderSide(color: Colors.blue)),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => _customSeed = int.tryParse(v),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                GamepadMenuItem(
                  focused: _isFocused(_kIdxPlay),
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
            focused: _isFocused(i),
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