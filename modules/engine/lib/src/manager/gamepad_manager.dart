import 'dart:async' as dart_async;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamepads/gamepads.dart';

class GamepadManager extends Component with KeyboardHandler {
  static final GamepadManager _instance = GamepadManager._internal();
  factory GamepadManager() => _instance;

  GamepadManager._internal() {
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    _startStream();
  }

  // ─── Raw event log (latest 20) — read by GamepadDebugOverlay ────────────────
  final List<String> rawLog = [];

  // ─── Analog stick ────────────────────────────────────────────────────────────
  Vector2 _analog  = Vector2.zero();
  Vector2 _hwDpad  = Vector2.zero();

  // Auto-learn first two distinct analog axis keys (X, then Y)
  String? _axisXKey;
  String? _axisYKey;

  // ─── Stream button states (gamepads package — XABY etc on Android/PS) ────────
  // These must NOT be overwritten by HardwareKeyboard callbacks.
  bool _sJump   = false;
  bool _sAttack = false;
  bool _sBlock  = false;
  bool _sDodge  = false;

  // ─── HardwareKeyboard gamepad button states (Flutter mapped keys) ─────────────
  bool _hwJump   = false;
  bool _hwAttack = false;
  bool _hwBlock  = false;
  bool _hwDodge  = false;

  // ─── Keyboard fallback ───────────────────────────────────────────────────────
  Vector2 _kbStick = Vector2.zero();
  bool _kbJump     = false;
  bool _kbAttack   = false;
  bool _kbBlock    = false;
  bool _kbDodge    = false;

  // ─── Public accessors ────────────────────────────────────────────────────────
  Vector2 get joystickDelta {
    if (_analog.length > 0.12) return _analog;
    if (_hwDpad.length > 0.1)  return _hwDpad;
    return _kbStick;
  }

  // Stick up/down as explicit booleans — used by character controllers for
  // jump (up) and block (down) when no face buttons are pressed.
  bool get isStickUp   => joystickDelta.y < -0.5;
  bool get isStickDown => joystickDelta.y >  0.5;

  bool get isJumpPressed   => _sJump   || _hwJump   || _kbJump   || isStickUp;
  bool get isAttackPressed => _sAttack || _hwAttack || _kbAttack;
  bool get isBlockPressed  => _sBlock  || _hwBlock  || _kbBlock  || isStickDown;
  bool get isDodgePressed  => _sDodge  || _hwDodge  || _kbDodge;

  final ValueNotifier<bool> connected = ValueNotifier<bool>(false);
  bool get isGamepadConnected => connected.value;

  // ─── Edge detection ──────────────────────────────────────────────────────────
  bool _pAttack = false, _pJump = false, _pDodge = false, _pBlock = false;

  bool isAttackJustPressed() => _edge(isAttackPressed, _pAttack, (v) => _pAttack = v);
  bool isJumpJustPressed()   => _edge(isJumpPressed,   _pJump,   (v) => _pJump   = v);
  bool isDodgeJustPressed()  => _edge(isDodgePressed,  _pDodge,  (v) => _pDodge  = v);
  bool isBlockJustPressed()  => _edge(isBlockPressed,  _pBlock,  (v) => _pBlock  = v);

  bool _edge(bool cur, bool prev, void Function(bool) set) {
    final j = cur && !prev; set(cur); return j;
  }

  // ─── Internals ───────────────────────────────────────────────────────────────
  dart_async.StreamSubscription<GamepadEvent>? _sub;
  dart_async.Timer? _poll;

  @override
  void onMount() {
    super.onMount();
    _poll = dart_async.Timer.periodic(const Duration(seconds: 3), (_) => checkConnection());
    checkConnection();
  }

  @override
  void onRemove() {
    _poll?.cancel();
    _sub?.cancel();
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    super.onRemove();
  }

  void _startStream() {
    _sub?.cancel();
    _sub = Gamepads.events.listen(_onGamepadEvent, onError: (e) => debugPrint('🎮 err: $e'));
  }

  Future<void> checkConnection() async {
    try {
      final list = await Gamepads.list();
      final now = list.isNotEmpty;
      if (now != connected.value) {
        connected.value = now;
        if (now) debugPrint('🎮 Connected: ${list.first.name}');
        else _resetAll();
      }
    } catch (_) {}
  }

  // ─── gamepads stream handler ──────────────────────────────────────────────────
  void _onGamepadEvent(GamepadEvent e) {
    if (!connected.value) connected.value = true;

    final log = '[${e.type.name}] "${e.key}" = ${e.value.toStringAsFixed(3)}';
    rawLog.add(log);
    if (rawLog.length > 20) rawLog.removeAt(0);
    debugPrint('🎮 $log');

    if (e.type == KeyType.analog) {
      _handleAnalog(e.key.trim(), e.value);
    } else {
      // KeyType.button — PS XABY, shoulders, dpad buttons
      _handleStreamButton(e.key.trim(), e.value > 0.5);
    }
  }

  void _handleAnalog(String rawKey, double value) {
    final k = rawKey.toLowerCase();

    // ── Auto-learn first two distinct axes as X then Y ───────────────────────
    if (_axisXKey == null) {
      _axisXKey = k;
      debugPrint('🎮 Learned axis X = "$k"');
    } else if (_axisYKey == null && k != _axisXKey) {
      _axisYKey = k;
      debugPrint('🎮 Learned axis Y = "$k"');
    }

    if (k == _axisXKey) {
      _analog.x = _dz(value);
      return;
    }
    if (k == _axisYKey) {
      // PS Y axis is INVERTED: physical up → positive value.
      // Negate so game coords match: up = negative, down = positive.
      _analog.y = -_dz(value);
      return;
    }

    // ── Hat/D-pad axes ───────────────────────────────────────────────────────
    if (_isHatX(k)) { _hwDpad.x =  _dz(value); return; }
    if (_isHatY(k)) { _hwDpad.y = -_dz(value); return; } // same inversion

    // ── Triggers as buttons ──────────────────────────────────────────────────
    if (k.contains('right trigger') || k.contains('r2') || k == '5') { _sAttack = value > 0.3; return; }
    if (k.contains('left trigger')  || k.contains('l2') || k == '4') { _sBlock  = value > 0.3; return; }
  }

  void _handleStreamButton(String rawKey, bool pressed) {
    final k = rawKey.toLowerCase();

    // ── Face buttons: PS naming from gamepads on Android ────────────────────
    // gamepads sends "KEYCODE_BUTTON_A" stripped to key string — may vary.
    // Covers: "a", "button_a", "cross", "south", numeric "0" etc.
    if (_isBtn(k, ['a', 'button_a', 'cross',    'south',   '0', 'keycode_button_a']))   { _sJump   = pressed; return; }
    if (_isBtn(k, ['b', 'button_b', 'circle',   'east',    '1', 'keycode_button_b']))   { _sDodge  = pressed; return; }
    if (_isBtn(k, ['x', 'button_x', 'square',   'west',    '2', 'keycode_button_x']))   { _sAttack = pressed; return; }
    if (_isBtn(k, ['y', 'button_y', 'triangle', 'north',   '3', 'keycode_button_y']))   { _sBlock  = pressed; return; }

    // ── Shoulders / triggers ─────────────────────────────────────────────────
    if (_isBtn(k, ['r1', 'button_r1', 'right shoulder',  'rightshoulder',  '5', 'keycode_button_r1'])) { _sAttack = pressed; return; }
    if (_isBtn(k, ['l1', 'button_l1', 'left shoulder',   'leftshoulder',   '4', 'keycode_button_l1'])) { _sBlock  = pressed; return; }
    if (_isBtn(k, ['r2', 'button_r2', 'right trigger',   'righttrigger',   '7', 'keycode_button_r2'])) { _sAttack = pressed; return; }
    if (_isBtn(k, ['l2', 'button_l2', 'left trigger',    'lefttrigger',    '6', 'keycode_button_l2'])) { _sBlock  = pressed; return; }

    // ── D-pad buttons ────────────────────────────────────────────────────────
    if (_isBtn(k, ['left',  'dpad_left',  'dpad left',  'keycode_dpad_left']))  { if (pressed) _hwDpad.x = -1; else if (_hwDpad.x < 0) _hwDpad.x = 0; return; }
    if (_isBtn(k, ['right', 'dpad_right', 'dpad right', 'keycode_dpad_right'])) { if (pressed) _hwDpad.x =  1; else if (_hwDpad.x > 0) _hwDpad.x = 0; return; }
    if (_isBtn(k, ['up',    'dpad_up',    'dpad up',    'keycode_dpad_up']))    { if (pressed) _hwDpad.y = -1; else if (_hwDpad.y < 0) _hwDpad.y = 0; return; }
    if (_isBtn(k, ['down',  'dpad_down',  'dpad down',  'keycode_dpad_down'])) { if (pressed) _hwDpad.y =  1; else if (_hwDpad.y > 0) _hwDpad.y = 0; return; }
  }

  bool _isBtn(String k, List<String> variants) =>
      variants.any((v) => k == v || k.contains(v));

  bool _isHatX(String k) => k.contains('hat x') || (k.contains('dpad') && k.contains('x')) || k == 'axis 6' || k == '6';
  bool _isHatY(String k) => k.contains('hat y') || (k.contains('dpad') && k.contains('y')) || k == 'axis 7' || k == '7';

  double _dz(double v, {double t = 0.12}) => v.abs() < t ? 0.0 : v;

  // ─── HardwareKeyboard: Flutter mapped keys (for non-Android platforms) ────────
  // Does NOT touch _sJump/_sAttack/_sBlock/_sDodge — those belong to stream only.
  bool _onHardwareKey(KeyEvent e) {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    if (!connected.value && keys.any(_isHwGamepadKey)) connected.value = true;
    _updateHwButtons(keys);
    return false;
  }

  @override
  bool onKeyEvent(KeyEvent e, Set<LogicalKeyboardKey> pressed) {
    _updateKb(pressed);
    return true;
  }

  void _updateHwButtons(Set<LogicalKeyboardKey> keys) {
    // Flutter maps PS/Xbox buttons on macOS/iOS/Windows — not Android
    _hwJump   = keys.contains(LogicalKeyboardKey.gameButtonA);
    _hwAttack = keys.contains(LogicalKeyboardKey.gameButtonX)      ||
        keys.contains(LogicalKeyboardKey.gameButtonRight1) ||
        keys.contains(LogicalKeyboardKey.gameButtonRight2);
    _hwBlock  = keys.contains(LogicalKeyboardKey.gameButtonY)      ||
        keys.contains(LogicalKeyboardKey.gameButtonLeft1)  ||
        keys.contains(LogicalKeyboardKey.gameButtonLeft2);
    _hwDodge  = keys.contains(LogicalKeyboardKey.gameButtonB);

    // D-pad via arrow keys (macOS/iOS maps PS dpad to arrows)
    final dpadX = (keys.contains(LogicalKeyboardKey.arrowLeft)  ? -1.0 : 0.0) +
        (keys.contains(LogicalKeyboardKey.arrowRight) ?  1.0 : 0.0);
    final dpadY = (keys.contains(LogicalKeyboardKey.arrowUp)    ? -1.0 : 0.0) +
        (keys.contains(LogicalKeyboardKey.arrowDown)  ?  1.0 : 0.0);
    // Only override hwDpad if no stream dpad active
    if (_hwDpad.length < 0.1) {
      _hwDpad = Vector2(dpadX, dpadY);
    }
  }

  void _updateKb(Set<LogicalKeyboardKey> keys) {
    _kbStick = Vector2.zero();
    if (keys.contains(LogicalKeyboardKey.keyA)) _kbStick.x -= 1;
    if (keys.contains(LogicalKeyboardKey.keyD)) _kbStick.x += 1;
    if (keys.contains(LogicalKeyboardKey.keyW)) _kbStick.y -= 1;
    if (keys.contains(LogicalKeyboardKey.keyS)) _kbStick.y += 1;
    if (_kbStick.length > 1) _kbStick.normalize();

    _kbJump   = keys.contains(LogicalKeyboardKey.keyJ);
    _kbAttack = keys.contains(LogicalKeyboardKey.keyF) || keys.contains(LogicalKeyboardKey.space);
    _kbBlock  = keys.contains(LogicalKeyboardKey.shiftLeft) || keys.contains(LogicalKeyboardKey.shiftRight) || keys.contains(LogicalKeyboardKey.keyI);
    _kbDodge  = keys.contains(LogicalKeyboardKey.keyK) || keys.contains(LogicalKeyboardKey.keyL);
  }

  bool _isHwGamepadKey(LogicalKeyboardKey k) =>
      (k.debugName?.toLowerCase() ?? '').startsWith('game button');

  void _resetAll() {
    _analog = _hwDpad = _kbStick = Vector2.zero();
    _sJump = _sAttack = _sBlock = _sDodge = false;
    _hwJump = _hwAttack = _hwBlock = _hwDodge = false;
    _kbJump = _kbAttack = _kbBlock = _kbDodge = false;
  }

  void resetAxisLearning() {
    _axisXKey = _axisYKey = null;
    _analog = Vector2.zero();
    debugPrint('🎮 Axis learning reset');
  }

  Vector2 getJoystickDirection() => joystickDelta;
  bool hasMovementInput() => joystickDelta.length > 0.1;
}