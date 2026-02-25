import 'dart:async' as dart_async;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamepads/gamepads.dart';

// ─── Android KEYCODE constants (gamepads sends these as numeric strings) ──────
const _kA   = '96';   // KEYCODE_BUTTON_A   → Jump
const _kB   = '97';   // KEYCODE_BUTTON_B   → Dodge
const _kC   = '98';   // KEYCODE_BUTTON_C   (unused)
const _kX   = '99';   // KEYCODE_BUTTON_X   → Attack
const _kY   = '100';  // KEYCODE_BUTTON_Y   → Block
const _kZ   = '101';  // KEYCODE_BUTTON_Z   (unused)
const _kL1  = '102';  // KEYCODE_BUTTON_L1  → Block
const _kR1  = '103';  // KEYCODE_BUTTON_R1  → Attack
const _kL2  = '104';  // KEYCODE_BUTTON_L2  → Block
const _kR2  = '105';  // KEYCODE_BUTTON_R2  → Attack
const _kSel = '109';  // KEYCODE_BUTTON_SELECT
const _kStt = '108';  // KEYCODE_BUTTON_START
// D-pad keycodes
const _kDL  = '21';   // KEYCODE_DPAD_LEFT
const _kDR  = '22';   // KEYCODE_DPAD_RIGHT
const _kDU  = '19';   // KEYCODE_DPAD_UP
const _kDD  = '20';   // KEYCODE_DPAD_DOWN

/// Keys that are buttons, NOT analog axes — must never be learned as axis X/Y.
const _kButtonKeycodes = {_kA, _kB, _kC, _kX, _kY, _kZ, _kL1, _kR1, _kL2, _kR2, _kSel, _kStt, _kDL, _kDR, _kDU, _kDD};

/// Named fragments that identify a button key (not an axis).
const _kButtonNameFragments = ['button_a', 'button_b', 'button_x', 'button_y',
  'cross', 'circle', 'square', 'triangle',
  'south', 'east', 'west', 'north',
  'shoulder', 'trigger', 'select', 'start', 'mode',
  'dpad_left', 'dpad_right', 'dpad_up', 'dpad_down',
  'hat', 'thumbl', 'thumbr'];

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

  String? _axisXKey;
  String? _axisYKey;

  // ─── Stream button states ────────────────────────────────────────────────────
  bool _sJump   = false;
  bool _sAttack = false;
  bool _sBlock  = false;
  bool _sDodge  = false;

  // ─── HardwareKeyboard gamepad button states ───────────────────────────────────
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

    final trimmed = e.key.trim();

    if (e.type == KeyType.analog) {
      _handleAnalog(trimmed, e.value);
    } else {
      _handleStreamButton(trimmed, e.value > 0.5);
    }
  }

  /// Returns true if this key string identifies a button, not an axis.
  bool _isButtonKey(String raw) {
    final k = raw.toLowerCase();
    // Exact match against Android keycode numerics
    if (_kButtonKeycodes.contains(k)) return true;
    // Named fragment match
    for (final frag in _kButtonNameFragments) {
      if (k.contains(frag)) return true;
    }
    return false;
  }

  void _handleAnalog(String rawKey, double value) {
    final k = rawKey.toLowerCase();

    // ── CRITICAL: never learn a face/shoulder/dpad button as an axis ──────────
    if (_isButtonKey(k)) {
      // Treat as digital button from analog channel (some controllers do this)
      _handleStreamButton(rawKey, value > 0.5);
      return;
    }

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
      _analog.y = -_dz(value);
      return;
    }

    // ── Hat/D-pad axes ───────────────────────────────────────────────────────
    if (_isHatX(k)) { _hwDpad.x =  _dz(value); return; }
    if (_isHatY(k)) { _hwDpad.y = -_dz(value); return; }

    // ── Triggers as buttons (analog threshold) ───────────────────────────────
    if (_isTriggerRight(k)) { _sAttack = value > 0.3; return; }
    if (_isTriggerLeft(k))  { _sBlock  = value > 0.3; return; }
  }

  void _handleStreamButton(String rawKey, bool pressed) {
    final k = rawKey.toLowerCase();

    // ── Face buttons ─────────────────────────────────────────────────────────
    // Android keycodes: A=96, B=97, X=99, Y=100
    // Named: cross/south=jump, circle/east=dodge, square/west=attack, triangle/north=block
    if (_matchBtn(k, exact: [_kA, '0'], fragments: ['button_a', 'cross', 'south']))         { _sJump   = pressed; return; }
    if (_matchBtn(k, exact: [_kB, '1'], fragments: ['button_b', 'circle', 'east']))          { _sDodge  = pressed; return; }
    if (_matchBtn(k, exact: [_kX, '2'], fragments: ['button_x', 'square', 'west']))          { _sAttack = pressed; return; }
    if (_matchBtn(k, exact: [_kY, '3'], fragments: ['button_y', 'triangle', 'north']))       { _sBlock  = pressed; return; }

    // ── Shoulders ────────────────────────────────────────────────────────────
    if (_matchBtn(k, exact: [_kR1], fragments: ['button_r1', 'rightshoulder', 'right shoulder'])) { _sAttack = pressed; return; }
    if (_matchBtn(k, exact: [_kL1], fragments: ['button_l1', 'leftshoulder',  'left shoulder']))  { _sBlock  = pressed; return; }

    // ── Triggers (digital path) ───────────────────────────────────────────────
    if (_matchBtn(k, exact: [_kR2], fragments: ['button_r2', 'righttrigger', 'right trigger'])) { _sAttack = pressed; return; }
    if (_matchBtn(k, exact: [_kL2], fragments: ['button_l2', 'lefttrigger',  'left trigger']))  { _sBlock  = pressed; return; }

    // ── D-pad ────────────────────────────────────────────────────────────────
    if (_matchBtn(k, exact: [_kDL], fragments: ['dpad_left',  'dpad left']))  { if (pressed) _hwDpad.x = -1; else if (_hwDpad.x < 0) _hwDpad.x = 0; return; }
    if (_matchBtn(k, exact: [_kDR], fragments: ['dpad_right', 'dpad right'])) { if (pressed) _hwDpad.x =  1; else if (_hwDpad.x > 0) _hwDpad.x = 0; return; }
    if (_matchBtn(k, exact: [_kDU], fragments: ['dpad_up',    'dpad up']))    { if (pressed) _hwDpad.y = -1; else if (_hwDpad.y < 0) _hwDpad.y = 0; return; }
    if (_matchBtn(k, exact: [_kDD], fragments: ['dpad_down',  'dpad down']))  { if (pressed) _hwDpad.y =  1; else if (_hwDpad.y > 0) _hwDpad.y = 0; return; }
  }

  /// Safe button matcher: exact match for short/numeric strings, fragment match for names.
  /// Avoids false positives from single-char contains (e.g. 'a' inside 'analog').
  bool _matchBtn(String k, {required List<String> exact, required List<String> fragments}) {
    for (final e in exact) {
      if (k == e) return true;
    }
    for (final f in fragments) {
      if (k.contains(f)) return true;
    }
    return false;
  }

  bool _isHatX(String k) => k.contains('hat x') || k == 'axis_hat_x' || k == 'axis 6';
  bool _isHatY(String k) => k.contains('hat y') || k == 'axis_hat_y' || k == 'axis 7';

  bool _isTriggerRight(String k) =>
      k.contains('right trigger') || k.contains('righttrigger') ||
          k.contains('r2') || k.contains('axis_z') || k == 'axis 5';
  bool _isTriggerLeft(String k) =>
      k.contains('left trigger')  || k.contains('lefttrigger')  ||
          k.contains('l2') || k.contains('axis_rz') || k == 'axis 4';

  double _dz(double v, {double t = 0.12}) => v.abs() < t ? 0.0 : v;

  // ─── HardwareKeyboard: Flutter mapped keys (non-Android platforms) ────────────
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
    _hwJump   = keys.contains(LogicalKeyboardKey.gameButtonA);
    _hwAttack = keys.contains(LogicalKeyboardKey.gameButtonX)      ||
        keys.contains(LogicalKeyboardKey.gameButtonRight1) ||
        keys.contains(LogicalKeyboardKey.gameButtonRight2);
    _hwBlock  = keys.contains(LogicalKeyboardKey.gameButtonY)      ||
        keys.contains(LogicalKeyboardKey.gameButtonLeft1)  ||
        keys.contains(LogicalKeyboardKey.gameButtonLeft2);
    _hwDodge  = keys.contains(LogicalKeyboardKey.gameButtonB);

    final dpadX = (keys.contains(LogicalKeyboardKey.arrowLeft)  ? -1.0 : 0.0) +
        (keys.contains(LogicalKeyboardKey.arrowRight) ?  1.0 : 0.0);
    final dpadY = (keys.contains(LogicalKeyboardKey.arrowUp)    ? -1.0 : 0.0) +
        (keys.contains(LogicalKeyboardKey.arrowDown)  ?  1.0 : 0.0);
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
    _kbBlock  = keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight) ||
        keys.contains(LogicalKeyboardKey.keyI);
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