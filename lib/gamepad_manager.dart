import 'dart:async' as dart_async;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamepads/gamepads.dart';

class GamepadManager extends Component with KeyboardHandler {
  static final GamepadManager _instance = GamepadManager._internal();
  factory GamepadManager() => _instance;

  GamepadManager._internal() {
    // Add a global listener so we can detect the gamepad even before the game starts
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
  }

  Vector2 joystickDelta = Vector2.zero();
  bool isAttackPressed = false;

  final ValueNotifier<bool> connected = ValueNotifier<bool>(false);
  bool get isGamepadConnected => connected.value;

  final Set<LogicalKeyboardKey> _pressedKeys = {};
  dart_async.Timer? _pollingTimer;

  @override
  void onMount() {
    super.onMount();
    _startListening();
  }

  @override
  void onRemove() {
    _pollingTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    super.onRemove();
  }

  bool _handleGlobalKeyEvent(KeyEvent event) {
    // Update our internal state whenever a key is pressed globally
    onKeyEvent(event, HardwareKeyboard.instance.logicalKeysPressed);
    return false; // Don't consume the event, let others use it
  }

  void _startListening() {
    checkConnection();
    _pollingTimer = dart_async.Timer.periodic(const Duration(seconds: 2), (timer) {
      checkConnection();
    });
  }

  Future<void> checkConnection() async {
    try {
      // Try to list physical devices
      final list = await Gamepads.list();
      if (list.isNotEmpty) {
        connected.value = true;
        return;
      }
    } catch (e) {
      debugPrint('Gamepad hardware list failed, relying on input detection: $e');
    }

    // Fallback: If listing fails or is empty, check if any gamepad-like keys are currently held
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    if (_isGamepadSignal(keys)) {
      connected.value = true;
    }
  }

  bool _isGamepadSignal(Iterable<LogicalKeyboardKey> keys) {
    return keys.any((k) {
      final name = k.debugName?.toLowerCase() ?? '';
      return name.contains('game button') ||
          name.contains('joystick') ||
          k == LogicalKeyboardKey.gameButtonA ||
          k == LogicalKeyboardKey.gameButtonB;
    });
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _pressedKeys.clear();
    _pressedKeys.addAll(keysPressed);
    _updateGamepadState();
    return true;
  }

  void _updateGamepadState() {
    joystickDelta = Vector2.zero();

    // Movement mapping
    bool left = _pressedKeys.contains(LogicalKeyboardKey.arrowLeft) || _pressedKeys.contains(LogicalKeyboardKey.keyA);
    bool right = _pressedKeys.contains(LogicalKeyboardKey.arrowRight) || _pressedKeys.contains(LogicalKeyboardKey.keyD);
    bool up = _pressedKeys.contains(LogicalKeyboardKey.arrowUp) || _pressedKeys.contains(LogicalKeyboardKey.keyW);
    bool down = _pressedKeys.contains(LogicalKeyboardKey.arrowDown) || _pressedKeys.contains(LogicalKeyboardKey.keyS);

    if (left) joystickDelta.x -= 1;
    if (right) joystickDelta.x += 1;
    if (up) joystickDelta.y -= 1;
    if (down) joystickDelta.y += 1;

    if (joystickDelta.length > 0) joystickDelta.normalize();

    // Attack mapping
    isAttackPressed = _pressedKeys.any((k) =>
    k == LogicalKeyboardKey.gameButtonA ||
        k == LogicalKeyboardKey.gameButtonX ||
        k == LogicalKeyboardKey.gameButtonRight1 ||
        k == LogicalKeyboardKey.space
    );

    // Auto-detect connection on any gamepad-like input
    if (!connected.value && _isGamepadSignal(_pressedKeys)) {
      connected.value = true;
    }
  }
}