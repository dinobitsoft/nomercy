import 'package:engine/engine.dart';
import 'package:flutter/material.dart';

// ── Style tile ────────────────────────────────────────────────────────────────
class StyleTile extends StatelessWidget {
  final MapStyle style;
  final bool selected;

  const StyleTile({super.key, required this.style, required this.selected});

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
          Icon(info.$1, size: 24, color: Colors.white),
          const SizedBox(height: 5),
          Text(
            context.translate(info.$2.toString().toLowerCase()),
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
            context.translate('${info.$2.toString().toLowerCase()}_desc'),
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
    );
  }
}