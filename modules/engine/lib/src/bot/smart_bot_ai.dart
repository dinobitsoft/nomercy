import 'dart:math' as math;

import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

// Walk-speed multiplier for bots.
// Player uses dex/2 * walkSpeedMultiplier(100) ≈ 400 px/s for knight.
// Bots use _kSpeed so they feel responsive but slightly slower than player.
const double _kSpeed = 30.0;

class SmartBotAI implements IntelligentBotAI {
  @override final String         name;
  @override final BotPersonality personality;

  BotState currentState         = BotState.idle;
  double   stateTimer           = 0;
  double   reactionTime         = 0.2;
  double   lastDecisionTime     = 0;

  int    consecutiveHits        = 0;
  int    consecutiveMisses      = 0;
  Vector2 lastPlayerPosition    = Vector2.zero();
  double  playerVelocityEstimate = 0;

  late final double aggressionLevel;
  late final double cautionLevel;
  late final double staminaReserve;
  late final double optimalRange;
  late final double retreatThreshold;

  SmartBotAI({required this.name, this.personality = BotPersonality.balanced}) {
    _initPersonality();
  }

  void _initPersonality() {
    switch (personality) {
      case BotPersonality.aggressive:
        aggressionLevel   = 0.9; cautionLevel = 0.2;
        staminaReserve    = 20;  optimalRange = 150;
        retreatThreshold  = 20;  reactionTime = 0.15;
      case BotPersonality.defensive:
        aggressionLevel   = 0.3; cautionLevel = 0.9;
        staminaReserve    = 40;  optimalRange = 350;
        retreatThreshold  = 50;  reactionTime = 0.10;
      case BotPersonality.tactical:
        aggressionLevel   = 0.6; cautionLevel = 0.7;
        staminaReserve    = 30;  optimalRange = 250;
        retreatThreshold  = 30;  reactionTime = 0.12;
      case BotPersonality.berserker:
        aggressionLevel   = 1.0; cautionLevel = 0.0;
        staminaReserve    = 10;  optimalRange = 100;
        retreatThreshold  = 0;   reactionTime = 0.20;
      default: // balanced
        aggressionLevel   = 0.6; cautionLevel = 0.5;
        staminaReserve    = 25;  optimalRange = 250;
        retreatThreshold  = 35;  reactionTime = 0.15;
    }
  }

  // ── public API ─────────────────────────────────────────────────────────────

  @override
  void executeAI(GameCharacter bot, GameCharacter target, double dt) {
    if (bot.characterState.health <= 0) { bot.velocity.x = 0; return; }
    if (target.characterState.health <= 0) {
      bot.velocity.x *= 0.7;
      currentState = BotState.idle;
      return;
    }

    stateTimer        += dt;
    lastDecisionTime  += dt;

    _trackPlayer(target, dt);

    if (lastDecisionTime >= reactionTime) {
      final decision = makeDecision(bot, target, bot.game.projectiles);
      _execute(bot, target, decision, dt);
      lastDecisionTime = 0;
    }

    _handleImmediateThreats(bot, target);
  }

  void _trackPlayer(GameCharacter target, double dt) {
    if (dt <= 0) return;
    final disp = target.position - lastPlayerPosition;
    playerVelocityEstimate = disp.length / dt;
    lastPlayerPosition = target.position.clone();
  }

  @override
  BotDecision makeDecision(
      GameCharacter bot, GameCharacter target, List<Projectile> projectiles) {
    final decisions = <BotDecision>[
      _evalAttack(bot, target),
      _evalDefend(bot, target),
      _evalReposition(bot, target),
      _evalEvade(bot, projectiles),
      _evalDodge(bot, target),
      _evalJumpAttack(bot, target),
    ];
    decisions.sort((a, b) => b.priority.compareTo(a.priority));
    return decisions.first;
  }

  // ── evaluators ─────────────────────────────────────────────────────────────

  BotDecision _evalAttack(GameCharacter bot, GameCharacter target) {
    final distance = bot.position.distanceTo(target.position);
    double p = aggressionLevel;
    if (target.characterState.isLanding || target.characterState.isStunned) p += 0.5;
    if (target.characterState.isAttacking && !target.characterState.isAttackCommitted) p += 0.3;
    if (bot.characterState.stamina / bot.characterState.maxStamina < 0.3) p -= 0.4;
    if (distance > bot.stats.attackRange * 30) p -= 0.5;
    if (bot.characterState.comboTimer > 0) p += 0.3;
    if (bot.characterState.attackCooldown > 0) p = 0;
    return BotDecision('attack', p);
  }

  BotDecision _evalDefend(GameCharacter bot, GameCharacter target) {
    final distance = bot.position.distanceTo(target.position);
    final hp = bot.characterState.health / 100;
    double p = cautionLevel;
    if (hp < 0.3) p += 0.6;
    if (hp < 0.5) p += 0.3;
    if (target.characterState.isAttacking && distance < 200) p += 0.5;
    if (bot.characterState.isBlocking) p += 0.2;
    if (bot.characterState.stamina < 10) p = 0;
    if (distance > 300) p -= 0.4;
    return BotDecision('defend', p);
  }

  BotDecision _evalReposition(GameCharacter bot, GameCharacter target) {
    final distance = bot.position.distanceTo(target.position);
    final hp = bot.characterState.health / 100;
    double p = 0.3 + ((distance - optimalRange).abs() / optimalRange) * 0.5;
    if (hp < 0.4) p += 0.3;
    return BotDecision('reposition', p,
        {'targetDistance': optimalRange, 'currentDistance': distance});
  }

  BotDecision _evalEvade(GameCharacter bot, List<Projectile> projectiles) {
    final threats = _dangerousProjectiles(bot, projectiles);
    if (threats.isEmpty) return BotDecision('evade', 0);
    final closest = threats
        .map((p) => bot.position.distanceTo(p.position))
        .reduce(math.min);
    double p = closest < 100 ? 1.0 : closest < 150 ? 0.7 : 0.4;
    p *= (1 + cautionLevel);
    return BotDecision('evade', p, {'projectiles': threats});
  }

  BotDecision _evalDodge(GameCharacter bot, GameCharacter target) {
    final distance = bot.position.distanceTo(target.position);
    double p = 0;
    if (target.characterState.isAttacking && distance < 180 &&
        bot.characterState.dodgeCooldown <= 0) {
      p = 0.7 * cautionLevel;
    }
    if (target.characterState.comboCount >= 2 && distance < 150) p = 0.8;
    if (bot.characterState.stamina < 20 || bot.characterState.dodgeCooldown > 0) p = 0;
    if (personality == BotPersonality.berserker) p = 0;
    return BotDecision('dodge', p);
  }

  BotDecision _evalJumpAttack(GameCharacter bot, GameCharacter target) {
    // Only consider if grounded — prevents aerial chain-jumps and falling off
    if (bot.characterState.groundPlatform == null) return BotDecision('jump_attack', 0);
    if (bot.characterState.stamina / bot.characterState.maxStamina < 0.2) {
      return BotDecision('jump_attack', 0);
    }
    final distance = bot.position.distanceTo(target.position);
    // Jump only when target is clearly below and nearby
    final targetBelow = target.position.y > bot.position.y + 50;
    double p = 0;
    if (targetBelow && distance < 250) p = 0.5 * aggressionLevel;
    if (personality == BotPersonality.aggressive || personality == BotPersonality.berserker) {
      p += 0.1;
    }
    return BotDecision('jump_attack', p);
  }

  // ── executors ──────────────────────────────────────────────────────────────

  void _execute(GameCharacter bot, GameCharacter target,
      BotDecision decision, double dt) {
    switch (decision.action) {
      case 'attack':      _doAttack(bot, target);
      case 'defend':      _doDefend(bot, target);
      case 'reposition':  _doReposition(bot, target, decision.params);
      case 'evade':       _doEvade(bot, decision.params);
      case 'dodge':       _doDodge(bot, target);
      case 'jump_attack': _doJumpAttack(bot, target);
    }
  }

  void _doAttack(GameCharacter bot, GameCharacter target) {
    final toTarget = target.position - bot.position;
    final distance = toTarget.length;
    bot.facingRight = toTarget.x > 0;

    final speed = bot.stats.dexterity * _kSpeed;
    if (distance > optimalRange * 1.1) {
      bot.velocity.x = toTarget.normalized().x * speed;
    } else if (distance < optimalRange * 0.6) {
      bot.velocity.x = -toTarget.normalized().x * speed * 0.5;
    } else {
      bot.velocity.x *= 0.8; // slow to stop at ideal range
    }

    if (bot.characterState.attackCooldown <= 0 && bot.characterState.stamina >= 15) {
      bot.attack();
    }
    currentState = BotState.attack;
  }

  void _doDefend(GameCharacter bot, GameCharacter target) {
    bot.facingRight = (target.position - bot.position).x > 0;
    bot.velocity.x  = 0;
    bot.startBlock();
    currentState = BotState.defend;
  }

  void _doReposition(GameCharacter bot, GameCharacter target,
      Map<String, dynamic> params) {
    final targetDist  = params['targetDistance'] as double;
    final currentDist = params['currentDistance'] as double;
    final toTarget    = target.position - bot.position;

    bot.facingRight = toTarget.x > 0;
    bot.stopBlock();

    final speed = bot.stats.dexterity * _kSpeed * 0.85;
    bot.velocity.x = currentDist < targetDist
        ? -toTarget.normalized().x * speed   // back off
        :  toTarget.normalized().x * speed;  // close in

    currentState = BotState.reposition;
  }

  void _doEvade(GameCharacter bot, Map<String, dynamic> params) {
    final projectiles = params['projectiles'] as List<Projectile>;
    if (projectiles.isEmpty) return;

    final closest = projectiles.reduce((a, b) =>
    bot.position.distanceTo(a.position) < bot.position.distanceTo(b.position)
        ? a : b);

    // Strafe perpendicular — NO upward jump (prevents falling off map)
    final speed = bot.stats.dexterity * _kSpeed * 1.2;
    bot.velocity.x = (closest.direction.x > 0 ? -1 : 1) * speed;

    currentState = BotState.evade;
  }

  void _doDodge(GameCharacter bot, GameCharacter target) {
    final away = -(target.position - bot.position).normalized();
    bot.dodge(Vector2(away.x, 0));
    currentState = BotState.evade;
  }

  void _doJumpAttack(GameCharacter bot, GameCharacter target) {
    if (bot.characterState.groundPlatform == null) return;

    final toTarget = target.position - bot.position;
    bot.facingRight = toTarget.x > 0;
    bot.performJump();

    final speed = bot.stats.dexterity * _kSpeed;
    bot.velocity.x = toTarget.normalized().x * speed;

    currentState = BotState.attack;
  }

  // ── immediate-threat handler (every frame) ─────────────────────────────────

  void _handleImmediateThreats(GameCharacter bot, GameCharacter target) {
    final threats = bot.game.projectiles.where((p) {
      if (p.enemyOwner == bot) return false;
      return bot.position.distanceTo(p.position) < 55 &&
          _headingTowards(bot, p);
    }).toList();

    if (threats.isNotEmpty &&
        bot.characterState.dodgeCooldown <= 0 &&
        bot.characterState.stamina >= 20) {
      final threat = threats.first;
      bot.dodge(Vector2(threat.direction.x > 0 ? -1 : 1, 0));
    }

    if (bot.characterState.isBlocking &&
        !target.characterState.isAttacking &&
        bot.position.distanceTo(target.position) > 250) {
      bot.stopBlock();
    }
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  List<Projectile> _dangerousProjectiles(
      GameCharacter bot, List<Projectile> all) {
    return all.where((p) {
      if (p.enemyOwner == bot) return false;
      return bot.position.distanceTo(p.position) < 200 &&
          _headingTowards(bot, p);
    }).toList();
  }

  bool _headingTowards(GameCharacter bot, Projectile p) {
    return (bot.position - p.position).dot(p.direction) > 0;
  }

  Vector2 _predict(GameCharacter target, double ahead) {
    return target.position + target.velocity * ahead;
  }

  @override
  bool shouldEvade(GameCharacter bot, List<Projectile> incoming) {
    return incoming.isNotEmpty && math.Random().nextDouble() < cautionLevel;
  }

  @override
  void onDamageTaken(GameCharacter bot, double damage) {
    consecutiveHits++;
    if (damage > 20) {
      debugPrint('${bot.stats.name}: heavy hit, retreating');
    }
  }
}