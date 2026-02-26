import 'dart:async';
import 'package:flutter/services.dart';
import 'package:gamepads/gamepads.dart';
import 'gamepad.dart';

enum GamepadNavEvent { up, down, left, right, confirm, back, start }

class GamepadNavService {
  static final GamepadNavService _instance = GamepadNavService._internal();
  factory GamepadNavService() => _instance;
  GamepadNavService._internal() {
    _init();
  }

  final _controller = StreamController<GamepadNavEvent>.broadcast();
  Stream<GamepadNavEvent> get events => _controller.stream;

  // Repeat-fire timers for held directions
  Timer? _repeatTimer;

  // Debounce per-event to prevent double-fire on connect
  final Map<GamepadNavEvent, DateTime> _lastFired = {};
  static const _debounce = Duration(milliseconds: 180);
  static const _repeatDelay = Duration(milliseconds: 400);
  static const _repeatInterval = Duration(milliseconds: 150);

  // Analog axis state (auto-learned, mirrors GamepadManager logic)
  String? _axisXKey;
  String? _axisYKey;
  String? _axisZKey;
  String? _axisRZKey;
  double _axisX = 0, _axisY = 0, _axisZ = 0, _axisRZ = 0;

  // Button press states (stream-based)
  bool _sUp = false, _sDown = false, _sLeft = false, _sRight = false;
  bool _sConfirm = false, _sBack = false, _sStart = false;

  // Hardware keyboard states
  bool _hwUp = false, _hwDown = false, _hwLeft = false, _hwRight = false;
  bool _hwConfirm = false, _hwBack = false;

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

  // ─── Gamepad stream ──────────────────────────────────────────────────────────
  void _onGamepadEvent(GamepadEvent e) {
    final k = e.key.trim().toLowerCase();
    switch(e.type) {
      case KeyType.analog:
        _handleAnalog(k, e.value);
        break;
      case KeyType.button:
        _handleButton(k, e.value);
        break;
    }
    _evaluateState();
  }

  static const _buttonKeycodes = {'96','97','98','99','100','101','102','103','104','105','108','109','19','20','21','22'};
  static const _buttonFragments = ['button_a','button_b','button_x','button_y','cross','circle','square','triangle','south','east','west','north','shoulder','trigger','select','start','dpad','hat','thumbl','thumbr'];

  bool _isButtonKey(String k) {
    if (_buttonKeycodes.contains(k)) return true;
    for (final f in _buttonFragments) { if (k.contains(f)) return true; }
    return false;
  }

  void _handleAnalog(String k, double value) {

    final GamepadDevice gamepadDevice = GamepadDevice();

    // D-pad
    // if (_match(k, ['21', 'dpad_left',  'keycode_dpad_left'],  ['dpad left']))  {     gamepadDevice.dpadLeft = _sLeft    = pressed; return; }
    // if (_match(k, ['22', 'dpad_right', 'keycode_dpad_right'], ['dpad right'])) { gamepadDevice.dpadRight = _sRight   = pressed; return; }
    // if (_match(k, ['19', 'dpad_up',    'keycode_dpad_up'],    ['dpad up']))    { gamepadDevice.dpadUp = _sUp      = pressed; return; }
    // if (_match(k, ['20', 'dpad_down',  'keycode_dpad_down'],  ['dpad down'])) { gamepadDevice.dpadDown = _sDown    = pressed; return; }

    //Other PS2
    if (_match(k, ['axis_hat_z',  'axis_z', 'axis_rz'], []))  { //axis_hat_y when d-pad down axis_y when joystick down
      if (value < 0) {
        _sLeft = true; return;
      } else if (value > 0) {
        _sRight = true; return;
      } else if (value == 0) {
        _sLeft = false;
        _sRight = false;
      }
    }
    if (_match(k, ['axis_hat_y',  'axis_y', 'axis_ry'], []))  { //axis_hat_y when d-pad down axis_y when joystick down
      if (value < 0) {
        _sDown = true; return;
      } else if (value > 0) {
        _sUp = true; return;
      } else if (value == 0) {
        _sUp = false;
        _sDown = false;
      }
    }

    // if (_isButtonKey(k)) {
    //   _handleButton(k, value > 0.5); return;
    // }
    //
    // if (_axisXKey == null) {
    //   _axisXKey = k; return;
    // }
    // else if (_axisYKey == null && k != _axisXKey) { _axisYKey = k; return; }
    // else if (_axisZKey == null && k != _axisXKey && k != _axisYKey) { _axisZKey = k; return; }
    // else if (_axisRZKey == null && k != _axisYKey) { _axisRZKey = k; return; }
    // else if (_axisRZKey == null && k != _axisYKey) { _axisRZKey = k; return; }
    //
    // if (k == _axisXKey) { _axisX = _dz(value); return; }
    // if (k == _axisYKey) { _axisY = -_dz(value); return; } // PS invert
    // if (k == _axisZKey) { _axisZ = _dz(value); return; }
    // if (k == _axisRZKey) { _axisRZ = _dz(value); return; }

    // Hat / dpad axes
    // if (k.contains('hat x') || k == 'axis 6') {
    //   if (value < -0.5) {
    //     _sLeft = true;
    //   } else if (value > 0.5) _sRight = true; else { _sLeft = false; _sRight = false; }
    // }
    // if (k.contains('hat y') || k == 'axis 7') {
    //   if (value < -0.5) {
    //     _sUp = true;
    //   } else if (value > 0.5) _sDown = true; else { _sUp = false; _sDown = false; }
    // }
  }

  bool _match(String k, List<String> exact, List<String> frags) {
    if (exact.contains(k)) return true;
    for (final f in frags) { if (k.contains(f)) return true; }
    return false;
  }

  void _handleButton(String k, double value) {

    if (_match(k, ['keycode_button_b'], []))  { //keycode_button_b back button down
      if (value < 0) {
        _sBack = true; return;
      } else if (value > 0) {
        _sBack = true; return;
      } else if (value == 0) {
        _sBack = false;
      }
    }

    if (_match(k, ['keycode_button_a'], []))  { //keycode_button_b back button down
      if (value < 0) {
        _sConfirm = true; return;
      } else if (value > 0) {
        _sConfirm = true; return;
      } else if (value == 0) {
        _sConfirm = false;
      }
    }

    if (_match(k, ['keycode_button_x'], []))  { //keycode_button_b back button down
      if (value < 0) {
        _sStart = true; return;
      } else if (value > 0) {
        _sStart = true; return;
      } else if (value == 0) {
        _sStart = false;
      }
    }


    if (_match(k, ['keycode_button_y'], []))  { //keycode_button_b back button down
      if (value < 0) {
        _sStart = true; return;
      } else if (value > 0) {
        _sStart = true; return;
      } else if (value == 0) {
        _sStart = false;
      }
    }

    // // D-pad
    // if (_match(k, ['21', 'dpad_left',  'keycode_dpad_left'],  ['dpad left']))  { _sLeft    = pressed; return; }
    // if (_match(k, ['22', 'dpad_right', 'keycode_dpad_right'], ['dpad right'])) { _sRight   = pressed; return; }
    // if (_match(k, ['19', 'dpad_up',    'keycode_dpad_up'],    ['dpad up']))    { _sUp      = pressed; return; }
    // if (_match(k, ['20', 'dpad_down',  'keycode_dpad_down'],  ['dpad down'])) { _sDown    = pressed; return; }
    // // Face: A=confirm, B=back, X=confirm, Start=start
    // if (_match(k, ['96','0'], ['button_a','cross','south']))   { _sConfirm = pressed; return; }
    // if (_match(k, ['97','1'], ['button_b','circle','east']))   { _sBack    = pressed; return; }
    // if (_match(k, ['99','2'], ['button_x','square','west']))   { _sConfirm = pressed; return; } // X also confirms
    // if (_match(k, ['108'],    ['start', 'keycode_button_start'])) { _sStart = pressed; return; }
    // //Other
    // if (_match(k, ['21', 'axis_hat_x',  'axis_x', 'axis_rz'], []))  {
    //   _sDown    = pressed; return;
    // }
    // if (_match(k, ['21', 'axis_hat_y',  'axis_y', 'axis_ry'], []))  {
    //   _sDown    = pressed; return;
    // }
    // if (_match(k, ['21', 'axis_ltrigger'], []))  {
    //   _sLeft    = pressed; return;
    // }
    // if (_match(k, ['21', 'axis_rtrigger'], []))  {
    //   _sRight    = pressed; return;
    // }
  }

  // ─── Hardware keyboard ───────────────────────────────────────────────────────
  bool _onHwKey(KeyEvent e) {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    _hwUp      = pressed.contains(LogicalKeyboardKey.arrowUp)    || pressed.contains(LogicalKeyboardKey.keyW);
    _hwDown    = pressed.contains(LogicalKeyboardKey.arrowDown)  || pressed.contains(LogicalKeyboardKey.keyS);
    _hwLeft    = pressed.contains(LogicalKeyboardKey.arrowLeft)  || pressed.contains(LogicalKeyboardKey.keyA);
    _hwRight   = pressed.contains(LogicalKeyboardKey.arrowRight) || pressed.contains(LogicalKeyboardKey.keyD);
    _hwConfirm = pressed.contains(LogicalKeyboardKey.enter)      || pressed.contains(LogicalKeyboardKey.space) || pressed.contains(LogicalKeyboardKey.gameButtonA);
    _hwBack    = pressed.contains(LogicalKeyboardKey.escape)     || pressed.contains(LogicalKeyboardKey.gameButtonB);
    _evaluateState();
    return false;
  }

  // ─── Combine and emit ────────────────────────────────────────────────────────
  GamepadNavEvent? _currentHeld;

  void _evaluateState() {
    final up      = _sUp;
    final down    = _sDown;
    final left    = _sLeft;
    final right   = _sRight;
    final confirm = _sConfirm || _hwConfirm;
    final back    = _sBack    || _hwBack;
    final start   = _sStart;

    GamepadNavEvent? held;
    if (confirm) {
      held = GamepadNavEvent.confirm;
    } else if (back)  held = GamepadNavEvent.back;
    else if (start) held = GamepadNavEvent.start;
    else if (up)    held = GamepadNavEvent.up;
    else if (down)  held = GamepadNavEvent.down;
    else if (left)  held = GamepadNavEvent.left;
    else if (right) held = GamepadNavEvent.right;

    if (held == _currentHeld) return;
    _currentHeld = held;
    _repeatTimer?.cancel();
    _repeatTimer = null;

    if (held == null) return;

    _fire(held);

    // Only repeat directional events, not confirm/back
    if (held == GamepadNavEvent.up || held == GamepadNavEvent.down ||
        held == GamepadNavEvent.left || held == GamepadNavEvent.right) {
      _repeatTimer = Timer(_repeatDelay, () {
        _repeatTimer = Timer.periodic(_repeatInterval, (_) {
          if (_currentHeld == held) _fire(held!);
        });
      });
    }
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