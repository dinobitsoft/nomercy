// THROWAWAY. Captures golden fixtures for the Godot port. Delete at cutover.
//
// Mirrors the damage pipeline in
// modules/engine/lib/src/system/combat_system.dart processAttack(), with the
// critical-hit RNG lifted out into an explicit parameter so the result is
// deterministic and portable across engines.
//
//   damage = base
//   if critical: damage *= BalanceConfig.criticalHitMultiplier   (2.0)
//   if combo > 0: damage *= 1.0 + combo * BalanceConfig.comboDamageMultiplier  (0.2)
//   if blocking: damage *= 0.3
//
// Order matters: critical is applied before combo, combo before block.

import 'dart:convert';
import 'dart:io';

import '../../../modules/core/lib/src/config/game_config.dart';

double calcDamage({
  required double base,
  required int combo,
  required bool blocking,
  required bool critical,
}) {
  var damage = base;
  if (critical) damage *= BalanceConfig.criticalHitMultiplier;
  if (combo > 0) {
    damage *= 1.0 + combo * BalanceConfig.comboDamageMultiplier;
  }
  if (blocking) damage *= 0.3;
  return damage;
}

void main() {
  // attackDamage per class, from the *Stats classes in
  // modules/engine/lib/src/components/character/
  const baseByClass = <String, double>{
    'knight': 15.0,
    'thief': 10.0,
    'wizard': 20.0,
    'trader': 12.0,
  };

  final records = <Map<String, dynamic>>[];

  for (final entry in baseByClass.entries) {
    for (var combo = 0; combo <= 5; combo++) {
      for (final blocking in [false, true]) {
        for (final critical in [false, true]) {
          records.add({
            'character': entry.key,
            'base': entry.value,
            'combo': combo,
            'blocking': blocking,
            'critical': critical,
            'expected': calcDamage(
              base: entry.value,
              combo: combo,
              blocking: blocking,
              critical: critical,
            ),
          });
        }
      }
    }
  }

  final out = File('../../godot/test/fixtures/combat_damage.json');
  out.parent.createSync(recursive: true);
  out.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(records),
  );

  stdout.writeln('Wrote ${records.length} records to ${out.path}');
}
