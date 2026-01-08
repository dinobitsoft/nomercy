import 'package:flutter/material.dart';

import 'character_class.dart';

class CharacterStats {
  final CharacterClass type;
  double power;
  double magic;
  double dexterity;
  double intelligence;
  int money;
  final String weaponName;
  final double attackRange;
  final double attackDamage;
  final Color color;

  CharacterStats({
    required this.type,
    required this.power,
    required this.magic,
    required this.dexterity,
    required this.intelligence,
    this.money = 100,
    required this.weaponName,
    required this.attackRange,
    required this.attackDamage,
    required this.color,
  });

  factory CharacterStats.fromClass(CharacterClass type) {
    switch (type) {
      case CharacterClass.knight:
        return CharacterStats(
          type: type,
          power: 15,
          magic: 5,
          dexterity: 8,
          intelligence: 7,
          weaponName: 'Sword Slash',
          attackRange: 2.0,
          attackDamage: 15,
          color: Colors.blue,
        );
      case CharacterClass.thief:
        return CharacterStats(
          type: type,
          power: 8,
          magic: 6,
          dexterity: 16,
          intelligence: 10,
          weaponName: 'Throwing Knives',
          attackRange: 8.0,
          attackDamage: 10,
          color: Colors.green,
        );
      case CharacterClass.wizard:
        return CharacterStats(
          type: type,
          power: 6,
          magic: 18,
          dexterity: 7,
          intelligence: 14,
          weaponName: 'Fireball',
          attackRange: 10.0,
          attackDamage: 20,
          color: Colors.purple,
        );
      case CharacterClass.trader:
        return CharacterStats(
          type: type,
          power: 10,
          magic: 7,
          dexterity: 12,
          intelligence: 11,
          weaponName: 'Bow & Arrow',
          attackRange: 12.0,
          attackDamage: 12,
          color: Colors.orange,
        );
    }
  }

  void upgradeStat(String stat) {
    if (money < 50) return;
    money -= 50;
    switch (stat) {
      case 'power':
        power += 5;
        break;
      case 'magic':
        magic += 5;
        break;
      case 'dexterity':
        dexterity += 5;
        break;
      case 'intelligence':
        intelligence += 5;
        break;
    }
  }
}