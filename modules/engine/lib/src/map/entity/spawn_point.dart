class SpawnPoint {
  final double x;
  final double y;

  SpawnPoint({required this.x, required this.y});

  factory SpawnPoint.fromJson(Map<String, dynamic> json) {
    return SpawnPoint(
      x: (json['x'] ?? 100).toDouble(),
      y: (json['y'] ?? 600).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'x': x, 'y': y};
  }
}