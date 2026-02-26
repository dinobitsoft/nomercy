import 'dart:async' as dart_async;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamepads/gamepads.dart';

import 'gamepad_nav_service.dart'; // for GamepadNavEvent

// ─── Android KEYCODE constants (gamepads sends these as numeric strings) ──────
const _kA   = '96';   // KEYCODE_BUTTON_A   → Jump / Confirm
const _kB   = '97';   // KEYCODE_BUTTON_B   → Dodge / Back
const _kC   = '98';
const _kX   = '99';   // KEYCODE_BUTTON_X   → Attack
const _kY   = '100';  // KEYCODE_BUTTON_Y   → Block
const _kZ   = '101';
const _kL1  = '102';
const _kR1  = '103';
const _kL2  = '104';
const _kR2  = '105';
const _kSel = '109';
const _kStt = '108';  // KEYCODE_BUTTON_START
const _kDL  = '21';   // KEYCODE_DPAD_LEFT
const _kDR  = '22';   // KEYCODE_DPAD_RIGHT
const _kDU  = '19';   // KEYCODE_DPAD_UP
const _kDD  = '20';   // KEYCODE_DPAD_DOWN

const _kButtonKeycodes = {
  _kA, _kB, _kC, _kX, _kY, _kZ,
  _kL1, _kR1, _kL2, _kR2,
  _kSel, _kStt,
  _kDL, _kDR, _kDU, _kDD,
};

const _kButtonNameFragments = [
  'button_a', 'button_b', 'button_x', 'button_y',
  'cross', 'circle', 'square', 'triangle',
  'south', 'east', 'west', 'north',
  'shoulder', 'trigger', 'select', 'start', 'mode',
  'dpad_left', 'dpad_right', 'dpad_up', 'dpad_down',
  'hat', 'thumbl', 'thumbr',
];

class GamepadManager extends Component with KeyboardHandler {
  static final GamepadManager _instance = GamepadManager._internal();
  factory GamepadManager() => _instance;

  GamepadManager._internal() {
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    _startStream();
  }

  // ─── Raw event log ───────────────────────────────────────────────────────────
  final List<String> rawLog = [];

  // ─── Analog stick ────────────────────────────────────────────────────────────
  Vector2 _analog = Vector2.zero();
  Vector2 _hwDpad = Vector2.zero();

  String? _axisXKey;
  String? _axisYKey;

  // ─── Gameplay button states ──────────────────────────────────────────────────
  bool _sJump = false, _sAttack = false, _sBlock = false, _sDodge = false;
  bool _hwJump = false, _hwAttack = false, _hwBlock = false, _hwDodge = false;
  Vector2 _kbStick = Vector2.zero();
  bool _kbJump = false, _kbAttack = false, _kbBlock = false, _kbDodge = false;

  // ─── Navigation button states ────────────────────────────────────────────────
  // Stream-sourced (gamepads package)
  bool _sNavConfirm = false;
  bool _sNavBack    = false;
  bool _sNavStart   = false;
  bool _sNavUp      = false;
  bool _sNavDown    = false;
  bool _sNavLeft    = false;
  bool _sNavRight   = false;

  // Analog stick nav (derived on-the-fly)
  bool get _analogNavUp    => _analog.y < -0.5;
  bool get _analogNavDown  => _analog.y >  0.5;
  bool get _analogNavLeft  => _analog.x < -0.5;
  bool get _analogNavRight => _analog.x >  0.5;

  // Hardware keyboard nav
  bool _hwNavConfirm = false;
  bool _hwNavBack    = false;
  bool _hwNavUp      = false;
  bool _hwNavDown    = false;
  bool _hwNavLeft    = false;
  bool _hwNavRight   = false;

  // ─── Nav event stream ────────────────────────────────────────────────────────
  final _navController = dart_async.StreamController<GamepadNavEvent>.broadcast();
  Stream<GamepadNavEvent> get navEvents => _navController.stream;

  GamepadNavEvent? _heldNavEvent;
  dart_async.Timer? _repeatTimer;

  static const _debounce       = Duration(milliseconds: 180);
  static const _repeatDelay    = Duration(milliseconds: 400);
  static const _repeatInterval = Duration(milliseconds: 150);
  final Map<GamepadNavEvent, DateTime> _lastFired = {};

  // ─── Connection ──────────────────────────────────────────────────────────────
  final ValueNotifier<bool> connected = ValueNotifier<bool>(false);
  bool get isGamepadConnected => connected.value;

  // ─── Gameplay public accessors ───────────────────────────────────────────────
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

  bool _pAttack = false, _pJump = false, _pDodge = false, _pBlock = false;
  bool isAttackJustPressed() => _edge(isAttackPressed, _pAttack, (v) => _pAttack = v);
  bool isJumpJustPressed()   => _edge(isJumpPressed,   _pJump,   (v) => _pJump   = v);
  bool isDodgeJustPressed()  => _edge(isDodgePressed,  _pDodge,  (v) => _pDodge  = v);
  bool isBlockJustPressed()  => _edge(isBlockPressed,  _pBlock,  (v) => _pBlock  = v);

  bool _edge(bool cur, bool prev, void Function(bool) set) {
    final j = cur && !prev;
    set(cur);
    return j;
  }

  // ─── Lifecycle ───────────────────────────────────────────────────────────────
  dart_async.StreamSubscription<GamepadEvent>? _sub;
  dart_async.Timer? _poll;

  @override
  void onMount() {
    super.onMount();
    _poll = dart_async.Timer.periodic(
        const Duration(seconds: 3), (_) => checkConnection());
    checkConnection();
  }

  @override
  void onRemove() {
    _poll?.cancel();
    _sub?.cancel();
    _repeatTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    super.onRemove();
  }

  void _startStream() {
    _sub?.cancel();
    _sub = Gamepads.events.listen(_onGamepadEvent,
        onError: (e) => debugPrint('🎮 err: $e'));
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

  // ─── Gamepads stream handler ─────────────────────────────────────────────────
  void _onGamepadEvent(GamepadEvent e) {
    if (!connected.value) connected.value = true;

    final log =
        '[${e.type.name}] "${e.key}" = ${e.value.toStringAsFixed(3)}';
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

  bool _isButtonKey(String raw) {
    final k = raw.toLowerCase();
    if (_kButtonKeycodes.contains(k)) return true;
    for (final frag in _kButtonNameFragments) {
      if (k.contains(frag)) return true;
    }
    return false;
  }

  void _handleAnalog(String rawKey, double value) {
    final k = rawKey.toLowerCase();

    if (_isButtonKey(k)) {
      _handleStreamButton(rawKey, value > 0.5);
      return;
    }

    // Auto-learn axes
    if (_axisXKey == null) {
      _axisXKey = k;
      debugPrint('🎮 Learned axis X = "$k"');
    } else if (_axisYKey == null && k != _axisXKey) {
      _axisYKey = k;
      debugPrint('🎮 Learned axis Y = "$k"');
    }

    if (k == _axisXKey) {
      _analog.x = _dz(value);
      _evaluateNavState();
      return;
    }
    if (k == _axisYKey) {
      _analog.y = -_dz(value); // PS Y axis is inverted
      _evaluateNavState();
      return;
    }

    // Hat / D-pad axes
    if (_isHatX(k)) {
      _hwDpad.x = _dz(value);
      if (value < -0.5) {
        _sNavLeft = true; _sNavRight = false;
      } else if (value > 0.5) {
        _sNavRight = true; _sNavLeft = false;
      } else {
        _sNavLeft = false; _sNavRight = false;
      }
      _evaluateNavState();
      return;
    }
    if (_isHatY(k)) {
      _hwDpad.y = -_dz(value);
      if (value < -0.5) {
        _sNavDown = true; _sNavUp = false;
      } else if (value > 0.5) {
        _sNavUp = true; _sNavDown = false;
      } else {
        _sNavUp = false; _sNavDown = false;
      }
      _evaluateNavState();
      return;
    }

    // Triggers as gameplay buttons
    if (_isTriggerRight(k)) { _sAttack = value > 0.3; return; }
    if (_isTriggerLeft(k))  { _sBlock  = value > 0.3; return; }
  }

  void _handleStreamButton(String rawKey, bool pressed) {
    final k = rawKey.toLowerCase();

    // ── Face buttons: gameplay ────────────────────────────────────────────────
    if (_matchBtn(k, exact: [_kA, '0'],   fragments: ['button_a', 'cross',     'south'])) {
      _sJump      = pressed;
      _sNavConfirm = pressed; // A = confirm in menus
      _evaluateNavState();
      return;
    }
    if (_matchBtn(k, exact: [_kB, '1'],   fragments: ['button_b', 'circle',    'east'])) {
      _sDodge     = pressed;
      _sNavBack   = pressed; // B = back in menus
      _evaluateNavState();
      return;
    }
    if (_matchBtn(k, exact: [_kX, '2'],   fragments: ['button_x', 'square',    'west'])) {
      _sAttack    = pressed;
      _sNavConfirm = pressed; // X also confirms
      _evaluateNavState();
      return;
    }
    if (_matchBtn(k, exact: [_kY, '3'],   fragments: ['button_y', 'triangle',  'north'])) {
      _sBlock = pressed;
      return;
    }

    // ── Shoulders ─────────────────────────────────────────────────────────────
    if (_matchBtn(k, exact: [_kR1], fragments: ['button_r1', 'rightshoulder', 'right shoulder'])) { _sAttack = pressed; return; }
    if (_matchBtn(k, exact: [_kL1], fragments: ['button_l1', 'leftshoulder',  'left shoulder']))  { _sBlock  = pressed; return; }
    if (_matchBtn(k, exact: [_kR2], fragments: ['button_r2', 'righttrigger',  'right trigger'])) { _sAttack = pressed; return; }
    if (_matchBtn(k, exact: [_kL2], fragments: ['button_l2', 'lefttrigger',   'left trigger']))  { _sBlock  = pressed; return; }

    // ── Start / Select ────────────────────────────────────────────────────────
    if (_matchBtn(k, exact: [_kStt], fragments: ['start', 'keycode_button_start'])) {
      _sNavStart = pressed;
      _evaluateNavState();
      return;
    }

    // ── D-pad: gameplay + navigation ──────────────────────────────────────────
    if (_matchBtn(k, exact: [_kDL], fragments: ['dpad_left',  'dpad left'])) {
      if (pressed) _hwDpad.x = -1; else if (_hwDpad.x < 0) _hwDpad.x = 0;
      _sNavLeft = pressed; if (!pressed) _sNavRight = false;
      _evaluateNavState(); return;
    }
    if (_matchBtn(k, exact: [_kDR], fragments: ['dpad_right', 'dpad right'])) {
      if (pressed) _hwDpad.x =  1; else if (_hwDpad.x > 0) _hwDpad.x = 0;
      _sNavRight = pressed; if (!pressed) _sNavLeft = false;
      _evaluateNavState(); return;
    }
    if (_matchBtn(k, exact: [_kDU], fragments: ['dpad_up',    'dpad up'])) {
      if (pressed) _hwDpad.y = -1; else if (_hwDpad.y < 0) _hwDpad.y = 0;
      _sNavUp = pressed; if (!pressed) _sNavDown = false;
      _evaluateNavState(); return;
    }
    if (_matchBtn(k, exact: [_kDD], fragments: ['dpad_down',  'dpad down'])) {
      if (pressed) _hwDpad.y =  1; else if (_hwDpad.y > 0) _hwDpad.y = 0;
      _sNavDown = pressed; if (!pressed) _sNavUp = false;
      _evaluateNavState(); return;
    }
  }

  // ─── Hardware keyboard ────────────────────────────────────────────────────────
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

    final dpadX =
        (keys.contains(LogicalKeyboardKey.arrowLeft)  ? -1.0 : 0.0) +
            (keys.contains(LogicalKeyboardKey.arrowRight) ?  1.0 : 0.0);
    final dpadY =
        (keys.contains(LogicalKeyboardKey.arrowUp)    ? -1.0 : 0.0) +
            (keys.contains(LogicalKeyboardKey.arrowDown)  ?  1.0 : 0.0);
    _hwDpad = Vector2(dpadX, dpadY);

    // Nav from hardware keyboard
    _hwNavConfirm = keys.contains(LogicalKeyboardKey.enter)      ||
        keys.contains(LogicalKeyboardKey.space)      ||
        keys.contains(LogicalKeyboardKey.gameButtonA);
    _hwNavBack    = keys.contains(LogicalKeyboardKey.escape)     ||
        keys.contains(LogicalKeyboardKey.gameButtonB);
    _hwNavUp      = keys.contains(LogicalKeyboardKey.arrowUp)    ||
        keys.contains(LogicalKeyboardKey.keyW);
    _hwNavDown    = keys.contains(LogicalKeyboardKey.arrowDown)  ||
        keys.contains(LogicalKeyboardKey.keyS);
    _hwNavLeft    = keys.contains(LogicalKeyboardKey.arrowLeft)  ||
        keys.contains(LogicalKeyboardKey.keyA);
    _hwNavRight   = keys.contains(LogicalKeyboardKey.arrowRight) ||
        keys.contains(LogicalKeyboardKey.keyD);

    _evaluateNavState();
  }

  void _updateKb(Set<LogicalKeyboardKey> keys) {
    final dx =
        (keys.contains(LogicalKeyboardKey.arrowLeft)  || keys.contains(LogicalKeyboardKey.keyA) ? -1.0 : 0.0) +
            (keys.contains(LogicalKeyboardKey.arrowRight) || keys.contains(LogicalKeyboardKey.keyD) ?  1.0 : 0.0);
    final dy =
        (keys.contains(LogicalKeyboardKey.arrowUp)    || keys.contains(LogicalKeyboardKey.keyW) ? -1.0 : 0.0) +
            (keys.contains(LogicalKeyboardKey.arrowDown)  || keys.contains(LogicalKeyboardKey.keyS) ?  1.0 : 0.0);
    _kbStick  = Vector2(dx, dy);
    _kbJump   = keys.contains(LogicalKeyboardKey.space) || keys.contains(LogicalKeyboardKey.keyZ);
    _kbAttack = keys.contains(LogicalKeyboardKey.keyJ)  || keys.contains(LogicalKeyboardKey.keyK);
    _kbBlock  = keys.contains(LogicalKeyboardKey.keyL);
    _kbDodge  = keys.contains(LogicalKeyboardKey.keyX);
  }

  // ─── Nav state machine ────────────────────────────────────────────────────────
  void _evaluateNavState() {
    final confirm = _sNavConfirm || _hwNavConfirm;
    final back    = _sNavBack    || _hwNavBack;
    final start   = _sNavStart;
    final up      = _sNavUp    || _analogNavUp    || _hwNavUp;
    final down    = _sNavDown  || _analogNavDown  || _hwNavDown;
    final left    = _sNavLeft  || _analogNavLeft  || _hwNavLeft;
    final right   = _sNavRight || _analogNavRight || _hwNavRight;

    GamepadNavEvent? held;
    if (confirm)     held = GamepadNavEvent.confirm;
    else if (back)   held = GamepadNavEvent.back;
    else if (start)  held = GamepadNavEvent.start;
    else if (up)     held = GamepadNavEvent.up;
    else if (down)   held = GamepadNavEvent.down;
    else if (left)   held = GamepadNavEvent.left;
    else if (right)  held = GamepadNavEvent.right;

    if (held == _heldNavEvent) return;
    _heldNavEvent = held;
    _repeatTimer?.cancel();
    _repeatTimer = null;

    if (held == null) return;

    _fireNav(held);

    // Repeat only for directions
    if (held == GamepadNavEvent.up    || held == GamepadNavEvent.down ||
        held == GamepadNavEvent.left  || held == GamepadNavEvent.right) {
      _repeatTimer = dart_async.Timer(_repeatDelay, () {
        _repeatTimer =
            dart_async.Timer.periodic(_repeatInterval, (_) {
              if (_heldNavEvent == held) _fireNav(held!);
            });
      });
    }
  }

  void _fireNav(GamepadNavEvent event) {
    final now  = DateTime.now();
    final last = _lastFired[event];
    if (last != null && now.difference(last) < _debounce) return;
    _lastFired[event] = now;
    _navController.add(event);
    debugPrint('🎮 NAV → ${event.name}');
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────
  bool _matchBtn(String k,
      {required List<String> exact, required List<String> fragments}) {
    for (final e in exact)     { if (k == e)          return true; }
    for (final f in fragments) { if (k.contains(f))   return true; }
    return false;
  }

  bool _isHatX(String k) =>
      k.contains('hat x') || k == 'axis_hat_x' || k == 'axis 6';
  bool _isHatY(String k) =>
      k.contains('hat y') || k == 'axis_hat_y' || k == 'axis 7';
  bool _isTriggerRight(String k) =>
      k.contains('right trigger') || k.contains('righttrigger') ||
          k.contains('r2') || k.contains('axis_z') || k == 'axis 5';
  bool _isTriggerLeft(String k) =>
      k.contains('left trigger')  || k.contains('lefttrigger')  ||
          k.contains('l2') || k.contains('axis_rz') || k == 'axis 4';

  Vector2 getJoystickDirection() => joystickDelta;
  bool hasMovementInput() => joystickDelta.length > 0.1;

  void resetAxisLearning() {
    _axisXKey = _axisYKey = null;
    _analog = Vector2.zero();
    debugPrint('🎮 Axis learning reset');
  }

  double _dz(double v, {double t = 0.12}) => v.abs() < t ? 0.0 : v;

  bool _isHwGamepadKey(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.gameButtonA ||
          k == LogicalKeyboardKey.gameButtonB ||
          k == LogicalKeyboardKey.gameButtonX ||
          k == LogicalKeyboardKey.gameButtonY;

  void _resetAll() {
    _analog = Vector2.zero();
    _hwDpad = Vector2.zero();
    _kbStick = Vector2.zero();
    _sJump = _sAttack = _sBlock = _sDodge = false;
    _hwJump = _hwAttack = _hwBlock = _hwDodge = false;
    _kbJump = _kbAttack = _kbBlock = _kbDodge = false;
    _sNavConfirm = _sNavBack = _sNavStart = false;
    _sNavUp = _sNavDown = _sNavLeft = _sNavRight = false;
    _hwNavConfirm = _hwNavBack = false;
    _hwNavUp = _hwNavDown = _hwNavLeft = _hwNavRight = false;
    _heldNavEvent = null;
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }
}