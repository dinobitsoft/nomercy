import 'dart:async' as async;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamepads/gamepads.dart';

import 'gamepad_nav_event.dart';

// ─── Android keycodes ────────────────────────────────────────────────────────
const _kA   = '96';
const _kB   = '97';
const _kC   = '98';
const _kX   = '99';
const _kY   = '100';
const _kZ   = '101';
const _kL1  = '102';
const _kR1  = '103';
const _kL2  = '104';
const _kR2  = '105';
const _kSel = '109';
const _kStt = '108';
const _kDL  = '21';
const _kDR  = '22';
const _kDU  = '19';
const _kDD  = '20';

const _kButtonKeycodes = {
  _kA, _kB, _kC, _kX, _kY, _kZ,
  _kL1, _kR1, _kL2, _kR2, _kSel, _kStt,
  _kDL, _kDR, _kDU, _kDD,
};

const _kButtonFragments = [
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

  // ─── Debug log ───────────────────────────────────────────────────────────────
  final List<String> rawLog = [];

  // ─── Analog ──────────────────────────────────────────────────────────────────
  Vector2 _analog  = Vector2.zero();
  Vector2 _hwDpad  = Vector2.zero();
  String? _axisXKey;
  String? _axisYKey;

  // ─── Gameplay states ─────────────────────────────────────────────────────────
  bool _sJump = false, _sAttack = false, _sBlock = false, _sDodge = false;
  bool _hwJump = false, _hwAttack = false, _hwBlock = false, _hwDodge = false;
  Vector2 _kbStick = Vector2.zero();
  bool _kbJump = false, _kbAttack = false, _kbBlock = false, _kbDodge = false;

  // ─── Nav states (gamepads stream) ────────────────────────────────────────────
  bool _sNavConfirm = false, _sNavBack = false, _sNavStart = false;
  bool _sNavUp = false, _sNavDown = false, _sNavLeft = false, _sNavRight = false;

  // ─── Nav states (hardware keyboard) ─────────────────────────────────────────
  bool _hwNavConfirm = false, _hwNavBack = false;
  bool _hwNavUp = false, _hwNavDown = false, _hwNavLeft = false, _hwNavRight = false;

  // ─── Analog-stick nav ────────────────────────────────────────────────────────
  bool get _stickNavUp    => _analog.y < -0.5;
  bool get _stickNavDown  => _analog.y >  0.5;
  bool get _stickNavLeft  => _analog.x < -0.5;
  bool get _stickNavRight => _analog.x >  0.5;

  // ─── Nav event stream ────────────────────────────────────────────────────────
  final _navCtrl = async.StreamController<GamepadNavEvent>.broadcast();
  Stream<GamepadNavEvent> get navEvents => _navCtrl.stream;

  GamepadNavEvent? _heldNav;
  async.Timer? _repeatTimer;

  static const _debounce       = Duration(milliseconds: 180);
  static const _repeatDelay    = Duration(milliseconds: 400);
  static const _repeatInterval = Duration(milliseconds: 150);
  final Map<GamepadNavEvent, DateTime> _lastFired = {};

  // ─── Connection ──────────────────────────────────────────────────────────────
  final ValueNotifier<bool> connected = ValueNotifier<bool>(false);
  bool get isGamepadConnected => connected.value;

  // ─── Gameplay public API ─────────────────────────────────────────────────────
  Vector2 get joystickDelta {
    if (_analog.length  > 0.12) return _analog;
    if (_hwDpad.length  > 0.10) return _hwDpad;
    return _kbStick;
  }

  bool get isStickUp   => joystickDelta.y < -0.5;
  bool get isStickDown => joystickDelta.y >  0.5;

  bool get isJumpPressed   => _sJump   || _hwJump   || _kbJump   || isStickUp;
  bool get isAttackPressed => _sAttack || _hwAttack || _kbAttack;
  bool get isBlockPressed  => _sBlock  || _hwBlock  || _kbBlock  || isStickDown;
  bool get isDodgePressed  => _sDodge  || _hwDodge  || _kbDodge;

  Vector2 getJoystickDirection() => joystickDelta;
  bool hasMovementInput() => joystickDelta.length > 0.1;

  bool _pAttack = false, _pJump = false, _pDodge = false, _pBlock = false;
  bool isAttackJustPressed() => _edge(isAttackPressed, _pAttack, (v) => _pAttack = v);
  bool isJumpJustPressed()   => _edge(isJumpPressed,   _pJump,   (v) => _pJump   = v);
  bool isDodgeJustPressed()  => _edge(isDodgePressed,  _pDodge,  (v) => _pDodge  = v);
  bool isBlockJustPressed()  => _edge(isBlockPressed,  _pBlock,  (v) => _pBlock  = v);

  bool _edge(bool cur, bool prev, void Function(bool) set) {
    final j = cur && !prev; set(cur); return j;
  }

  // ─── Flame lifecycle ─────────────────────────────────────────────────────────
  async.StreamSubscription<GamepadEvent>? _sub;
  async.Timer? _poll;

  @override
  void onMount() {
    super.onMount();
    _poll = async.Timer.periodic(const Duration(seconds: 3), (_) => checkConnection());
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
        onError: (e) => debugPrint('🎮 stream err: $e'));
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

    final log = '[${e.type.name}] "${e.key}" = ${e.value.toStringAsFixed(3)}';
    rawLog.add(log);
    if (rawLog.length > 20) rawLog.removeAt(0);
    debugPrint('🎮 $log');

    final k = e.key.trim();
    if (e.type == KeyType.analog) {
      _handleAnalog(k, e.value);
    } else {
      _handleStreamButton(k, e.value > 0.5);
    }
  }

  bool _isButtonKey(String raw) {
    final k = raw.toLowerCase();
    if (_kButtonKeycodes.contains(k)) return true;
    for (final f in _kButtonFragments) { if (k.contains(f)) return true; }
    return false;
  }

  void _handleAnalog(String rawKey, double value) {
    final k = rawKey.toLowerCase();

    // Some controllers send buttons via analog channel
    if (_isButtonKey(k)) { _handleStreamButton(rawKey, value > 0.5); return; }

    // Auto-learn axes
    if (_axisXKey == null) {
      _axisXKey = k; debugPrint('🎮 axis X = "$k"');
    } else if (_axisYKey == null && k != _axisXKey) {
      _axisYKey = k; debugPrint('🎮 axis Y = "$k"');
    }

    if (k == _axisXKey) { _analog.x = _dz(value); _evalNav(); return; }
    if (k == _axisYKey) { _analog.y = -_dz(value); _evalNav(); return; } // PS: invert Y

    // Hat / D-pad axes
    if (_isHatX(k)) {
      _hwDpad.x  = _dz(value);
      _sNavLeft  = value < -0.5;
      _sNavRight = value >  0.5;
      _evalNav(); return;
    }
    if (_isHatY(k)) {
      _hwDpad.y = -_dz(value);
      // Hat Y: positive = down on most controllers
      _sNavUp   = value < -0.5;
      _sNavDown = value >  0.5;
      _evalNav(); return;
    }

    if (_isTriggerRight(k)) { _sAttack = value > 0.3; return; }
    if (_isTriggerLeft(k))  { _sBlock  = value > 0.3; return; }
  }

  void _handleStreamButton(String rawKey, bool pressed) {
    final k = rawKey.toLowerCase();

    // A → jump + confirm
    if (_matchBtn(k, exact: [_kA, '0'], frags: ['button_a', 'cross', 'south'])) {
      _sJump = pressed; _sNavConfirm = pressed; _evalNav(); return;
    }
    // B → dodge + back
    if (_matchBtn(k, exact: [_kB, '1'], frags: ['button_b', 'circle', 'east'])) {
      _sDodge = pressed; _sNavBack = pressed; _evalNav(); return;
    }
    // X → attack + confirm
    if (_matchBtn(k, exact: [_kX, '2'], frags: ['button_x', 'square', 'west'])) {
      _sAttack = pressed; _sNavConfirm = pressed; _evalNav(); return;
    }
    // Y → block
    if (_matchBtn(k, exact: [_kY, '3'], frags: ['button_y', 'triangle', 'north'])) {
      _sBlock = pressed; return;
    }
    // Shoulders / Triggers
    if (_matchBtn(k, exact: [_kR1], frags: ['button_r1', 'rightshoulder'])) { _sAttack = pressed; return; }
    if (_matchBtn(k, exact: [_kL1], frags: ['button_l1', 'leftshoulder']))  { _sBlock  = pressed; return; }
    if (_matchBtn(k, exact: [_kR2], frags: ['button_r2', 'righttrigger']))  { _sAttack = pressed; return; }
    if (_matchBtn(k, exact: [_kL2], frags: ['button_l2', 'lefttrigger']))   { _sBlock  = pressed; return; }

    // Start
    if (_matchBtn(k, exact: [_kStt], frags: ['start'])) {
      _sNavStart = pressed; _evalNav(); return;
    }

    // D-pad → gameplay + nav
    if (_matchBtn(k, exact: [_kDL], frags: ['dpad_left',  'dpad left'])) {
      if (pressed) _hwDpad.x = -1.0; else if (_hwDpad.x < 0) _hwDpad.x = 0.0;
      _sNavLeft = pressed; _evalNav(); return;
    }
    if (_matchBtn(k, exact: [_kDR], frags: ['dpad_right', 'dpad right'])) {
      if (pressed) _hwDpad.x =  1.0; else if (_hwDpad.x > 0) _hwDpad.x = 0.0;
      _sNavRight = pressed; _evalNav(); return;
    }
    if (_matchBtn(k, exact: [_kDU], frags: ['dpad_up',    'dpad up'])) {
      if (pressed) _hwDpad.y = -1.0; else if (_hwDpad.y < 0) _hwDpad.y = 0.0;
      _sNavUp = pressed; _evalNav(); return;
    }
    if (_matchBtn(k, exact: [_kDD], frags: ['dpad_down',  'dpad down'])) {
      if (pressed) _hwDpad.y =  1.0; else if (_hwDpad.y > 0) _hwDpad.y = 0.0;
      _sNavDown = pressed; _evalNav(); return;
    }
  }

  // ─── Hardware keyboard ────────────────────────────────────────────────────────
  bool _onHardwareKey(KeyEvent e) {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    if (!connected.value && keys.any(_isGamepadKey)) connected.value = true;
    _updateHw(keys);
    return false;
  }

  @override
  bool onKeyEvent(KeyEvent e, Set<LogicalKeyboardKey> pressed) {
    _updateKb(pressed); return true;
  }

  void _updateHw(Set<LogicalKeyboardKey> keys) {
    _hwJump   = keys.contains(LogicalKeyboardKey.gameButtonA);
    _hwDodge  = keys.contains(LogicalKeyboardKey.gameButtonB);
    _hwAttack = keys.contains(LogicalKeyboardKey.gameButtonX)      ||
        keys.contains(LogicalKeyboardKey.gameButtonRight1) ||
        keys.contains(LogicalKeyboardKey.gameButtonRight2);
    _hwBlock  = keys.contains(LogicalKeyboardKey.gameButtonY)      ||
        keys.contains(LogicalKeyboardKey.gameButtonLeft1)  ||
        keys.contains(LogicalKeyboardKey.gameButtonLeft2);

    final dx = (keys.contains(LogicalKeyboardKey.arrowLeft)  ? -1.0 : 0.0) +
        (keys.contains(LogicalKeyboardKey.arrowRight) ?  1.0 : 0.0);
    final dy = (keys.contains(LogicalKeyboardKey.arrowUp)    ? -1.0 : 0.0) +
        (keys.contains(LogicalKeyboardKey.arrowDown)  ?  1.0 : 0.0);
    if (_hwDpad.length < 0.1) _hwDpad = Vector2(dx, dy);

    _hwNavConfirm = keys.contains(LogicalKeyboardKey.enter)      ||
        keys.contains(LogicalKeyboardKey.space)       ||
        keys.contains(LogicalKeyboardKey.gameButtonA);
    _hwNavBack    = keys.contains(LogicalKeyboardKey.escape)      ||
        keys.contains(LogicalKeyboardKey.gameButtonB);
    _hwNavUp    = keys.contains(LogicalKeyboardKey.arrowUp)    || keys.contains(LogicalKeyboardKey.keyW);
    _hwNavDown  = keys.contains(LogicalKeyboardKey.arrowDown)  || keys.contains(LogicalKeyboardKey.keyS);
    _hwNavLeft  = keys.contains(LogicalKeyboardKey.arrowLeft)  || keys.contains(LogicalKeyboardKey.keyA);
    _hwNavRight = keys.contains(LogicalKeyboardKey.arrowRight) || keys.contains(LogicalKeyboardKey.keyD);
    _evalNav();
  }

  void _updateKb(Set<LogicalKeyboardKey> keys) {
    _kbStick = Vector2(
      (keys.contains(LogicalKeyboardKey.keyA) || keys.contains(LogicalKeyboardKey.arrowLeft)  ? -1.0 : 0.0) +
          (keys.contains(LogicalKeyboardKey.keyD) || keys.contains(LogicalKeyboardKey.arrowRight) ?  1.0 : 0.0),
      (keys.contains(LogicalKeyboardKey.keyW) || keys.contains(LogicalKeyboardKey.arrowUp)    ? -1.0 : 0.0) +
          (keys.contains(LogicalKeyboardKey.keyS) || keys.contains(LogicalKeyboardKey.arrowDown)  ?  1.0 : 0.0),
    );
    if (_kbStick.length > 1) _kbStick.normalize();
    _kbJump   = keys.contains(LogicalKeyboardKey.keyJ) || keys.contains(LogicalKeyboardKey.space);
    _kbAttack = keys.contains(LogicalKeyboardKey.keyF);
    _kbBlock  = keys.contains(LogicalKeyboardKey.keyI);
    _kbDodge  = keys.contains(LogicalKeyboardKey.keyK);
  }

  // ─── Nav state machine ────────────────────────────────────────────────────────
  void _evalNav() {
    final confirm = _sNavConfirm || _hwNavConfirm;
    final back    = _sNavBack    || _hwNavBack;
    final start   = _sNavStart;
    final up      = _sNavUp    || _stickNavUp    || _hwNavUp;
    final down    = _sNavDown  || _stickNavDown  || _hwNavDown;
    final left    = _sNavLeft  || _stickNavLeft  || _hwNavLeft;
    final right   = _sNavRight || _stickNavRight || _hwNavRight;

    GamepadNavEvent? held;
    if (confirm)    held = GamepadNavEvent.confirm;
    else if (back)  held = GamepadNavEvent.back;
    else if (start) held = GamepadNavEvent.start;
    else if (up)    held = GamepadNavEvent.up;
    else if (down)  held = GamepadNavEvent.down;
    else if (left)  held = GamepadNavEvent.left;
    else if (right) held = GamepadNavEvent.right;

    if (held == _heldNav) return;
    _heldNav = held;
    _repeatTimer?.cancel();
    _repeatTimer = null;

    if (held == null) return;
    _fireNav(held);

    if (held == GamepadNavEvent.up   || held == GamepadNavEvent.down  ||
        held == GamepadNavEvent.left || held == GamepadNavEvent.right) {
      _repeatTimer = async.Timer(_repeatDelay, () {
        _repeatTimer = async.Timer.periodic(_repeatInterval, (_) {
          if (_heldNav == held) _fireNav(held!);
        });
      });
    }
  }

  void _fireNav(GamepadNavEvent event) {
    final now  = DateTime.now();
    final last = _lastFired[event];
    if (last != null && now.difference(last) < _debounce) return;
    _lastFired[event] = now;
    debugPrint('🎮 NAV → ${event.name}');
    _navCtrl.add(event);
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────
  bool _matchBtn(String k, {required List<String> exact, required List<String> frags}) {
    for (final e in exact) { if (k == e)        return true; }
    for (final f in frags) { if (k.contains(f)) return true; }
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

  bool _isGamepadKey(LogicalKeyboardKey k) =>
      (k.debugName?.toLowerCase() ?? '').startsWith('game button');

  double _dz(double v, {double t = 0.12}) => v.abs() < t ? 0.0 : v;

  void resetAxisLearning() {
    _axisXKey = _axisYKey = null;
    _analog = Vector2.zero();
    debugPrint('🎮 Axis learning reset');
  }

  void _resetAll() {
    _analog = _hwDpad = _kbStick = Vector2.zero();
    _sJump = _sAttack = _sBlock = _sDodge = false;
    _hwJump = _hwAttack = _hwBlock = _hwDodge = false;
    _kbJump = _kbAttack = _kbBlock = _kbDodge = false;
    _sNavConfirm = _sNavBack = _sNavStart = false;
    _sNavUp = _sNavDown = _sNavLeft = _sNavRight = false;
    _hwNavConfirm = _hwNavBack = false;
    _hwNavUp = _hwNavDown = _hwNavLeft = _hwNavRight = false;
    _heldNav = null;
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }
}