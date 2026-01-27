import 'item.dart';

class ItemData {
  final int id;
  final String type; // 'healthPotion', 'weapon'
  final double x;
  final double y;
  final String? weaponId; // If type is weapon, which weapon

  ItemData({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    this.weaponId,
  });

  factory ItemData.fromJson(Map<String, dynamic> json) {
    return ItemData(
      id: json['id'] ?? 0,
      type: json['type'] ?? 'healthPotion',
      x: (json['x'] ?? 0).toDouble(),
      y: (json['y'] ?? 0).toDouble(),
      weaponId: json['weaponId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'x': x,
      'y': y,
      if (weaponId != null) 'weaponId': weaponId,
    };
  }

  Item toItem() {
    if (type == 'healthPotion') {
      return HealthPotion();
    } else if (type == 'weapon' && weaponId != null) {
      // Find weapon by ID
      final weapons = Weapon.getAllWeapons();
      return weapons.firstWhere(
            (w) => w.id == weaponId,
        orElse: () => Weapon.ironSword(),
      );
    }
    return HealthPotion(); // Default
  }
}