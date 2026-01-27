class ChestData {
  final int id;
  final String type;
  final double x;
  final double y;
  final bool opened;

  ChestData({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    this.opened = false,
  });

  factory ChestData.fromJson(Map<String, dynamic> json) {
    return ChestData(
      id: json['id'] ?? 0,
      type: json['type'] ?? 'chest',
      x: (json['x'] ?? 0).toDouble(),
      y: (json['y'] ?? 0).toDouble(),
      opened: json['opened'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'x': x,
      'y': y,
      'opened': opened,
    };
  }
}