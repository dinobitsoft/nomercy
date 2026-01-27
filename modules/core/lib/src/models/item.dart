import 'package:flutter/material.dart';

enum ItemType {
  healthPotion,
  weapon,
  armor,
}

enum WeaponType {
  sword,
  bow,
  staff,
  dagger,
  axe,
  crossbow,
}

abstract class Item {
  final String id;
  final String name;
  final String description;
  final ItemType type;
  final int value; // Gold value
  final String iconAsset;

  Item({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.value,
    required this.iconAsset,
  });

  Map<String, dynamic> toJson();
}

class HealthPotion extends Item {
  final double healAmount;

  HealthPotion({
    super.id = 'health_potion',
    super.name = 'Health Potion',
    super.description = 'Restores health',
    super.value = 50,
    this.healAmount = 100.0,
  }) : super(
    type: ItemType.healthPotion,
    iconAsset: 'health_potion.png',
  );

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': 'healthPotion',
      'value': value,
      'healAmount': healAmount,
    };
  }

  factory HealthPotion.fromJson(Map<String, dynamic> json) {
    return HealthPotion(
      id: json['id'] ?? 'health_potion',
      name: json['name'] ?? 'Health Potion',
      description: json['description'] ?? 'Restores health',
      value: json['value'] ?? 50,
      healAmount: json['healAmount']?.toDouble() ?? 100.0,
    );
  }
}

class Weapon extends Item {
  final WeaponType weaponType;
  final double damage;
  final double range;
  final double attackSpeed; // Cooldown multiplier
  final String projectileType; // 'fireball', 'arrow', 'knife', etc.
  final Color projectileColor;

  // Stat bonuses
  final double powerBonus;
  final double magicBonus;
  final double dexterityBonus;
  final double intelligenceBonus;

  Weapon({
    required super.id,
    required super.name,
    required super.description,
    required this.weaponType,
    required this.damage,
    required this.range,
    required super.value,
    this.attackSpeed = 1.0,
    this.projectileType = 'projectile',
    this.projectileColor = Colors.grey,
    this.powerBonus = 0,
    this.magicBonus = 0,
    this.dexterityBonus = 0,
    this.intelligenceBonus = 0,
  }) : super(
    type: ItemType.weapon,
    iconAsset: '${weaponType.name}_icon.png',
  );

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': 'weapon',
      'weaponType': weaponType.name,
      'damage': damage,
      'range': range,
      'value': value,
      'attackSpeed': attackSpeed,
      'projectileType': projectileType,
      'projectileColor': projectileColor.value,
      'powerBonus': powerBonus,
      'magicBonus': magicBonus,
      'dexterityBonus': dexterityBonus,
      'intelligenceBonus': intelligenceBonus,
    };
  }

  factory Weapon.fromJson(Map<String, dynamic> json) {
    return Weapon(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      weaponType: WeaponType.values.firstWhere(
            (e) => e.name == json['weaponType'],
        orElse: () => WeaponType.sword,
      ),
      damage: json['damage'].toDouble(),
      range: json['range'].toDouble(),
      value: json['value'],
      attackSpeed: json['attackSpeed']?.toDouble() ?? 1.0,
      projectileType: json['projectileType'] ?? 'projectile',
      projectileColor: Color(json['projectileColor'] ?? Colors.grey.value),
      powerBonus: json['powerBonus']?.toDouble() ?? 0,
      magicBonus: json['magicBonus']?.toDouble() ?? 0,
      dexterityBonus: json['dexterityBonus']?.toDouble() ?? 0,
      intelligenceBonus: json['intelligenceBonus']?.toDouble() ?? 0,
    );
  }

  // Predefined weapons
  static Weapon ironSword() => Weapon(
    id: 'iron_sword',
    name: 'Iron Sword',
    description: 'A basic iron sword',
    weaponType: WeaponType.sword,
    damage: 15,
    range: 2.0,
    value: 100,
    powerBonus: 5,
  );

  static Weapon flamingSword() => Weapon(
    id: 'flaming_sword',
    name: 'Flaming Sword',
    description: 'A sword wreathed in flames',
    weaponType: WeaponType.sword,
    damage: 25,
    range: 2.5,
    value: 250,
    powerBonus: 10,
    magicBonus: 5,
  );

  static Weapon hunterBow() => Weapon(
    id: 'hunter_bow',
    name: 'Hunter\'s Bow',
    description: 'A precise hunting bow',
    weaponType: WeaponType.bow,
    damage: 18,
    range: 12.0,
    value: 150,
    projectileType: 'arrow',
    projectileColor: Colors.brown,
    dexterityBonus: 8,
  );

  static Weapon elvenBow() => Weapon(
    id: 'elven_bow',
    name: 'Elven Bow',
    description: 'An elegant elven masterpiece',
    weaponType: WeaponType.bow,
    damage: 28,
    range: 15.0,
    value: 350,
    attackSpeed: 0.8,
    projectileType: 'arrow',
    projectileColor: Colors.green,
    dexterityBonus: 15,
    intelligenceBonus: 5,
  );

  static Weapon fireStaff() => Weapon(
    id: 'fire_staff',
    name: 'Staff of Flames',
    description: 'Channels devastating fire magic',
    weaponType: WeaponType.staff,
    damage: 30,
    range: 10.0,
    value: 300,
    projectileType: 'fireball',
    projectileColor: Colors.orange,
    magicBonus: 15,
    intelligenceBonus: 10,
  );

  static Weapon iceStaff() => Weapon(
    id: 'ice_staff',
    name: 'Staff of Frost',
    description: 'Freezes enemies in their tracks',
    weaponType: WeaponType.staff,
    damage: 25,
    range: 10.0,
    value: 300,
    attackSpeed: 1.2,
    projectileType: 'iceball',
    projectileColor: Colors.cyan,
    magicBonus: 12,
    intelligenceBonus: 12,
  );

  static Weapon shadowDagger() => Weapon(
    id: 'shadow_dagger',
    name: 'Shadow Dagger',
    description: 'Strikes from the shadows',
    weaponType: WeaponType.dagger,
    damage: 20,
    range: 8.0,
    value: 200,
    attackSpeed: 0.6,
    projectileType: 'knife',
    projectileColor: Colors.black,
    dexterityBonus: 12,
    intelligenceBonus: 3,
  );

  static Weapon battleAxe() => Weapon(
    id: 'battle_axe',
    name: 'Battle Axe',
    description: 'A heavy weapon of war',
    weaponType: WeaponType.axe,
    damage: 35,
    range: 2.0,
    value: 250,
    attackSpeed: 1.5,
    powerBonus: 20,
  );

  static Weapon heavyCrossbow() => Weapon(
    id: 'heavy_crossbow',
    name: 'Heavy Crossbow',
    description: 'Powerful but slow',
    weaponType: WeaponType.crossbow,
    damage: 40,
    range: 14.0,
    value: 400,
    attackSpeed: 2.0,
    projectileType: 'bolt',
    projectileColor: Colors.grey,
    powerBonus: 10,
    dexterityBonus: 5,
  );

  static List<Weapon> getAllWeapons() => [
    ironSword(),
    flamingSword(),
    hunterBow(),
    elvenBow(),
    fireStaff(),
    iceStaff(),
    shadowDagger(),
    battleAxe(),
    heavyCrossbow(),
  ];
}