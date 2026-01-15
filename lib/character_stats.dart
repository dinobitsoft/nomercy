import 'package:flutter/material.dart';

abstract class CharacterStats {
  final String name;
  double power;
  double magic;
  double dexterity;
  double intelligence;
  int money;
  final String weaponName;
  final double attackRange;
  late final double attackDamage;
  final Color color;

  CharacterStats({
    required this.name,
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

  void upgradeStat(String stat) {
    if (money < 50) return;
    money -= 50;
    switch (stat) {
      case 'power':
        power += 5;
        attackDamage += 2;
        break;
      case 'magic':
        magic += 5;
        attackDamage += 1;
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