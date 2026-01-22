// lib/managers/pool_manager.dart

import '../entities/projectile/poolable_projectile.dart';

/// Generic object pool for frequently created/destroyed objects
/// Reduces garbage collection overhead significantly
class ObjectPool<T> {
  final List<T> _available = [];
  final Set<T> _inUse = {};
  final T Function() _factory;
  final void Function(T)? _reset;
  final int _initialSize;
  final int _maxSize;

  ObjectPool({
    required T Function() factory,
    void Function(T)? reset,
    int initialSize = 10,
    int maxSize = 100,
  })  : _factory = factory,
        _reset = reset,
        _initialSize = initialSize,
        _maxSize = maxSize {
    _prewarm();
  }

  /// Pre-create objects for faster initial access
  void _prewarm() {
    for (int i = 0; i < _initialSize; i++) {
      _available.add(_factory());
    }
  }

  /// Get object from pool (reuse or create new)
  T obtain() {
    T object;

    if (_available.isNotEmpty) {
      object = _available.removeLast();
    } else if (_inUse.length < _maxSize) {
      object = _factory();
    } else {
      throw Exception('Pool exhausted! Max size: $_maxSize');
    }

    _inUse.add(object);
    return object;
  }

  /// Return object to pool for reuse
  void release(T object) {
    if (!_inUse.contains(object)) {
      return; // Already released or never obtained
    }

    _inUse.remove(object);

    // Reset object state before returning to pool
    if (_reset != null) {
      _reset!(object);
    }

    if (_available.length < _maxSize) {
      _available.add(object);
    }
  }

  /// Release all objects currently in use
  void releaseAll() {
    _available.addAll(_inUse);
    _inUse.clear();
  }

  /// Clear pool completely
  void clear() {
    _available.clear();
    _inUse.clear();
  }

  /// Pool statistics
  int get activeCount => _inUse.length;
  int get availableCount => _available.length;
  int get totalCount => activeCount + availableCount;
  double get utilization => totalCount == 0 ? 0.0 : activeCount / totalCount;
}

/// Centralized manager for all object pools
class PoolManager {
  static final PoolManager _instance = PoolManager._internal();
  factory PoolManager() => _instance;
  PoolManager._internal();

  final Map<Type, ObjectPool> _pools = {};

  /// Register a pool for a specific type
  void registerPool<T>(ObjectPool<T> pool) {
    _pools[T] = pool;
  }

  /// Get pool for a specific type
  ObjectPool<T> getPool<T>() {
    final pool = _pools[T];
    if (pool == null) {
      throw Exception('No pool registered for type: $T');
    }
    return pool as ObjectPool<T>;
  }

  /// Quick obtain from registered pool
  T obtain<T>() => getPool<T>().obtain();

  /// Quick release to registered pool
  void release<T>(T object) => getPool<T>().release(object);

  /// Print pool statistics
  void printStats() {
    print('\n📊 Object Pool Statistics:');
    _pools.forEach((type, pool) {
      print('  $type: ${pool.activeCount}/${pool.totalCount} '
          '(${(pool.utilization * 100).toStringAsFixed(1)}% used)');
    });
  }

  /// Clear all pools
  void clearAll() {
    _pools.values.forEach((pool) => pool.clear());
    print('🧹 All object pools cleared');
  }
}

/// Initialize projectile pool at game start
void initializeProjectilePool() {
  final projectilePool = ObjectPool<PoolableProjectile>(
    factory: () => PoolableProjectile(),
    reset: null, // Reset handled by PoolableProjectile.reset()
    initialSize: 20,
    maxSize: 100,
  );

  PoolManager().registerPool(projectilePool);
  print('✅ Projectile pool initialized (20-100 objects)');
}