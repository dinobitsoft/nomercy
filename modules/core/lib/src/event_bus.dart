// lib/core/events/event_bus.dart

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'events/game_event.dart';

/// Event listener callback type
typedef EventCallback<T extends GameEvent> = void Function(T event);

/// Event subscription handle (for cleanup)
class EventSubscription {
  final String id;
  final VoidCallback _unsubscribe;

  EventSubscription._(this.id, this._unsubscribe);

  /// Unsubscribe from event
  void cancel() => _unsubscribe();
}

/// Priority levels for event listeners
enum ListenerPriority {
  lowest(0),
  low(25),
  normal(50),
  high(75),
  highest(100);

  final int value;
  const ListenerPriority(this.value);
}

/// Event listener wrapper
class _EventListener {
  final String id;
  final void Function(GameEvent) callback;
  final ListenerPriority priority;
  final bool once; // Auto-unsubscribe after first trigger

  _EventListener({
    required this.id,
    required this.callback,
    required this.priority,
    this.once = false,
  });
}

/// Central event bus for game-wide communication
/// Singleton pattern ensures single source of truth
class EventBus {
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  EventBus._internal();

  // Stream controller for reactive programming
  final StreamController<GameEvent> _streamController =
  StreamController<GameEvent>.broadcast();

  // Listener storage: Type -> List of listeners
  final Map<Type, List<_EventListener>> _listeners = {};

  // Event history for debugging
  final Queue<GameEvent> _eventHistory = Queue();
  final int _maxHistorySize = 200;

  // Statistics
  int _totalEventsEmitted = 0;
  final Map<Type, int> _eventCounts = {};

  // Paused state
  bool _isPaused = false;
  final Queue<GameEvent> _queuedEvents = Queue();

  // ==========================================
  // SUBSCRIPTION METHODS
  // ==========================================

  /// Subscribe to specific event type with callback
  EventSubscription on<T extends GameEvent>(
      EventCallback<T> callback, {
        ListenerPriority priority = ListenerPriority.normal,
        bool once = false,
      }) {
    final type = T;
    final listenerId = '${type}_${DateTime.now().millisecondsSinceEpoch}';

    // Create listener with a wrapped callback to avoid type mismatch
    final listener = _EventListener(
      id: listenerId,
      callback: (GameEvent event) {
        if (event is T) {
          callback(event);
        }
      },
      priority: priority,
      once: once,
    );

    // Add to listeners map
    _listeners.putIfAbsent(type, () => []);
    _listeners[type]!.add(listener);

    // Sort by priority (highest first)
    _listeners[type]!.sort((a, b) => b.priority.value.compareTo(a.priority.value));

    if (kDebugMode) {
      print('📢 EventBus: Subscribed to $type (priority: ${priority.name})');
    }

    // Return subscription handle
    return EventSubscription._(listenerId, () => _unsubscribe<T>(listenerId));
  }

  /// Subscribe to event (triggers only once)
  EventSubscription once<T extends GameEvent>(EventCallback<T> callback) {
    return on<T>(callback, once: true);
  }

  /// Unsubscribe specific listener
  void _unsubscribe<T extends GameEvent>(String listenerId) {
    final type = T;
    final listeners = _listeners[type];
    if (listeners == null) return;

    listeners.removeWhere((listener) => listener.id == listenerId);

    if (listeners.isEmpty) {
      _listeners.remove(type);
    }

    if (kDebugMode) {
      print('🔇 EventBus: Unsubscribed from $type');
    }
  }

  /// Remove all listeners for a specific type
  void offAll<T extends GameEvent>() {
    _listeners.remove(T);
    if (kDebugMode) {
      print('🔇 EventBus: Removed all listeners for $T');
    }
  }

  /// Remove ALL listeners (use carefully!)
  void clearAllListeners() {
    _listeners.clear();
    if (kDebugMode) {
      print('🔇 EventBus: Cleared ALL listeners');
    }
  }

  // ==========================================
  // EMISSION METHODS
  // ==========================================

  /// Emit an event to all subscribers
  void emit<T extends GameEvent>(T event) {
    // If paused, queue the event
    if (_isPaused) {
      _queuedEvents.add(event);
      return;
    }

    _processEvent(event);
  }

  /// Internal event processing
  void _processEvent(GameEvent event) {
    // Update statistics
    _totalEventsEmitted++;
    _eventCounts[event.runtimeType] = (_eventCounts[event.runtimeType] ?? 0) + 1;

    // Add to history
    _eventHistory.add(event);
    if (_eventHistory.length > _maxHistorySize) {
      _eventHistory.removeFirst();
    }

    // Broadcast to stream
    _streamController.add(event);

    // Call typed listeners
    final listeners = _listeners[event.runtimeType];
    if (listeners != null) {
      // Create copy to avoid concurrent modification
      final listenersCopy = List<_EventListener>.from(listeners);
      final onceListeners = <String>[];

      for (final listener in listenersCopy) {
        try {
          listener.callback(event);

          // Track once listeners for removal
          if (listener.once) {
            onceListeners.add(listener.id);
          }
        } catch (e, stackTrace) {
          if (kDebugMode) {
            print('❌ EventBus: Error in listener for ${event.runtimeType}');
            print('   Error: $e');
            print('   Stack: $stackTrace');
          }
        }
      }

      // Remove once listeners
      if (onceListeners.isNotEmpty) {
        listeners.removeWhere((l) => onceListeners.contains(l.id));
      }
    }

    if (kDebugMode) {
      print('📤 EventBus: Emitted ${event.runtimeType}');
    }
  }

  // ==========================================
  // STREAM METHODS (Reactive Programming)
  // ==========================================

  /// Get stream of specific event type
  Stream<T> stream<T extends GameEvent>() {
    return _streamController.stream
        .where((event) => event is T)
        .cast<T>();
  }

  /// Get stream of all events
  Stream<GameEvent> get allEvents => _streamController.stream;

  // ==========================================
  // PAUSE/RESUME
  // ==========================================

  /// Pause event processing (events are queued)
  void pause() {
    _isPaused = true;
    if (kDebugMode) {
      print('⏸️  EventBus: Paused');
    }
  }

  /// Resume event processing and emit queued events
  void resume() {
    _isPaused = false;

    // Emit queued events
    while (_queuedEvents.isNotEmpty) {
      final event = _queuedEvents.removeFirst();
      _processEvent(event);
    }

    if (kDebugMode) {
      print('▶️  EventBus: Resumed');
    }
  }

  // ==========================================
  // HISTORY & DEBUGGING
  // ==========================================

  /// Get event history (optional filter by type)
  List<GameEvent> getHistory<T extends GameEvent>() {
    if (T == GameEvent) {
      return List.unmodifiable(_eventHistory);
    }
    return _eventHistory.whereType<T>().toList();
  }

  /// Get last N events
  List<GameEvent> getRecentEvents(int count) {
    if (_eventHistory.length <= count) {
      return List.unmodifiable(_eventHistory);
    }
    return _eventHistory.toList().sublist(_eventHistory.length - count);
  }

  /// Clear event history
  void clearHistory() {
    _eventHistory.clear();
    if (kDebugMode) {
      print('🧹 EventBus: History cleared');
    }
  }

  // ==========================================
  // STATISTICS
  // ==========================================

  /// Get total events emitted
  int get totalEvents => _totalEventsEmitted;

  /// Get event count by type
  int getEventCount<T extends GameEvent>() {
    return _eventCounts[T] ?? 0;
  }

  /// Get all event counts
  Map<Type, int> get eventCounts => Map.unmodifiable(_eventCounts);

  /// Get number of active listeners
  int get listenerCount {
    return _listeners.values.fold(0, (sum, list) => sum + list.length);
  }

  /// Get listener count for specific type
  int getListenerCount<T extends GameEvent>() {
    return _listeners[T]?.length ?? 0;
  }

  /// Print statistics
  void printStats() {
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📊 EVENT BUS STATISTICS');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('Total Events: $_totalEventsEmitted');
    print('Active Listeners: $listenerCount');
    print('Event History Size: ${_eventHistory.length}');
    print('Paused: $_isPaused');
    print('Queued Events: ${_queuedEvents.length}');
    print('\nTop Event Types:');

    final sortedCounts = _eventCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (var i = 0; i < sortedCounts.length && i < 10; i++) {
      final entry = sortedCounts[i];
      print('  ${i + 1}. ${entry.key}: ${entry.value}');
    }
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  }

  /// Generate debug report
  String generateReport() {
    final buffer = StringBuffer();
    buffer.writeln('EventBus Report');
    buffer.writeln('Total Events: $_totalEventsEmitted');
    buffer.writeln('Active Listeners: $listenerCount');
    buffer.writeln('Recent Events (last 10):');

    final recent = getRecentEvents(10);
    for (final event in recent) {
      buffer.writeln('  - $event');
    }

    return buffer.toString();
  }

  // ==========================================
  // CLEANUP
  // ==========================================

  /// Dispose of event bus (call on game shutdown)
  void dispose() {
    _streamController.close();
    _listeners.clear();
    _eventHistory.clear();
    _queuedEvents.clear();
    _eventCounts.clear();

    if (kDebugMode) {
      print('🗑️  EventBus: Disposed');
    }
  }

  /// Reset event bus to initial state
  void reset() {
    clearAllListeners();
    clearHistory();
    _totalEventsEmitted = 0;
    _eventCounts.clear();
    _queuedEvents.clear();
    _isPaused = false;

    if (kDebugMode) {
      print('🔄 EventBus: Reset');
    }
  }
}

// ==========================================
// HELPER EXTENSIONS
// ==========================================

/// Extension for easy event emission
extension EmitEventExtension on GameEvent {
  /// Emit this event to the bus
  void emit() => EventBus().emit(this);
}

/// Extension for StreamSubscription to EventSubscription conversion
extension StreamToEventSubscription on StreamSubscription<GameEvent> {
  EventSubscription toEventSubscription() {
    return EventSubscription._(
      'stream_${DateTime.now().millisecondsSinceEpoch}',
      cancel,
    );
  }
}