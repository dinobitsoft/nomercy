import 'dart:async' as dart_async;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamepads/gamepads.dart';

class GamepadManager extends Component with KeyboardHandler {
  static final GamepadManager _instance = GamepadManager._internal();
  factory GamepadManager() => _instance;

  GamepadManager._internal() {
    // Global listener ensures we catch events even if component focus is lost
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
    _startGamepadListener();
  }

  // Physical gamepad states
  Vector2 _physicalJoystick = Vector2.zero();
  bool _physicalAttack = false;
  bool _physicalJump = false;
  bool _physicalBlock = false;
  bool _physicalDodge = false;

  // Keyboard (simulated gamepad) states
  Vector2 _keyboardJoystick = Vector2.zero();
  bool _keyboardAttack = false;
  bool _keyboardJump = false;
  bool _keyboardBlock = false;
  bool _keyboardDodge = false;

  // Combined states
  Vector2 get joystickDelta {
    final combined = _physicalJoystick + _keyboardJoystick;
    if (combined.length > 1.0) combined.normalize();
    return combined;
  }

  bool get isAttackPressed => _physicalAttack || _keyboardAttack;
  bool get isJumpPressed => _physicalJump || _keyboardJump;
  bool get isBlockPressed => _physicalBlock || _keyboardBlock;
  bool get isDodgePressed => _physicalDodge || _keyboardDodge;

  final ValueNotifier<bool> connected = ValueNotifier<bool>(false);
  bool get isGamepadConnected => connected.value;

  dart_async.Timer? _pollingTimer;
  dart_async.StreamSubscription<GamepadEvent>? _gamepadSubscription;

  // Track last states for edge detection (JustPressed)
  bool _lastAttack = false;
  bool _lastJump = false;
  bool _lastBlock = false;
  bool _lastDodge = false;

  @override
  void onMount() {
    super.onMount();
    _startListening();
  }

  @override
  void onRemove() {
    _pollingTimer?.cancel();
    _gamepadSubscription?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    super.onRemove();
  }

  bool _handleGlobalKeyEvent(KeyEvent event) {
    // This ensures we always update based on what Flutter sees as "pressed"
    _updateKeyboardStates(HardwareKeyboard.instance.logicalKeysPressed);
    return false; // Do not consume, allow standard Flutter/Flame dispatch
  }

  void _startListening() {
    checkConnection();
    _pollingTimer = dart_async.Timer.periodic(const Duration(seconds: 2), (timer) {
      checkConnection();
    });
  }

  void _startGamepadListener() {
    _gamepadSubscription = Gamepads.events.listen((event) {
      if (!connected.value) {
        connected.value = true;
      }
      _handleGamepadEvent(event);
    });
  }

  void _handleGamepadEvent(GamepadEvent event) {
    // Handle physical analog sticks
    if (event.type == KeyType.analog) {
      if (event.key == 'left_stick_x') {
        _physicalJoystick.x = event.value;
      } else if (event.key == 'left_stick_y') {
        _physicalJoystick.y = event.value;
      }
    }

    // Handle physical buttons
    if (event.type == KeyType.button) {
      final isPressed = event.value > 0.5;
      
      switch (event.key) {
        case 'button_a':
          _physicalJump = isPressed;
          break;
        case 'button_b':
          _physicalDodge = isPressed;
          break;
        case 'button_x':
          _physicalAttack = isPressed;
          break;
        case 'button_y':
          _physicalBlock = isPressed;
          break;
      }
    }
  }

  Future<void> checkConnection() async {
    try {
      final list = await Gamepads.list();
      if (list.isNotEmpty && !connected.value) {
        connected.value = true;
      }
    } catch (e) {
      // Hardware listing is optional, we mostly rely on event stream
    }
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _updateKeyboardStates(keysPressed);
    return true;
  }

  void _updateKeyboardStates(Set<LogicalKeyboardKey> keys) {
    // Reset keyboard states and recalculate from currently pressed keys
    _keyboardJoystick = Vector2.zero();
    
    bool left = keys.contains(LogicalKeyboardKey.arrowLeft) || keys.contains(LogicalKeyboardKey.keyA);
    bool right = keys.contains(LogicalKeyboardKey.arrowRight) || keys.contains(LogicalKeyboardKey.keyD);
    bool up = keys.contains(LogicalKeyboardKey.arrowUp) || keys.contains(LogicalKeyboardKey.keyW);
    bool down = keys.contains(LogicalKeyboardKey.arrowDown) || keys.contains(LogicalKeyboardKey.keyS);

    if (left) _keyboardJoystick.x -= 1;
    if (right) _keyboardJoystick.x += 1;
    if (up) _keyboardJoystick.y -= 1;
    if (down) _keyboardJoystick.y += 1;

    if (_keyboardJoystick.length > 0) _keyboardJoystick.normalize();

    _keyboardAttack = keys.any((k) =>
      k == LogicalKeyboardKey.gameButtonX || k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.keyF
    );

    _keyboardJump = keys.any((k) =>
      k == LogicalKeyboardKey.gameButtonA || k == LogicalKeyboardKey.keyJ || k == LogicalKeyboardKey.space
    );

    _keyboardDodge = keys.any((k) =>
      k == LogicalKeyboardKey.gameButtonB || k == LogicalKeyboardKey.keyK || k == LogicalKeyboardKey.keyL
    );

    _keyboardBlock = keys.any((k) =>
      k == LogicalKeyboardKey.gameButtonY || k == LogicalKeyboardKey.shiftLeft || k == LogicalKeyboardKey.shiftRight || k == LogicalKeyboardKey.keyI
    );

    // Auto-connect if we see gamepad-like hardware keys
    if (!connected.value && _isGamepadSignal(keys)) {
      connected.value = true;
    }
  }

  bool _isGamepadSignal(Iterable<LogicalKeyboardKey> keys) {
    return keys.any((k) {
      final name = k.debugName?.toLowerCase() ?? '';
      return name.contains('game button') || name.contains('joystick');
    });
  }

  // Edge detection for one-time triggers
  bool isAttackJustPressed() {
    final pressed = isAttackPressed && !_lastAttack;
    _lastAttack = isAttackPressed;
    return pressed;
  }

  bool isJumpJustPressed() {
    final pressed = isJumpPressed && !_lastJump;
    _lastJump = isJumpPressed;
    return pressed;
  }

  bool isDodgeJustPressed() {
    final pressed = isDodgePressed && !_lastDodge;
    _lastDodge = isDodgePressed;
    return pressed;
  }

  bool isBlockJustPressed() {
    final pressed = isBlockPressed && !_lastBlock;
    _lastBlock = isBlockPressed;
    return pressed;
  }

  Vector2 getJoystickDirection() => joystickDelta;
  bool hasMovementInput() => joystickDelta.length > 0.1;
}
