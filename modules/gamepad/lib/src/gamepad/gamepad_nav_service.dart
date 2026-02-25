import 'dart:async';

import 'package:flutter/services.dart';
import 'package:gamepads/gamepads.dart';

enum GamepadNavEvent { up, down, left, right, confirm, back, start }

class GamepadNavService {
  static final GamepadNavService _instance = GamepadNavService._internal();
  factory GamepadNavService() => _instance;
  GamepadNavService._internal() {
    _init();
  }

  final _controller = StreamController<GamepadNavEvent>.broadcast();
  Stream<GamepadNavEvent> get events => _controller.stream;

  Timer? _repeatTimer;

  final Map<GamepadNavEvent, DateTime> _lastFired = {};
  static const _debounce = Duration(milliseconds: 180);
  static const _repeatDelay = Duration(milliseconds: 400);
  static const _repeatInterval = Duration(milliseconds: 150);

  String? _axisXKey;
  String? _axisYKey;
  double _axisX = 0;
  double _axisY = 0;

  bool _sUp = false;
  bool _sDown = false;
  bool _sLeft = false;
  bool _sRight = false;

  bool _hwUp = false;
  bool _hwDown = false;
  bool _hwLeft = false;
  bool _hwRight = false;
  bool _hwConfirm = false;
  bool _hwBack = false;

  bool _prevConfirm = false;
  bool _prevBack = false;

  StreamSubscription<GamepadEvent>? _gpSub;

  void _init() {
    _gpSub = Gamepads.events.listen(_onGamepadEvent, onError: (_) {});
    HardwareKeyboard.instance.addHandler(_onHwKey);
  }

  void dispose() {
    _gpSub?.cancel();
    _repeatTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onHwKey);
    _controller.close();
  }

  void _onGamepadEvent(GamepadEvent e) {
    final k = e.key.trim().toLowerCase();
    if (e.type == KeyType.analog) {
      _handleAnalog(k, e.value);
    } else {
      _handleButton(k, e.value > 0.5);
    }
    _evaluateState();
  }

  static const _buttonKeycodes = {
    '96',
    '97',
    '98',
    '99',
    '100',
    '101',
    '102',
    '103',
    '104',
    '105',
    '108',
    '109',
    '19',
    '20',
    '21',
    '22',
  };

  static const _buttonFragments = [
    'button_a',
    'button_b',
    'button_x',
    'button_y',
    'cross',
    'circle',
    'square',
    'triangle',
    'south',
    'east',
    'west',
    'north',
    'shoulder',
    'trigger',
    'select',
    'start',
    'dpad',
    'hat',
    'thumbl',
    'thumbr',
  ];

  bool _isButtonKey(String k) {
    if (_buttonKeycodes.contains(k)) return true;
    for (final f in _buttonFragments) {
      if (k.contains(f)) return true;
    }
    return false;
  }

  void _handleAnalog(String k, double value) {
    if (_isButtonKey(k)) {
      _handleButton(k, value > 0.5);
      return;
    }

    if (_axisXKey == null) {
      _axisXKey = k;
      return;
    } else if (_axisYKey == null && k != _axisXKey) {
      _axisYKey = k;
      return;
    }

    if (k == _axisXKey) {
      _axisX = _dz(value);
      return;
    }

    if (k == _axisYKey) {
      _axisY = -_dz(value);
      return;
    }

    if (k.contains('hat x') || k == 'axis 6') {
      if (value < -0.5) {
        _sLeft = true;
        _sRight = false;
      } else if (value > 0.5) {
        _sRight = true;
        _sLeft = false;
      } else {
        _sLeft = false;
        _sRight = false;
      }
    }

    if (k.contains('hat y') || k == 'axis 7') {
      if (value < -0.5) {
        _sUp = true;
        _sDown = false;
      } else if (value > 0.5) {
        _sDown = true;
        _sUp = false;
      } else {
        _sUp = false;
        _sDown = false;
      }
    }
  }

  bool _match(String k, List<String> exact, List<String> frags) {
    if (exact.contains(k)) return true;
    for (final f in frags) {
      if (k.contains(f)) return true;
    }
    return false;
  }

  void _emitPress(GamepadNavEvent event, bool pressed) {
    if (!pressed) return;
    _fire(event);
  }

  void _handleButton(String k, bool pressed) {
    if (_match(k, ['21', 'dpad_left', 'keycode_dpad_left'], ['dpad left'])) {
      _sLeft = pressed;
      return;
    }

    if (_match(k, ['22', 'dpad_right', 'keycode_dpad_right'], ['dpad right'])) {
      _sRight = pressed;
      return;
    }

    if (_match(k, ['19', 'dpad_up', 'keycode_dpad_up'], ['dpad up'])) {
      _sUp = pressed;
      return;
    }

    if (_match(k, ['20', 'dpad_down', 'keycode_dpad_down'], ['dpad down'])) {
      _sDown = pressed;
      return;
    }

    if (_match(k, ['96', '0', '99', '2'], [
      'button_a',
      'cross',
      'south',
      'button_x',
      'square',
      'west',
    ])) {
      _emitPress(GamepadNavEvent.confirm, pressed);
      return;
    }

    if (_match(k, ['97', '1'], ['button_b', 'circle', 'east'])) {
      _emitPress(GamepadNavEvent.back, pressed);
      return;
    }

    if (_match(k, ['108'], ['start', 'keycode_button_start'])) {
      _emitPress(GamepadNavEvent.start, pressed);
      return;
    }
  }

  bool _onHwKey(KeyEvent e) {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    _hwUp =
        pressed.contains(LogicalKeyboardKey.arrowUp) ||
        pressed.contains(LogicalKeyboardKey.keyW);
    _hwDown =
        pressed.contains(LogicalKeyboardKey.arrowDown) ||
        pressed.contains(LogicalKeyboardKey.keyS);
    _hwLeft =
        pressed.contains(LogicalKeyboardKey.arrowLeft) ||
        pressed.contains(LogicalKeyboardKey.keyA);
    _hwRight =
        pressed.contains(LogicalKeyboardKey.arrowRight) ||
        pressed.contains(LogicalKeyboardKey.keyD);
    _hwConfirm =
        pressed.contains(LogicalKeyboardKey.enter) ||
        pressed.contains(LogicalKeyboardKey.space) ||
        pressed.contains(LogicalKeyboardKey.gameButtonA);
    _hwBack =
        pressed.contains(LogicalKeyboardKey.escape) ||
        pressed.contains(LogicalKeyboardKey.gameButtonB);

    _evaluateState();
    return false;
  }

  GamepadNavEvent? _currentHeld;

  void _evaluateState() {
    final confirm = _hwConfirm;
    final back = _hwBack;
    if (confirm && !_prevConfirm) _fire(GamepadNavEvent.confirm);
    if (back && !_prevBack) _fire(GamepadNavEvent.back);
    _prevConfirm = confirm;
    _prevBack = back;
    final up = _sUp || _hwUp || _axisY < -0.5;
    final down = _sDown || _hwDown || _axisY > 0.5;
    final left = _sLeft || _hwLeft || _axisX < -0.5;
    final right = _sRight || _hwRight || _axisX > 0.5;

    GamepadNavEvent? held;
    if (up) {
      held = GamepadNavEvent.up;
    } else if (down) {
      held = GamepadNavEvent.down;
    } else if (left) {
      held = GamepadNavEvent.left;
    } else if (right) {
      held = GamepadNavEvent.right;
    }

    if (held == _currentHeld) return;

    _currentHeld = held;
    _repeatTimer?.cancel();
    _repeatTimer = null;

    if (held == null) return;

    _fire(held);

    _repeatTimer = Timer(_repeatDelay, () {
      _repeatTimer = Timer.periodic(_repeatInterval, (_) {
        if (_currentHeld == held) _fire(held!);
      });
    });
  }

  void _fire(GamepadNavEvent event) {
    final now = DateTime.now();
    final last = _lastFired[event];
    if (last != null && now.difference(last) < _debounce) return;
    _lastFired[event] = now;
    _controller.add(event);
  }

  double _dz(double v, {double t = 0.12}) => v.abs() < t ? 0.0 : v;
}
