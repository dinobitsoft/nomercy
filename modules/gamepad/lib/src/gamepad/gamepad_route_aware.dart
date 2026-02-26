import 'dart:async';
import 'package:flutter/material.dart';
import 'gamepad_nav_service.dart';

/// Singleton route observer — register in MaterialApp.navigatorObservers.
final gamepadRouteObserver = RouteObserver<ModalRoute<void>>();

/// Mixin for StatefulWidget screens that need reliable gamepad input.
///
/// Replaces the broken `ModalRoute.of(context)?.isCurrent` pattern.
/// Uses Flutter's RouteObserver lifecycle to subscribe/unsubscribe
/// the gamepad stream exactly when the route is visible and active.
///
/// Usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen>
///     with GamepadRouteAware<MyScreen> {
///
///   @override
///   void onGamepadEvent(GamepadNavEvent event) { … }
/// }
/// ```
mixin GamepadRouteAware<T extends StatefulWidget> on State<T>
implements RouteAware {
  StreamSubscription<GamepadNavEvent>? _gamepadSub;

  // ── RouteAware lifecycle ──────────────────────────────────────────────────

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
    _gamepadSub?.cancel();
    super.dispose();
  }

  /// Called when this route is pushed for the first time.
  @override
  void didPush() => _subscribe();

  /// Called when a route above this one is popped, revealing this route.
  @override
  void didPopNext() => _subscribe();

  /// Called when this route is pushed over (another route appears on top).
  @override
  void didPushNext() => _unsubscribe();

  /// Called when this route is popped off the navigator.
  @override
  void didPop() => _unsubscribe();

  // ── Stream management ─────────────────────────────────────────────────────

  void _subscribe() {
    _gamepadSub?.cancel();
    _gamepadSub = GamepadNavService().events.listen((event) {
      if (mounted) onGamepadEvent(event);
    });
  }

  void _unsubscribe() {
    _gamepadSub?.cancel();
    _gamepadSub = null;
  }

  /// Override to handle gamepad events. Only called when this route is active.
  void onGamepadEvent(GamepadNavEvent event);
}