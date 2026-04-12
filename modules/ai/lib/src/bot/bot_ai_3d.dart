// modules/ai/lib/src/bot/bot_ai_3d.dart

import 'dart:math' as math;

import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';

/// Concrete 3D bot brain. Registered with [AiBotRegistry] via [AiModule.register].
class BotAI3D implements BotController3D {
  final BotPersonality3D personality;

  double _decisionTimer      = 0;
  double _strafeSwitchTimer  = 0;
  double _stuckTimer         = 0;
  double _retreatTimer       = 0;
  double _jumpCooldown       = 0;

  double _strafeDir = 1.0;

  late final double _decisionInterval;
  late final double _engageRange;
  late final double _attackRange;
  late final double _retreatRange;
  late final bool   _prefersRanged;

  static const double _strafeSwitchInterval = 2.2;
  static const double _stuckThreshold       = 0.28;
  static const double _jumpCooldownTime     = 0.6;
  static const double _stuckSpeedThreshold  = 45.0;

  BotAI3D(this.personality) {
    switch (personality) {
      case BotPersonality3D.aggressor:
        _decisionInterval = 0.10;
        _engageRange      = 40.0;
        _attackRange      = GameConfig3D.attackRangeZ + 80;
        _retreatRange     = 0.0;
        _prefersRanged    = false;

      case BotPersonality3D.flanker:
        _decisionInterval = 0.14;
        _engageRange      = 160.0;
        _attackRange      = GameConfig3D.attackRangeZ + 50;
        _retreatRange     = 70.0;
        _prefersRanged    = false;

      case BotPersonality3D.ranged:
        _decisionInterval = 0.18;
        _engageRange      = 380.0;
        _attackRange      = 520.0;
        _retreatRange     = 220.0;
        _prefersRanged    = true;

      case BotPersonality3D.coward:
        _decisionInterval = 0.20;
        _engageRange      = 300.0;
        _attackRange      = 400.0;
        _retreatRange     = 180.0;
        _prefersRanged    = true;
    }
  }

  @override
  void update(GameCharacter3D bot, MovementStrategy3D strategy, double dt) {
    _decisionTimer     += dt;
    _strafeSwitchTimer += dt;
    if (_retreatTimer > 0) _retreatTimer -= dt;
    if (_jumpCooldown > 0) _jumpCooldown -= dt;

    if (_strafeSwitchTimer >= _strafeSwitchInterval) {
      _strafeDir         = -_strafeDir;
      _strafeSwitchTimer = 0;
    }

    final player = bot.game.character;
    if (player.characterState.health <= 0) return;

    final dx   = player.worldPos.x - bot.worldPos.x;
    final dz   = player.worldPos.z - bot.worldPos.z;
    final dist = math.sqrt(dx * dx + dz * dz);

    _checkStuck(bot, dist, dt);

    if (_decisionTimer < _decisionInterval) return;
    _decisionTimer = 0;

    _decide(bot, strategy, dx, dz, dist);
  }

  @override
  void onDamageTaken(GameCharacter3D bot, double damage) {
    switch (personality) {
      case BotPersonality3D.aggressor:
        _decisionTimer = _decisionInterval;
      case BotPersonality3D.flanker:
        if (damage >= 10) _retreatTimer = 0.45;
      case BotPersonality3D.ranged:
        _retreatTimer = math.max(_retreatTimer, 0.80);
      case BotPersonality3D.coward:
        _retreatTimer = math.max(_retreatTimer, 1.40);
        _strafeDir    = -_strafeDir;
    }
  }

  void _decide(GameCharacter3D bot, MovementStrategy3D strategy,
      double dx, double dz, double dist) {
    if (_retreatTimer > 0) { _doRetreat(bot, strategy, dx, dz); return; }
    switch (personality) {
      case BotPersonality3D.aggressor: _aggressorTick(bot, strategy, dx, dz, dist);
      case BotPersonality3D.flanker:   _flankerTick(bot, strategy, dx, dz, dist);
      case BotPersonality3D.ranged:    _rangedTick(bot, strategy, dx, dz, dist);
      case BotPersonality3D.coward:    _cowardTick(bot, strategy, dx, dz, dist);
    }
    _tryAttack(bot, dist);
  }

  void _aggressorTick(GameCharacter3D bot, MovementStrategy3D strategy,
      double dx, double dz, double dist) {
    if (dist > _engageRange) _doChase(bot, strategy, dx, dz, dist, run: true);
    _tryHeightJump(bot);
  }

  void _flankerTick(GameCharacter3D bot, MovementStrategy3D strategy,
      double dx, double dz, double dist) {
    if (dist < _retreatRange) { _doRetreat(bot, strategy, dx, dz); return; }
    if (dist > _engageRange) {
      final norm = math.max(dist, 1.0);
      final toX  = dx / norm; final toZ = dz / norm;
      final sx   = toX * 0.60 + (-toZ) * 0.40 * _strafeDir;
      final sz   = toZ * 0.60 + ( toX) * 0.40 * _strafeDir;
      _applyInput(bot, strategy, Vector2(sx, -sz), run: dist > 320);
    } else {
      final norm = math.max(dist, 1.0);
      _applyInput(bot, strategy, Vector2(-dz / norm * _strafeDir, 0), run: false);
    }
    _tryHeightJump(bot);
  }

  void _rangedTick(GameCharacter3D bot, MovementStrategy3D strategy,
      double dx, double dz, double dist) {
    if (dist < _retreatRange) { _doRetreat(bot, strategy, dx, dz); return; }
    if (dist > _engageRange) {
      _doChase(bot, strategy, dx, dz, dist, run: dist > 600);
    } else {
      final norm     = math.max(dist, 1.0);
      final sideX    = -dz / norm * _strafeDir;
      final zCorrect = (dist - _engageRange) / _engageRange;
      _applyInput(bot, strategy,
          Vector2(sideX * 0.8, -(dz / norm * zCorrect * 0.4)), run: false);
    }
  }

  void _cowardTick(GameCharacter3D bot, MovementStrategy3D strategy,
      double dx, double dz, double dist) {
    if (dist < _retreatRange) { _doRetreat(bot, strategy, dx, dz); return; }
    final playerBusy = bot.game.character.characterState.isAttacking ||
        bot.game.character.characterState.isAirborne;
    if (dist > _engageRange) {
      if (playerBusy) {
        _doChase(bot, strategy, dx, dz, dist, run: false);
      } else {
        final norm = math.max(dist, 1.0);
        _applyInput(bot, strategy,
            Vector2(-dz / norm * _strafeDir * 0.5, 0), run: false);
      }
    } else {
      final norm = math.max(dist, 1.0);
      _applyInput(bot, strategy, Vector2(-dz / norm * _strafeDir, 0), run: false);
    }
  }

  void _doChase(GameCharacter3D bot, MovementStrategy3D strategy,
      double dx, double dz, double dist, {required bool run}) {
    final norm = math.max(dist, 1.0);
    _applyInput(bot, strategy, Vector2(dx / norm, -dz / norm), run: run);
  }

  void _doRetreat(GameCharacter3D bot, MovementStrategy3D strategy,
      double dx, double dz) {
    final norm = math.sqrt(dx * dx + dz * dz);
    if (norm < 1.0) return;
    _applyInput(bot, strategy, Vector2(-dx / norm, dz / norm), run: true);
  }

  void _applyInput(GameCharacter3D bot, MovementStrategy3D strategy,
      Vector2 input, {required bool run}) {
    strategy.applyMovement(bot, input, run, 0.016);
  }

  void _tryAttack(GameCharacter3D bot, double dist) {
    if (dist > _attackRange) return;
    if (bot.characterState.isAttacking) return;
    if (bot.characterState.attackCooldown > 0) return;
    if (personality == BotPersonality3D.coward) {
      final busy = bot.game.character.characterState.isAttacking ||
          bot.game.character.characterState.isAirborne;
      if (!busy) return;
    }
    bot.performAttack3D();
  }

  void _tryHeightJump(GameCharacter3D bot) {
    if (_jumpCooldown > 0) return;
    if (bot.game.character.worldPos.y - bot.worldPos.y > 90) {
      bot.performJump3D();
      _jumpCooldown = _jumpCooldownTime;
    }
  }

  void _checkStuck(GameCharacter3D bot, double dist, double dt) {
    if (_jumpCooldown > 0) return;
    if (bot.characterState.isAirborne) { _stuckTimer = 0; return; }
    final speed = math.sqrt(
        bot.velocity.x * bot.velocity.x + bot.velocity.z * bot.velocity.z);
    if (dist > 100 && speed < _stuckSpeedThreshold) {
      _stuckTimer += dt;
    } else {
      _stuckTimer = 0;
    }
    if (_stuckTimer >= _stuckThreshold) {
      bot.performJump3D();
      _stuckTimer   = 0;
      _jumpCooldown = _jumpCooldownTime;
    }
  }
}
