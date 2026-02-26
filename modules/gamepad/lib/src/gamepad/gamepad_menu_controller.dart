import 'dart:async';
import 'package:flutter/material.dart';
import 'gamepad.dart';

// ─── Controller mixin ─────────────────────────────────────────────────────────
//
// Uses GamepadRouteAware subscription so events are only processed
// when this route is the active top-most route.
//
mixin GamepadMenuController<T extends StatefulWidget> on State<T>
implements RouteAware {
  // RouteObserver subscription via GamepadRouteAware
  StreamSubscription<GamepadNavEvent>? _navSub;
  bool _routeActive = false;

  List<GamepadItem> _items = [];
  int _columns = 1;
  int _focusIndex = 0;

  int get focusIndex => _focusIndex;
  int get itemCount  => _items.length;

  bool get _hasItems => _items.isNotEmpty;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      gamepadRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    gamepadRouteObserver.unsubscribe(this);
    _navSub?.cancel();
    super.dispose();
  }

  // ── RouteAware ──────────────────────────────────────────────────────────────
  @override void didPush()     => _setActive(true);
  @override void didPopNext()  => _setActive(true);
  @override void didPushNext() => _setActive(false);
  @override void didPop()      => _setActive(false);

  void _setActive(bool active) {
    _routeActive = active;
    if (active) {
      _navSub?.cancel();
      _navSub = GamepadNavService().events.listen((event) {
        if (mounted) _onNav(event);
      });
    } else {
      _navSub?.cancel();
      _navSub = null;
    }
  }

  // ── Item registration ───────────────────────────────────────────────────────
  void registerItems(List<GamepadItem> items, {int columns = 1}) {
    _items      = items;
    _columns    = columns.clamp(1, items.isEmpty ? 1 : items.length);
    _focusIndex = 0;
  }

  void _onNav(GamepadNavEvent event) {
    if (!_hasItems) return;
    switch (event) {
      case GamepadNavEvent.confirm: _items[_focusIndex].onSelect(); break;
      case GamepadNavEvent.back:    onBack(); break;
      case GamepadNavEvent.start:   onStart(); break;
      case GamepadNavEvent.up:      _moveFocus(0, -1); break;
      case GamepadNavEvent.down:    _moveFocus(0,  1); break;
      case GamepadNavEvent.left:    _moveFocus(-1, 0); break;
      case GamepadNavEvent.right:   _moveFocus( 1, 0); break;
    }
  }

  void _moveFocus(int dCol, int dRow) {
    if (_columns == 1) {
      final next =
          (_focusIndex + dRow + dCol + _items.length) % _items.length;
      setState(() => _focusIndex = next);
      return;
    }
    final rows   = (_items.length / _columns).ceil();
    final curCol = _focusIndex % _columns;
    final curRow = _focusIndex ~/ _columns;
    int newCol   = (curCol + dCol + _columns) % _columns;
    int newRow   = (curRow + dRow + rows) % rows;
    int next     = newRow * _columns + newCol;
    if (next >= _items.length) next = _items.length - 1;
    setState(() => _focusIndex = next);
  }

  bool isFocused(int index) => index == _focusIndex;

  void onBack()  { if (mounted) Navigator.maybePop(context); }
  void onStart() {}
}