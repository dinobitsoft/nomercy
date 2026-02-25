import 'package:flutter/material.dart';
// ─── MenuItem descriptor ──────────────────────────────────────────────────────
class GamepadItem {
  final VoidCallback onSelect;
  final int column;
  final int row;

  GamepadItem({
    required this.onSelect,
    this.column = 0,
    this.row = 0,
  });
}