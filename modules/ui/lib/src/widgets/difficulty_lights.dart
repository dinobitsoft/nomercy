import 'package:engine/engine.dart';
import 'package:flutter/material.dart';

// ── Difficulty Crosslight widget ───────────────────────────────────────────────
class DifficultyLights extends StatelessWidget {
  final List<MapDifficulty> diffs;
  final MapDifficulty selected;
  final Map<MapDifficulty, Color> colors;
  final int focusStart;
  final bool Function(int) isFocused;
  final void Function(MapDifficulty) onSelect;

  const DifficultyLights({super.key,
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