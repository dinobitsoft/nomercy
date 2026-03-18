import 'dart:async';
import 'package:flutter/material.dart';
import 'gamepad_nav_service.dart';

/// Singleton route observer — must be registered in MaterialApp.navigatorObservers.
final gamepadRouteObserver = RouteObserver<ModalRoute<void>>();

/// Mixin for [StatefulWidget] screens that need reliable gamepad navigation.
///
/// ## Why this exists
/// [RouteObserver] never fires [didPush] for the **initial/home route** because
/// that route is not pushed onto an existing navigator stack — it is the stack.
/// The fix: subscribe to [GamepadNavService.events] eagerly inside
/// [didChangeDependencies], where the [ModalRoute] is already available.
///
/// For all subsequently pushed routes [didPush] is also called and re-subscribes
/// (cancel + recreate) to ensure a fresh subscription after any transition.
/// [didPushNext] / [didPop] pause and resume the subscription correctly.
///
/// ## Usage
/// ```dart
/// class _MyScreenState extends State<MyScreen>
///     with GamepadRouteAware<MyScreen> {
///   @override
///   void onGamepadEvent(GamepadNavEvent event) {
///     // handle event — only called when this route is the active top route
///   }
/// }
/// ```
mixin GamepadRouteAware<T extends StatefulWidget> on State<T>
implements RouteAware {

  StreamSubscription<GamepadNavEvent>? _gamepadSub;
  bool _observerRegistered = false;

  // ── Flutter lifecycle ────────────────────────────────────────────────────────

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && !_observerRegistered) {
      _observerRegistered = true;
      gamepadRouteObserver.subscribe(this, route);
      // Subscribe immediately — [RouteObserver] never fires [didPush] for the
      // home route, so this call ensures it receives events from the start.
      _subscribe();
    }
  }

  @override
  void dispose() {
    gamepadRouteObserver.unsubscribe(this);
    _gamepadSub?.cancel();
    super.dispose();
  }

  // ── RouteAware callbacks ─────────────────────────────────────────────────────

  /// Route is now the top-most visible route (pushed for the first time).
  @override
  void didPush() => _subscribe();

  /// A route above this one was popped, making this route visible again.
  @override
  void didPopNext() => _subscribe();

  /// A new route was pushed on top of this one — pause input.
  @override
  void didPushNext() => _unsubscribe();

  /// This route was popped off the navigator.
  @override
  void didPop() => _unsubscribe();

  // ── Stream management ────────────────────────────────────────────────────────

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

  // ── Override point ───────────────────────────────────────────────────────────

  /// Called with each [GamepadNavEvent] while this route is the active top route.
  void onGamepadEvent(GamepadNavEvent event);
}