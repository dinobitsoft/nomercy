import 'package:engine/engine.dart';
import 'package:flutter/material.dart';
import 'package:gamepad/gamepad.dart';

import 'game_screen_3d.dart';
import 'map_selection_screen.dart';

class ModeSelectionScreen extends StatefulWidget {
  final String selectedCharacterClass;

  const ModeSelectionScreen({
    super.key,
    required this.selectedCharacterClass,
  });

  @override
  State<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen>
    with GamepadRouteAware<ModeSelectionScreen> {

  static const _modes = [
    (GameMode.survival,  Icons.shield,        'SURVIVAL',   'Endless waves\nof enemies',          Colors.orange),
    (GameMode.campaign,  Icons.book,           'CAMPAIGN',   'Story mode with\nboss fights',        Colors.blue),
    (GameMode.bossFight, Icons.dangerous,      'BOSS FIGHT', 'Face a powerful\nboss enemy',         Colors.red),
    (GameMode.training,  Icons.fitness_center, 'TRAINING',   'Practice mode\nPerfect your skills', Colors.green),
  ];

  // Index for the 3D mode button (after the 4 standard modes)
  static const int _idx3D = 4;

  int _focus = 0;
  static const int _cols = 2;
  static const int _rows = 3; // 4 modes + 1 special 3D button

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
        if (_focus == _idx3D) {
          _launch3D();
        } else {
          _navigate(_modes[_focus].$1);
        }
      case GamepadNavEvent.back:
        Navigator.maybePop(context);
      default:
        break;
    }
  }

  void _moveFocus(int dc, int dr) {
    final total = _modes.length + 1; // 4 modes + 3D button
    if (_focus == _idx3D) {
      // On 3D button (spans full width) — up/down only
      if (dr == -1) {
        setState(() => _focus = _idx3D - _cols); // go to last row of grid
      } else if (dr == 1) {
        setState(() => _focus = 0);
      }
      return;
    }
    final col = (_focus % _cols + dc + _cols) % _cols;
    final row = _focus ~/ _cols + dr;
    if (row < 0) {
      setState(() => _focus = _idx3D); // wrap up to 3D button
    } else if (row >= _modes.length ~/ _cols) {
      setState(() => _focus = _idx3D); // wrap down to 3D button
    } else {
      setState(() => _focus = (row * _cols + col).clamp(0, _modes.length - 1));
    }
  }

  void _navigate(GameMode mode) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => MapSelectionScreen(
        selectedCharacterClass: widget.selectedCharacterClass,
        gameMode: mode,
      ),
    ));
  }

  void _launch3D() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => GameScreen3D(
        characterClass: widget.selectedCharacterClass,
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
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          size: 28, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 20),
                    Text(
                      context.translate('select_mode'),
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: _cols,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 10),
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 15,
                        childAspectRatio: 2.8,
                        physics: const NeverScrollableScrollPhysics(),
                        children: List.generate(_modes.length, (i) {
                          final m = _modes[i];
                          return GamepadMenuItem(
                            focused: _focus == i,
                            onTap: () => _navigate(m.$1),
                            borderRadius: BorderRadius.circular(15),
                            child: _buildModeCard(
                                i, m.$1, m.$3, m.$4, m.$2, m.$5),
                          );
                        }),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: GamepadMenuItem(
                        focused: _focus == _idx3D,
                        onTap: _launch3D,
                        borderRadius: BorderRadius.circular(15),
                        child: _build3DCard(),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),

              const GamepadHintBar(confirmLabel: 'Select Mode'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _build3DCard() {
    final focused = _focus == _idx3D;
    const color = Colors.deepPurple;
    return GestureDetector(
      onTap: _launch3D,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              focused ? color.withOpacity(0.9) : color.withOpacity(0.8),
              focused ? Colors.indigo.withOpacity(0.8) : Colors.indigo.withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white30, width: 2),
          boxShadow: [
            BoxShadow(
              color: focused ? color.withOpacity(0.5) : color.withOpacity(0.3),
              blurRadius: focused ? 18 : 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.view_in_ar, size: 28, color: Colors.white),
            SizedBox(width: 12),
            Text('3D MODE',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2)),
            SizedBox(width: 12),
            Text('Isometric infinite world',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard(int index, GameMode mode, String title, String desc,
      IconData icon, Color color) {
    final focused = _focus == index;
    return GestureDetector(
      onTap: () {
        setState(() => _focus = index);
        _navigate(mode);
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              focused
                  ? color.withOpacity(0.9)
                  : color.withOpacity(0.8),
              focused
                  ? color.withOpacity(0.7)
                  : color.withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white30, width: 2),
          boxShadow: [
            BoxShadow(
              color: focused
                  ? color.withOpacity(0.5)
                  : color.withOpacity(0.3),
              blurRadius: focused ? 18 : 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 15),
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(desc,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}