import 'package:flutter/material.dart';

class GamepadItem {
  final VoidCallback onSelect;
  final int column; // For multi-column grids (0-based)
  final int row;    // For multi-column grids (0-based)

  const GamepadItem({
    required this.onSelect,
    this.column = 0,
    this.row = 0,
  });
}