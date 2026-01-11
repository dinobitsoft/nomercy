import 'package:flutter/material.dart';

import '../../character_stats.dart';

class KnightStats extends CharacterStats {
  KnightStats() : super(
    name: 'Knight',
    power: 15,
    magic: 5,
    dexterity: 8,
    intelligence: 7,
    weaponName: 'Sword Slash',
    attackRange: 2.0,
    attackDamage: 15,
    color: Colors.blue,
  );
}

class ThiefStats extends CharacterStats {
  ThiefStats() : super(
    name: 'Thief',
    power: 8,
    magic: 6,
    dexterity: 16,
    intelligence: 10,
    weaponName: 'Throwing Knives',
    attackRange: 8.0,
    attackDamage: 10,
    color: Colors.green,
  );
}

class WizardStats extends CharacterStats {
  WizardStats() : super(
    name: 'Wizard',
    power: 6,
    magic: 18,
    dexterity: 7,
    intelligence: 14,
    weaponName: 'Fireball',
    attackRange: 10.0,
    attackDamage: 20,
    color: Colors.purple,
  );
}

class TraderStats extends CharacterStats {
  TraderStats() : super(
    name: 'Trader',
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