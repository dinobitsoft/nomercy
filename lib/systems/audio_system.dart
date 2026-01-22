import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

import '../config/game_config.dart';
import '../core/event_bus.dart';
import '../core/game_event.dart';

/// Audio system - handles all game audio using events
class AudioSystem {
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

  AudioSystem() {
    _setupEventListeners();
    _preloadAudio();
  }

  /// Setup event listeners
  void _setupEventListeners() {
    // Listen for SFX events
    _subscriptions.add(
      _eventBus.on<PlaySFXEvent>(
        _onPlaySFX,
        priority: ListenerPriority.normal,
      ),
    );

    // Listen for music events
    _subscriptions.add(
      _eventBus.on<PlayMusicEvent>(
        _onPlayMusic,
        priority: ListenerPriority.normal,
      ),
    );

    _subscriptions.add(
      _eventBus.on<StopMusicEvent>(
        _onStopMusic,
        priority: ListenerPriority.normal,
      ),
    );

    // Listen for combat events
    _subscriptions.add(
      _eventBus.on<CharacterAttackedEvent>(_onAttack),
    );

    _subscriptions.add(
      _eventBus.on<CharacterDamagedEvent>(_onDamage),
    );

    _subscriptions.add(
      _eventBus.on<CharacterKilledEvent>(_onDeath),
    );

    // Listen for game state events
    _subscriptions.add(
      _eventBus.on<WaveStartedEvent>(_onWaveStarted),
    );

    _subscriptions.add(
      _eventBus.on<WaveCompletedEvent>(_onWaveCompleted),
    );

    _subscriptions.add(
      _eventBus.on<ItemPickedUpEvent>(_onItemPickup),
    );

    _subscriptions.add(
      _eventBus.on<ComboTriggeredEvent>(_onCombo),
    );

    print('✅ AudioSystem: Event listeners registered');
  }

  /// Preload all audio files
  Future<void> _preloadAudio() async {
    try {
      // Preload SFX
      await FlameAudio.audioCache.loadAll([
        'hit.wav',
        'critical_hit.wav',
        'block.wav',
        'death.wav',
        'item_pickup.wav',
        'chest_open.wav',
        'level_up.wav',
        'combo.wav',
        'jump.wav',
        'land.wav',
        'sword_slash.wav',
        'arrow_shot.wav',
        'fireball.wav',
      ]);

      print('✅ AudioSystem: SFX preloaded');
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ AudioSystem: Failed to preload audio: $e');
      }
    }
  }

  // ==========================================
  // EVENT HANDLERS
  // ==========================================

  void _onPlaySFX(PlaySFXEvent event) {
    playSFX(event.soundId, volume: event.volume);
  }

  void _onPlayMusic(PlayMusicEvent event) {
    playMusic(event.musicId, volume: event.volume, loop: event.loop);
  }

  void _onStopMusic(StopMusicEvent event) {
    stopMusic();
  }

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
    // Low health warning sound
    if (event.healthPercent < 0.3 && event.healthPercent > 0) {
      playSFX('low_health', volume: 0.7);
    }
  }

  void _onDeath(CharacterKilledEvent event) {
    playSFX('death', volume: 1.0);
  }

  void _onWaveStarted(WaveStartedEvent event) {
    // Boss wave music
    if (event.waveNumber % 5 == 0) {
      playMusic('boss_theme', volume: 0.7);
    }
  }

  void _onWaveCompleted(WaveCompletedEvent event) {
    playSFX('wave_complete', volume: 0.9);

    if (event.perfectClear) {
      playSFX('perfect_clear', volume: 1.0);
    }
  }

  void _onItemPickup(ItemPickedUpEvent event) {
    playSFX('item_pickup', volume: 0.6);
  }

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

  /// Play sound effect
  void playSFX(String soundId, {double volume = 1.0}) {
    if (!_sfxEnabled) return;

    // Check if sound was recently played (prevent spam)
    final lastPlayed = _lastPlayed[soundId];
    if (lastPlayed != null) {
      final elapsed = DateTime.now().difference(lastPlayed);
      if (elapsed < _minSoundInterval) {
        return; // Too soon, skip
      }
    }

    try {
      FlameAudio.play(
        '$soundId.wav',
        volume: volume * _sfxVolume * GameConfig.masterVolume,
      );
      _lastPlayed[soundId] = DateTime.now();

      if (kDebugMode) {
        print('🔊 Playing SFX: $soundId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to play SFX: $soundId - $e');
      }
    }
  }

  /// Play background music
  void playMusic(String musicId, {double volume = 0.6, bool loop = true}) {
    if (!_musicEnabled) return;

    // Don't restart same music
    if (_currentMusic == musicId) return;

    try {
      FlameAudio.bgm.play(
        '$musicId.mp3',
        volume: volume * _musicVolume * GameConfig.masterVolume,
      );
      _currentMusic = musicId;

      if (kDebugMode) {
        print('🎵 Playing music: $musicId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to play music: $musicId - $e');
      }
    }
  }

  /// Stop current music
  void stopMusic() {
    FlameAudio.bgm.stop();
    _currentMusic = null;

    if (kDebugMode) {
      print('⏹️  Music stopped');
    }
  }

  /// Pause music
  void pauseMusic() {
    FlameAudio.bgm.pause();
  }

  /// Resume music
  void resumeMusic() {
    FlameAudio.bgm.resume();
  }

  // ==========================================
  // VOLUME CONTROL
  // ==========================================

  /// Set music volume (0.0 to 1.0)
  void setMusicVolume(double volume) {
    _musicVolume = volume.clamp(0.0, 1.0);
    FlameAudio.bgm.audioPlayer.setVolume(
        _musicVolume * GameConfig.masterVolume
    );

    if (kDebugMode) {
      print('🔊 Music volume: ${(_musicVolume * 100).toInt()}%');
    }
  }

  /// Set SFX volume (0.0 to 1.0)
  void setSFXVolume(double volume) {
    _sfxVolume = volume.clamp(0.0, 1.0);

    if (kDebugMode) {
      print('🔊 SFX volume: ${(_sfxVolume * 100).toInt()}%');
    }
  }

  /// Toggle music on/off
  void toggleMusic() {
    _musicEnabled = !_musicEnabled;

    if (!_musicEnabled) {
      stopMusic();
    }

    if (kDebugMode) {
      print('🎵 Music ${_musicEnabled ? "enabled" : "disabled"}');
    }
  }

  /// Toggle SFX on/off
  void toggleSFX() {
    _sfxEnabled = !_sfxEnabled;

    if (kDebugMode) {
      print('🔊 SFX ${_sfxEnabled ? "enabled" : "disabled"}');
    }
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

  /// Dispose audio system
  void dispose() {
    // Cancel subscriptions
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    // Stop all audio
    stopMusic();
    FlameAudio.audioCache.clearAll();

    print('🗑️  AudioSystem: Disposed');
  }
}

// ==========================================
// AUDIO CONFIGURATION
// ==========================================

/// Audio file mappings
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
    'battle_theme': 'battle_theme.mp3',
    'boss_theme': 'boss_theme.mp3',
    'victory_theme': 'victory_theme.mp3',
  };
}