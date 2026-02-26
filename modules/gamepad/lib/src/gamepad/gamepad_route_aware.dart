import 'dart:async';
import 'package:flutter/material.dart';
import 'gamepad_nav_service.dart';

/// Singleton route observer — register in MaterialApp.navigatorObservers.
final gamepadRouteObserver = RouteObserver<ModalRoute<void>>();

/// Mixin for [StatefulWidget] screens needing reliable gamepad input.
///
/// Key fix: subscribes on [didChangeDependencies] so the **home/initial route**
/// (which never receives [didPush] from [RouteObserver]) also gets events.
/// [didPushNext] / [didPop] unsubscribe when the route is not the top-most.
///
/// Usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen>
///     with GamepadRouteAware<MyScreen> {
///   @override
///   void onGamepadEvent(GamepadNavEvent event) { … }
/// }
/// ```
mixin GamepadRouteAware<T extends StatefulWidget> on State<T>
implements RouteAware {
  StreamSubscription<GamepadNavEvent>? _gamepadSub;
  bool _subscribedToObserver = false;

  // ── RouteAware lifecycle ──────────────────────────────────────────────────

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && !_subscribedToObserver) {
      _subscribedToObserver = true;
      gamepadRouteObserver.subscribe(this, route);
      // Subscribe immediately — handles the home route where didPush is never
      // called by RouteObserver (the initial route is not "pushed" onto an
      // existing navigator, so the observer never fires didPush for it).
      _subscribe();
    }
  }

  @override
  void dispose() {
    gamepadRouteObserver.unsubscribe(this);
    _gamepadSub?.cancel();
    super.dispose();
  }

  /// Called when this route is pushed for the first time (non-home routes).
  @override
  void didPush() => _subscribe();

  /// Called when a route above this one is popped, revealing this route.
  @override
  void didPopNext() => _subscribe();

  /// Called when this route is covered by a new route pushed on top.
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

  /// Override to handle gamepad navigation events.
  /// Only invoked while this route is the active top-most route.
  void onGamepadEvent(GamepadNavEvent event);
}