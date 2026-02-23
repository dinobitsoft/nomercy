import 'package:core/core.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

class AudioSystem {
  // ==========================================
  // SINGLETON
  // ==========================================
  static final AudioSystem _instance = AudioSystem._internal();
  factory AudioSystem() => _instance;
  AudioSystem._internal() {
    _setupEventListeners();
    _preloadAudio();
  }

  final EventBus _eventBus = EventBus();

  // Audio state
  String? _currentMusic;
  double _musicVolume = GameConfig.musicVolume;
  double _sfxVolume = GameConfig.sfxVolume;
  bool _musicEnabled = true;
  bool _sfxEnabled = true;

  // Audio pools (prevent spam)
  final Map<String, DateTime> _lastPlayed = {};
  final Duration _minSoundInterval = const Duration(milliseconds: 100);

  // Subscriptions
  final List<EventSubscription> _subscriptions = [];

  // ==========================================
  // INITIALIZATION
  // ==========================================

  void _setupEventListeners() {
    // Avoid duplicate registrations on hot-reload
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    _subscriptions.add(_eventBus.on<PlaySFXEvent>(_onPlaySFX, priority: ListenerPriority.normal));
    _subscriptions.add(_eventBus.on<PlayMusicEvent>(_onPlayMusic, priority: ListenerPriority.normal));
    _subscriptions.add(_eventBus.on<StopMusicEvent>(_onStopMusic));
    _subscriptions.add(_eventBus.on<CharacterAttackedEvent>(_onAttack));
    _subscriptions.add(_eventBus.on<CharacterDamagedEvent>(_onDamage));
    _subscriptions.add(_eventBus.on<CharacterKilledEvent>(_onDeath));
    _subscriptions.add(_eventBus.on<WaveStartedEvent>(_onWaveStarted));
    _subscriptions.add(_eventBus.on<WaveCompletedEvent>(_onWaveCompleted));
    _subscriptions.add(_eventBus.on<ItemPickedUpEvent>(_onItemPickup));
    _subscriptions.add(_eventBus.on<ComboTriggeredEvent>(_onCombo));

    print('✅ AudioSystem: Event listeners registered');
  }

  Future<void> _preloadAudio() async {
    try {
      await FlameAudio.audioCache.loadAll([
        'hit.wav',
        'death.wav',
        'jump.wav',
        'critical_hit.wav',
        'block.wav',
        'item_pickup.wav',
        'chest_open.wav',
        'level_up.wav',
        'combo.wav',
        'land.wav',
        'sword_slash.wav',
        'arrow_shot.wav',
        'fireball.wav',
      ]);
      print('✅ AudioSystem: SFX preloaded');
    } catch (e) {
      if (kDebugMode) print('⚠️ AudioSystem: Failed to preload audio: $e');
    }
  }

  // ==========================================
  // EVENT HANDLERS
  // ==========================================

  void _onPlaySFX(PlaySFXEvent event) => playSFX(event.soundId, volume: event.volume);

  void _onPlayMusic(PlayMusicEvent event) => playMusic(event.musicId, volume: event.volume, loop: event.loop);

  void _onStopMusic(StopMusicEvent event) => stopMusic();

  void _onAttack(CharacterAttackedEvent event) {
    if (event.isCritical) {
      playSFX('critical_hit', volume: 1.2);
    } else if (event.isBlocked) {
      playSFX('block', volume: 0.8);
    } else {
      playSFX('hit', volume: 1.0);
    }
  }

  void _onDamage(CharacterDamagedEvent event) {
    if (event.healthPercent < 0.3 && event.healthPercent > 0) {
      playSFX('low_health', volume: 0.7);
    }
  }

  void _onDeath(CharacterKilledEvent event) => playSFX('death', volume: 1.0);

  void _onWaveStarted(WaveStartedEvent event) {
    if (event.waveNumber % 5 == 0) {
      playMusic('boss_theme', volume: 0.7);
    }
  }

  void _onWaveCompleted(WaveCompletedEvent event) {
    playSFX('wave_complete', volume: 0.9);
    if (event.perfectClear) playSFX('perfect_clear', volume: 1.0);
  }

  void _onItemPickup(ItemPickedUpEvent event) => playSFX('item_pickup', volume: 0.6);

  void _onCombo(ComboTriggeredEvent event) {
    if (event.comboCount >= 5) {
      playSFX('mega_combo', volume: 1.1);
    } else if (event.comboCount >= 3) {
      playSFX('combo', volume: 0.9);
    }
  }

  // ==========================================
  // AUDIO PLAYBACK
  // ==========================================

  void playSFX(String soundId, {double volume = 1.0}) {
    if (!_sfxEnabled) return;

    final lastPlayed = _lastPlayed[soundId];
    if (lastPlayed != null && DateTime.now().difference(lastPlayed) < _minSoundInterval) return;

    try {
      FlameAudio.play(
        '$soundId.wav',
        volume: volume * _sfxVolume * GameConfig.masterVolume,
      );
      _lastPlayed[soundId] = DateTime.now();
      if (kDebugMode) print('🔊 Playing SFX: $soundId');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to play SFX: $soundId - $e');
    }
  }

  void playMusic(String musicId, {double volume = 0.6, bool loop = true}) {
    if (!_musicEnabled) return;
    if (_currentMusic == musicId) return;

    try {
      FlameAudio.bgm.play(
        '${AudioPaths.music[musicId] ?? '$musicId.wav'}',
        volume: volume * _musicVolume * GameConfig.masterVolume,
      );
      _currentMusic = musicId;
      if (kDebugMode) print('🎵 Playing music: $musicId');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to play music: $musicId - $e');
    }
  }

  void stopMusic() {
    FlameAudio.bgm.stop();
    _currentMusic = null;
    if (kDebugMode) print('⏹️  Music stopped');
  }

  void pauseMusic() => FlameAudio.bgm.pause();

  void resumeMusic() {
    if (_musicEnabled) FlameAudio.bgm.resume();
  }

  // ==========================================
  // VOLUME CONTROL
  // ==========================================

  void setMusicVolume(double volume) {
    _musicVolume = volume.clamp(0.0, 1.0);
    FlameAudio.bgm.audioPlayer.setVolume(_musicVolume * GameConfig.masterVolume);
    if (kDebugMode) print('🔊 Music volume: ${(_musicVolume * 100).toInt()}%');
  }

  void setSFXVolume(double volume) {
    _sfxVolume = volume.clamp(0.0, 1.0);
    if (kDebugMode) print('🔊 SFX volume: ${(_sfxVolume * 100).toInt()}%');
  }

  void toggleMusic() {
    _musicEnabled = !_musicEnabled;
    if (!_musicEnabled) stopMusic();
    if (kDebugMode) print('🎵 Music ${_musicEnabled ? "enabled" : "disabled"}');
  }

  void toggleSFX() {
    _sfxEnabled = !_sfxEnabled;
    if (kDebugMode) print('🔊 SFX ${_sfxEnabled ? "enabled" : "disabled"}');
  }

  // ==========================================
  // GETTERS
  // ==========================================

  bool get isMusicEnabled => _musicEnabled;
  bool get isSFXEnabled => _sfxEnabled;
  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;
  String? get currentMusic => _currentMusic;

  // ==========================================
  // CLEANUP
  // ==========================================

  /// Call only on full app exit — never on screen pop.
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    stopMusic();
    FlameAudio.audioCache.clearAll();
    print('🗑️  AudioSystem: Disposed');
  }
}

// ==========================================
// AUDIO CONFIGURATION
// ==========================================

class AudioPaths {
  static const Map<String, String> sfx = {
    'hit': 'hit.wav',
    'critical_hit': 'critical_hit.wav',
    'block': 'block.wav',
    'death': 'death.wav',
    'item_pickup': 'item_pickup.wav',
    'chest_open': 'chest_open.wav',
    'level_up': 'level_up.wav',
    'combo': 'combo.wav',
    'mega_combo': 'mega_combo.wav',
    'jump': 'jump.wav',
    'land': 'land.wav',
    'sword_slash': 'sword_slash.wav',
    'arrow_shot': 'arrow_shot.wav',
    'fireball': 'fireball.wav',
    'wave_complete': 'wave_complete.wav',
    'perfect_clear': 'perfect_clear.wav',
    'low_health': 'low_health.wav',
  };

  static const Map<String, String> music = {
    'menu_theme': 'menu_theme.mp3',
    'battle_theme': 'battle_theme.wav',
    'boss_theme': 'boss_theme.mp3',
    'victory_theme': 'victory_theme.mp3',
  };
}