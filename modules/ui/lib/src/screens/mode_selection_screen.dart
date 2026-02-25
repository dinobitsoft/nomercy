import 'dart:async';
import 'package:engine/engine.dart';
import 'package:flutter/material.dart';
import 'package:gamepad/gamepad.dart';

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

class _ModeSelectionScreenState extends State<ModeSelectionScreen> {

  static const _modes = [
    (GameMode.survival,  Icons.shield,        'SURVIVAL',   'Endless waves\nof enemies',           Colors.orange),
    (GameMode.campaign,  Icons.book,           'CAMPAIGN',   'Story mode with\nboss fights',         Colors.blue),
    (GameMode.bossFight, Icons.dangerous,      'BOSS FIGHT', 'Face a powerful\nboss enemy',          Colors.red),
    (GameMode.training,  Icons.fitness_center, 'TRAINING',   'Practice mode\nPerfect your skills',  Colors.green),
  ];

  // 2-column grid: row=i÷2, col=i%2
  // Focus order: 0(top-left) 1(top-right) 2(bot-left) 3(bot-right)
  int _focus = 0;
  static const int _cols = 2;
  static const int _rows = 2;

  StreamSubscription<GamepadNavEvent>? _navSub;

  @override
  void initState() {
    super.initState();
    _navSub = GamepadNavService().events.listen(_onNav);
  }

  @override
  void dispose() {
    _navSub?.cancel();
    super.dispose();
  }

  void _onNav(GamepadNavEvent event) {
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
        _navigate(_modes[_focus].$1);
      case GamepadNavEvent.back:
        Navigator.maybePop(context);
      default:
        break;
    }
  }

  void _moveFocus(int dc, int dr) {
    final col = (_focus % _cols + dc + _cols) % _cols;
    final row = (_focus ~/ _cols + dr + _rows) % _rows;
    setState(() => _focus = row * _cols + col);
  }

  void _navigate(GameMode mode) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => MapSelectionScreen(
        selectedCharacterClass: widget.selectedCharacterClass,
        gameMode: mode,
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
                      icon: const Icon(Icons.arrow_back, size: 28, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 20),
                    Text(
                      context.translate('select_mode'),
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: GridView.count(
                  crossAxisCount: _cols,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
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
                      child: _buildModeCard(i, m.$1, m.$3, m.$4, m.$2, m.$5),
                    );
                  }),
                ),
              ),

              const GamepadHintBar(confirmLabel: 'Select Mode'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard(int index, GameMode mode, String title, String desc, IconData icon, Color color) {
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
              focused ? color.withOpacity(0.9) : color.withOpacity(0.8),
              focused ? color.withOpacity(0.7) : color.withOpacity(0.6),
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
                          color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(desc,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
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