import 'package:engine/engine.dart';
import 'package:flutter/material.dart';

// ── Style tile ────────────────────────────────────────────────────────────────
class StyleTile extends StatelessWidget {
  final MapStyle style;
  final bool selected;

  const StyleTile({required this.style, required this.selected});

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
      width: double.infinity,
      height: double.infinity,
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
        crossAxisAlignment: CrossAxisAlignment.center,
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