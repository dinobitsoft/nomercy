// lib/util/performance_monitor.dart

import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Performance monitoring and profiling
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  // Frame timing
  final Queue<double> _frameTimes = Queue();
  final int _sampleSize = 60; // Track last 60 frames
  double _lastFrameTime = 0;
  int _frameCount = 0;

  // Performance metrics
  double _currentFPS = 0;
  double _averageFPS = 0;
  double _minFPS = double.infinity;
  double _maxFPS = 0;

  // Memory tracking
  int _currentMemory = 0;
  int _peakMemory = 0;

  // Custom timers
  final Map<String, _Timer> _timers = {};
  final Map<String, Queue<double>> _timerHistory = {};

  /// Record frame time
  void recordFrame(double dt) {
    _frameTimes.add(dt);
    _frameCount++;

    if (_frameTimes.length > _sampleSize) {
      _frameTimes.removeFirst();
    }

    // Calculate FPS
    if (dt > 0) {
      _currentFPS = 1.0 / dt;
      _minFPS = math.min(_minFPS, _currentFPS);
      _maxFPS = math.max(_maxFPS, _currentFPS);

      // Average FPS over samples
      final avgDt = _frameTimes.reduce((a, b) => a + b) / _frameTimes.length;
      _averageFPS = 1.0 / avgDt;
    }
  }

  /// Start timing a code section
  void startTimer(String name) {
    _timers[name] = _Timer()..start();
  }

  /// Stop timing a code section
  void stopTimer(String name) {
    final timer = _timers[name];
    if (timer == null || !timer.isRunning) return;

    timer.stop();

    // Store in history
    _timerHistory.putIfAbsent(name, () => Queue());
    _timerHistory[name]!.add(timer.elapsedMilliseconds);

    if (_timerHistory[name]!.length > _sampleSize) {
      _timerHistory[name]!.removeFirst();
    }
  }

  /// Get average time for a timer
  double getAverageTime(String name) {
    final history = _timerHistory[name];
    if (history == null || history.isEmpty) return 0;

    return history.reduce((a, b) => a + b) / history.length;
  }

  /// Update memory usage (call periodically)
  void updateMemory() {
    // In production, use dart:developer's getCurrentMemoryUsage
    // For now, simulate
    _currentMemory = 0; // Placeholder
    _peakMemory = math.max(_peakMemory, _currentMemory);
  }

  /// Get FPS
  double get fps => _currentFPS;
  double get avgFPS => _averageFPS;
  double get minFPS => _minFPS;
  double get maxFPS => _maxFPS;

  /// Get frame time in ms
  double get frameTimeMs => _frameTimes.isEmpty ? 0 : _frameTimes.last * 1000;
  double get avgFrameTimeMs =>
      _frameTimes.isEmpty ? 0 : (_frameTimes.reduce((a, b) => a + b) / _frameTimes.length) * 1000;

  /// Get memory
  int get currentMemoryMB => (_currentMemory / 1024 / 1024).round();
  int get peakMemoryMB => (_peakMemory / 1024 / 1024).round();

  /// Check if performance is degraded
  bool get isPerformanceDegraded => _currentFPS < 30;
  bool get isFrameTimeHigh => frameTimeMs > 33.33; // 30 FPS threshold

  /// Generate performance report
  String generateReport() {
    final buffer = StringBuffer();
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📊 PERFORMANCE REPORT');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('Frame Count: $_frameCount');
    buffer.writeln('Current FPS: ${_currentFPS.toStringAsFixed(1)}');
    buffer.writeln('Average FPS: ${_averageFPS.toStringAsFixed(1)}');
    buffer.writeln('Min FPS: ${_minFPS.toStringAsFixed(1)}');
    buffer.writeln('Max FPS: ${_maxFPS.toStringAsFixed(1)}');
    buffer.writeln('Frame Time: ${frameTimeMs.toStringAsFixed(2)}ms');
    buffer.writeln('Avg Frame Time: ${avgFrameTimeMs.toStringAsFixed(2)}ms');

    if (_timers.isNotEmpty) {
      buffer.writeln('\n⏱️  TIMERS:');
      _timerHistory.forEach((name, history) {
        final avg = history.reduce((a, b) => a + b) / history.length;
        buffer.writeln('  $name: ${avg.toStringAsFixed(2)}ms');
      });
    }

    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    return buffer.toString();
  }

  /// Reset all metrics
  void reset() {
    _frameTimes.clear();
    _frameCount = 0;
    _currentFPS = 0;
    _averageFPS = 0;
    _minFPS = double.infinity;
    _maxFPS = 0;
    _timers.clear();
    _timerHistory.clear();
  }

  /// Print current stats (debug)
  void printStats() {
    if (kDebugMode) {
      print(generateReport());
    }
  }
}

/// Timer helper class
class _Timer {
  DateTime? _startTime;
  DateTime? _stopTime;

  void start() {
    _startTime = DateTime.now();
    _stopTime = null;
  }

  void stop() {
    _stopTime = DateTime.now();
  }

  bool get isRunning => _startTime != null && _stopTime == null;

  double get elapsedMilliseconds {
    if (_startTime == null) return 0;
    final end = _stopTime ?? DateTime.now();
    return end.difference(_startTime!).inMicroseconds / 1000.0;
  }
}

// lib/util/fps_counter.dart



// Usage in ActionGame:
/*
@override
void update(double dt) {
  super.update(dt);

  // Record frame for performance monitoring
  PerformanceMonitor().recordFrame(dt);

  // Time expensive operations
  PerformanceMonitor().startTimer('physics');
  // ... physics code ...
  PerformanceMonitor().stopTimer('physics');

  PerformanceMonitor().startTimer('ai');
  // ... AI code ...
  PerformanceMonitor().stopTimer('ai');
}

@override
Future<void> onLoad() async {
  // Add FPS counter in debug mode
  if (DebugConfig.showFPS) {
    camera.viewport.add(FPSCounter());
  }
}
*/