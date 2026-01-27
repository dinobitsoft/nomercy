import 'package:flame/sprite.dart';

class AnimationComponent {
  final Map<String, SpriteAnimation> animations;
  final Map<String, SpriteAnimationTicker> _tickers = {};
  String _currentState;
  SpriteAnimationTicker? _currentTicker;
  double _stateTime = 0;
  final Map<String, int> _statePriority;

  AnimationComponent({
    required this.animations,
    required String initialState,
    Map<String, int>? statePriority,
  })  : _currentState = initialState,
        _statePriority = statePriority ?? {} {
    // Create tickers for all animations
    animations.forEach((key, animation) {
      _tickers[key] = animation.createTicker();
    });
    _currentTicker = _tickers[initialState];
  }

  String get currentState => _currentState;
  SpriteAnimation? get animation => animations[_currentState];
  double get stateTime => _stateTime;

  /// Update animation
  void update(double dt) {
    _stateTime += dt;
    _currentTicker?.update(dt);
  }

  /// Change animation state
  bool setState(String newState, {bool force = false}) {
    if (newState == _currentState && !force) return false;

    // Check priority (higher priority can interrupt lower)
    if (!force) {
      final currentPriority = _statePriority[_currentState] ?? 0;
      final newPriority = _statePriority[newState] ?? 0;

      if (newPriority < currentPriority) {
        return false; // Lower priority, can't interrupt
      }
    }

    final newTicker = _tickers[newState];
    if (newTicker == null) return false;

    _currentState = newState;
    _currentTicker = newTicker;
    _stateTime = 0;
    _currentTicker?.reset();

    return true;
  }

  /// Check if animation is finished (for non-looping anims)
  bool get isAnimationFinished {
    final ticker = _currentTicker;
    if (ticker == null || ticker.spriteAnimation.loop) return false;
    return ticker.done();
  }
}