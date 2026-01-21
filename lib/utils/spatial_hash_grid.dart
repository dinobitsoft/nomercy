import 'package:flame/components.dart';

class SpatialHashGrid<T> {
  final double cellSize;
  final Map<int, Set<T>> _grid = {};
  final Map<T, Set<int>> _objectToCells = {};

  SpatialHashGrid({this.cellSize = 200.0});

  /// Insert object into grid
  void insert(T object, Vector2 position, Vector2 size) {
    final cells = _getCells(position, size);

    // Remove from old cells if exists
    remove(object);

    // Add to new cells
    _objectToCells[object] = cells;
    for (final cellKey in cells) {
      _grid.putIfAbsent(cellKey, () => <T>{});
      _grid[cellKey]!.add(object);
    }
  }

  /// Remove object from grid
  void remove(T object) {
    final cells = _objectToCells[object];
    if (cells == null) return;

    for (final cellKey in cells) {
      _grid[cellKey]?.remove(object);
      if (_grid[cellKey]?.isEmpty ?? false) {
        _grid.remove(cellKey);
      }
    }
    _objectToCells.remove(object);
  }

  /// Get potential collision candidates near position
  Set<T> getNearby(Vector2 position, Vector2 size) {
    final cells = _getCells(position, size);
    final nearby = <T>{};

    for (final cellKey in cells) {
      final cellObjects = _grid[cellKey];
      if (cellObjects != null) {
        nearby.addAll(cellObjects);
      }
    }

    return nearby;
  }

  /// Clear all objects from grid
  void clear() {
    _grid.clear();
    _objectToCells.clear();
  }

  /// Get cell keys for object bounds
  Set<int> _getCells(Vector2 position, Vector2 size) {
    final cells = <int>{};

    final minX = ((position.x - size.x / 2) / cellSize).floor();
    final maxX = ((position.x + size.x / 2) / cellSize).floor();
    final minY = ((position.y - size.y / 2) / cellSize).floor();
    final maxY = ((position.y + size.y / 2) / cellSize).floor();

    for (int x = minX; x <= maxX; x++) {
      for (int y = minY; y <= maxY; y++) {
        cells.add(_hashCell(x, y));
      }
    }

    return cells;
  }

  /// Hash cell coordinates to unique key
  int _hashCell(int x, int y) {
    // Cantor pairing function for unique hash
    return ((x + y) * (x + y + 1) ~/ 2) + y;
  }

  /// Get grid statistics
  Map<String, int> getStats() {
    return {
      'totalCells': _grid.length,
      'totalObjects': _objectToCells.length,
      'averageObjectsPerCell': _grid.isEmpty
          ? 0
          : (_grid.values.fold(0, (sum, set) => sum + set.length) / _grid.length).round(),
    };
  }
}

// lib/systems/collision_system.dart

/// Optimized collision detection using spatial partitioning
