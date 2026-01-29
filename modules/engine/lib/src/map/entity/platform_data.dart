class PlatformData {
  final int id;
  final String type; // 'brick', 'ground'
  final double x;
  final double y;
  final double width;
  final double height;

  PlatformData({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory PlatformData.fromJson(Map<String, dynamic> json) {
    return PlatformData(
      id: json['id'] ?? 0,
      type: json['type'] ?? 'brick',
      x: (json['x'] ?? 0).toDouble(),
      y: (json['y'] ?? 0).toDouble(),
      width: (json['width'] ?? 120).toDouble(),
      height: (json['height'] ?? 20).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    };
  }
}