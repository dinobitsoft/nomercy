import 'dart:async';
import 'package:flutter/material.dart';
import 'gamepad_item.dart';
import 'gamepad_nav_service.dart';

// ─── Controller mixin ─────────────────────────────────────────────────────────
/// Mix into a [State<T>] to get gamepad focus management.
///
/// Usage:
///   1. Add `with GamepadMenuController` to your State class.
///   2. Override `buildItems()` to return your menu items list.
///   3. Call `registerItems(items, columns: N)` from `initState` / after
///      items change.
///   4. Wrap each menu item with `GamepadMenuItem(index: i, controller: this, child: ...)`.
///   5. Override `onBack()` if you want custom back behaviour.
mixin GamepadMenuController<T extends StatefulWidget> on State<T> {
  late StreamSubscription<GamepadNavEvent> _navSub;

  List<GamepadItem> _items = [];
  int _columns = 1;
  int _focusIndex = 0;

  int get focusIndex => _focusIndex;
  int get itemCount  => _items.length;

  bool get _hasItems => _items.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _navSub = GamepadNavService().events.listen(_onNav);
  }

  @override
  void dispose() {
    _navSub.cancel();
    super.dispose();
  }

  /// Call this whenever the item list changes.
  void registerItems(List<GamepadItem> items, {int columns = 1}) {
    _items   = items;
    _columns = columns.clamp(1, items.isEmpty ? 1 : items.length);
    _focusIndex = 0;
  }

  void _onNav(GamepadNavEvent event) {
    if (!_hasItems) return;
    switch (event) {
      case GamepadNavEvent.confirm:
        _items[_focusIndex].onSelect();
        break;
      case GamepadNavEvent.back:
        onBack();
        break;
      case GamepadNavEvent.start:
        onStart();
        break;
      case GamepadNavEvent.up:
        _moveFocus(0, -1);
        break;
      case GamepadNavEvent.down:
        _moveFocus(0, 1);
        break;
      case GamepadNavEvent.left:
        _moveFocus(-1, 0);
        break;
      case GamepadNavEvent.right:
        _moveFocus(1, 0);
        break;
    }
  }

  void _moveFocus(int dCol, int dRow) {
    if (_columns == 1) {
      // Simple linear list
      final next = (_focusIndex + dRow + dCol + _items.length) % _items.length;
      setState(() => _focusIndex = next);
      return;
    }

    // Grid layout
    final rows = (_items.length / _columns).ceil();
    final curCol = _focusIndex % _columns;
    final curRow = _focusIndex ~/ _columns;

    int newCol = (curCol + dCol + _columns) % _columns;
    int newRow = (curRow + dRow + rows) % rows;

    int next = newRow * _columns + newCol;
    // Clamp to actual item count (last row may be partial)
    if (next >= _items.length) next = _items.length - 1;
    setState(() => _focusIndex = next);
  }

  bool isFocused(int index) => index == _focusIndex;

  /// Override to handle B / Escape.
  void onBack() {
    if (mounted) Navigator.maybePop(context);
  }

  /// Override to handle Start button.
  void onStart() {}
}
