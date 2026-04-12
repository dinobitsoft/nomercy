import 'dart:math' as math;

import 'package:engine/engine.dart';
import 'package:flame/components.dart';

import 'bot_decision.dart';
import 'bot_state.dart';
import 'intelligent_bot_ai.dart';

class SmartBotAI implements IntelligentBotAI {
  @override
  final String name;

  @override
  final BotPersonality personality;

  BotState currentState = BotState.idle;
  double stateTimer = 0;
  double reactionTime = 0.2;
  double lastDecisionTime = 0;

  int consecutiveHits = 0;
  int consecutiveMisses = 0;
  double lastPlayerAttackTime = 0;
  Vector2 lastPlayerPosition = Vector2.zero();
  double playerVelocityEstimate = 0;

  late final double aggressionLevel;
  late final double cautionLevel;
  late final double staminaReserve;
  late final double optimalRange;
  late final double retreatThreshold;

  SmartBotAI({
    required this.name,
    this.personality = BotPersonality.balanced,
  }) {
    _initializePersonality();
  }

  void _initializePersonality() {
    switch (personality) {
      case BotPersonality.aggressive:
        aggressionLevel = 0.9; cautionLevel = 0.2; staminaReserve = 20;
        optimalRange = 150; retreatThreshold = 20; reactionTime = 0.15;
      case BotPersonality.defensive:
        aggressionLevel = 0.3; cautionLevel = 0.9; staminaReserve = 40;
        optimalRange = 350; retreatThreshold = 50; reactionTime = 0.1;
      case BotPersonality.tactical:
        aggressionLevel = 0.6; cautionLevel = 0.7; staminaReserve = 30;
        optimalRange = 250; retreatThreshold = 30; reactionTime = 0.12;
      case BotPersonality.berserker:
        aggressionLevel = 1.0; cautionLevel = 0.0; staminaReserve = 10;
        optimalRange = 100; retreatThreshold = 0; reactionTime = 0.2;
      default:
        aggressionLevel = 0.6; cautionLevel = 0.5; staminaReserve = 25;
        optimalRange = 250; retreatThreshold = 35; reactionTime = 0.15;
    }
  }

  @override
  void executeAI(GameCharacter bot, GameCharacter target, double dt) {
    if (bot.characterState.health <= 0) { bot.velocity = Vector2.zero(); return; }
    if (target.characterState.health <= 0) {
      bot.velocity.x *= 0.7; currentState = BotState.idle; return;
    }
    stateTimer += dt;
    lastDecisionTime += dt;
    _updatePlayerTracking(target, dt);
    if (lastDecisionTime >= reactionTime) {
      final decision = makeDecision(bot, target, bot.game.projectiles);
      _executeDecision(bot, target, decision, dt);
      lastDecisionTime = 0;
    }
    _handleImmediateThreats(bot, target, dt);
  }

  void _updatePlayerTracking(GameCharacter target, double dt) {
    final currentPos = target.position;
    final displacement = currentPos - lastPlayerPosition;
    playerVelocityEstimate = displacement.length / dt;
    lastPlayerPosition = currentPos.clone();
  }

  @override
  BotDecision makeDecision(GameCharacter bot, GameCharacter target,
      List<Projectile> projectiles) {
    final decisions = <BotDecision>[];
    final distance = bot.position.distanceTo(target.position);
    final healthPct  = bot.characterState.health / 100;
    final staminaPct = bot.characterState.stamina / bot.characterState.maxStamina;

    decisions.add(_evaluateAttack(bot, target, distance, staminaPct));
    decisions.add(_evaluateDefend(bot, target, distance, healthPct));
    decisions.add(_evaluateReposition(bot, target, distance, healthPct));
    decisions.add(_evaluateEvade(bot, target, projectiles, distance));
    decisions.add(_evaluateDodge(bot, target, distance, staminaPct));
    decisions.add(_evaluateJumpAttack(bot, target, distance, staminaPct));

    decisions.sort((a, b) => b.priority.compareTo(a.priority));
    return decisions.first;
  }

  BotDecision _evaluateAttack(GameCharacter bot, GameCharacter target,
      double distance, double staminaPct) {
    double priority = aggressionLevel;
    if (target.characterState.isLanding || target.characterState.isStunned) priority += 0.5;
    if (target.characterState.isAttacking && !target.characterState.isAttackCommitted) priority += 0.3;
    if (staminaPct < 0.3) priority -= 0.4;
    if (distance >= bot.stats.attackRange * 30) priority -= 0.5;
    if (bot.characterState.comboTimer > 0) priority += 0.3;
    if (bot.characterState.attackCooldown > 0) priority = 0;
    return BotDecision('attack', priority);
  }

  BotDecision _evaluateDefend(GameCharacter bot, GameCharacter target,
      double distance, double healthPct) {
    double priority = cautionLevel;
    if (healthPct < 0.3) priority += 0.6;
    if (healthPct < 0.5) priority += 0.3;
    if (target.characterState.isAttacking && distance < 200) priority += 0.5;
    if (bot.characterState.isBlocking) priority += 0.2;
    if (bot.characterState.stamina < 10) priority = 0;
    if (distance > 300) priority -= 0.4;
    return BotDecision('defend', priority);
  }

  BotDecision _evaluateReposition(GameCharacter bot, GameCharacter target,
      double distance, double healthPct) {
    double priority = 0.3;
    priority += ((distance - optimalRange).abs() / optimalRange) * 0.5;
    if (healthPct < 0.4) priority += 0.3;
    if (target.position.y < bot.position.y - 100) priority += 0.2;
    return BotDecision('reposition', priority,
        {'targetDistance': optimalRange, 'currentDistance': distance});
  }

  BotDecision _evaluateEvade(GameCharacter bot, GameCharacter target,
      List<Projectile> projectiles, double distance) {
    final threats = projectiles.where((p) {
      if (p.enemyOwner == bot) return false;
      return bot.position.distanceTo(p.position) < 200 &&
          _isProjectileHeadingTowards(bot, p);
    }).toList();
    if (threats.isEmpty) return BotDecision('evade', 0);
    final closest = threats
        .map((p) => bot.position.distanceTo(p.position))
        .reduce(math.min);
    double priority = closest < 100 ? 1.0 : closest < 150 ? 0.7 : 0.4;
    priority *= (1 + cautionLevel);
    return BotDecision('evade', priority, {'projectiles': threats});
  }

  BotDecision _evaluateDodge(GameCharacter bot, GameCharacter target,
      double distance, double staminaPct) {
    double priority = 0;
    if (target.characterState.isAttacking && distance < 180 &&
        bot.characterState.dodgeCooldown <= 0) {
      priority = 0.7 * cautionLevel;
    }
    if (target.characterState.comboCount >= 2 && distance < 150) priority = 0.8;
    if (bot.characterState.stamina < 20 || bot.characterState.dodgeCooldown > 0) priority = 0;
    if (personality == BotPersonality.berserker) priority = 0;
    return BotDecision('dodge', priority);
  }

  BotDecision _evaluateJumpAttack(GameCharacter bot, GameCharacter target,
      double distance, double staminaPct) {
    double priority = 0;
    final isGrounded   = bot.characterState.groundPlatform != null;
    final canDblJump   = bot.characterState.canDoubleJump &&
        !bot.characterState.hasDoubleJumped &&
        bot.characterState.isAirborne;
    if (isGrounded && target.position.y > bot.position.y + 50 && distance < 250) {
      priority = 0.6 * aggressionLevel;
    }
    if (canDblJump) {
      if (target.position.y < bot.position.y - 80 && distance < 300) priority = 0.75 * aggressionLevel;
      else if (bot.characterState.health / 100 < 0.3) priority = 0.5;
      else if (target.characterState.isAttacking && distance < 180) priority = 0.6;
    }
    if (personality == BotPersonality.aggressive || personality == BotPersonality.berserker) priority += 0.2;
    if (staminaPct < 0.2) priority = 0;
    if (!isGrounded && !canDblJump) priority = 0;
    return BotDecision('jump_attack', priority);
  }

  void _executeDecision(GameCharacter bot, GameCharacter target,
      BotDecision decision, double dt) {
    switch (decision.action) {
      case 'attack':      _performAttack(bot, target);
      case 'defend':      _performDefend(bot, target);
      case 'reposition':  _performReposition(bot, target, decision.params);
      case 'evade':       _performEvade(bot, decision.params);
      case 'dodge':       _performDodge(bot, target);
      case 'jump_attack': _performJumpAttack(bot, target);
    }
  }

  void _performAttack(GameCharacter bot, GameCharacter target) {
    final distance  = bot.position.distanceTo(target.position);
    final toTarget  = target.position - bot.position;
    bot.facingRight = toTarget.x > 0;
    if (bot.stats.attackRange > 5) {
      final pred = _predictTargetPosition(target, 0.5);
      bot.facingRight = (pred - bot.position).x > 0;
    }
    if (distance > optimalRange) {
      bot.velocity.x = toTarget.normalized().x * (bot.stats.dexterity / 3);
    } else if (distance < optimalRange * 0.7) {
      bot.velocity.x = -toTarget.normalized().x * (bot.stats.dexterity / 4);
    } else {
      bot.velocity.x = 0;
    }
    if (bot.characterState.attackCooldown <= 0 && bot.characterState.stamina >= 15) {
      bot.attack(); consecutiveMisses = 0;
    }
    currentState = BotState.attack;
  }

  void _performDefend(GameCharacter bot, GameCharacter target) {
    bot.facingRight = (target.position - bot.position).x > 0;
    bot.velocity.x = 0;
    bot.startBlock();
    currentState = BotState.defend;
  }

  void _performReposition(GameCharacter bot, GameCharacter target,
      Map<String, dynamic> params) {
    final targetDist  = params['targetDistance'] as double;
    final currentDist = params['currentDistance'] as double;
    final toTarget    = target.position - bot.position;
    bot.facingRight = toTarget.x > 0;
    bot.stopBlock();
    bot.velocity.x = currentDist < targetDist
        ? -toTarget.normalized().x * (bot.stats.dexterity / 2)
        :  toTarget.normalized().x * (bot.stats.dexterity / 2);
    if (bot.characterState.groundPlatform != null &&
        math.Random().nextDouble() < 0.1) {
      for (final p in bot.game.platforms) {
        if (p.position.y < bot.position.y - 50 &&
            (p.position.x - bot.position.x).abs() < 200) {
          bot.performJump(); break;
        }
      }
    } else if (bot.characterState.canDoubleJump &&
        !bot.characterState.hasDoubleJumped &&
        bot.characterState.isAirborne &&
        math.Random().nextDouble() < 0.05) {
      bot.performJump();
    }
    currentState = BotState.reposition;
  }

  void _performEvade(GameCharacter bot, Map<String, dynamic> params) {
    final projectiles = params['projectiles'] as List<Projectile>;
    if (projectiles.isEmpty) return;
    final closest = projectiles.reduce((a, b) =>
        bot.position.distanceTo(a.position) < bot.position.distanceTo(b.position) ? a : b);
    bot.velocity.x =
        Vector2(-closest.direction.y, closest.direction.x).x * (bot.stats.dexterity / 1.5);
    if (closest.position.y > bot.position.y - 50 &&
        bot.characterState.groundPlatform != null &&
        bot.characterState.stamina >= 20) {
      bot.velocity.y = -300;
      bot.characterState.groundPlatform = null;
      bot.characterState.stamina -= 20;
    }
    currentState = BotState.evade;
  }

  void _performDodge(GameCharacter bot, GameCharacter target) {
    bot.dodge(Vector2(-(target.position - bot.position).normalized().x, 0));
    currentState = BotState.evade;
  }

  void _performJumpAttack(GameCharacter bot, GameCharacter target) {
    final toTarget   = target.position - bot.position;
    bot.facingRight  = toTarget.x > 0;
    final isGrounded = bot.characterState.groundPlatform != null;
    final canDblJump = bot.characterState.canDoubleJump &&
        !bot.characterState.hasDoubleJumped &&
        bot.characterState.isAirborne;
    if (isGrounded || canDblJump) bot.performJump();
    bot.velocity.x = toTarget.normalized().x * (bot.stats.dexterity / 2.5);
    if (bot.characterState.attackCooldown <= 0 &&
        bot.characterState.stamina >= 15 &&
        bot.position.distanceTo(target.position) < bot.stats.attackRange * 30) {
      bot.attack();
    }
    currentState = BotState.attack;
  }

  void _handleImmediateThreats(GameCharacter bot, GameCharacter target, double dt) {
    final threats = bot.game.projectiles.where((p) {
      if (p.enemyOwner == bot) return false;
      return bot.position.distanceTo(p.position) < 50 &&
          _isProjectileHeadingTowards(bot, p);
    }).toList();
    if (threats.isNotEmpty &&
        bot.characterState.dodgeCooldown <= 0 &&
        bot.characterState.stamina >= 20) {
      bot.dodge(Vector2(-threats.first.direction.x, 0));
    }
    if (bot.characterState.isBlocking &&
        !target.characterState.isAttacking &&
        bot.position.distanceTo(target.position) > 250) {
      bot.stopBlock();
    }
  }

  bool _isProjectileHeadingTowards(GameCharacter bot, Projectile p) =>
      (bot.position - p.position).dot(p.direction) > 0;

  Vector2 _predictTargetPosition(GameCharacter target, double timeAhead) =>
      target.position + (target.velocity * timeAhead);

  @override
  bool shouldEvade(GameCharacter bot, List<Projectile> incomingProjectiles) =>
      incomingProjectiles.isNotEmpty && math.Random().nextDouble() < cautionLevel;

  @override
  void onDamageTaken(GameCharacter bot, double damage) {
    consecutiveHits++;
    if (consecutiveHits > 3 && personality != BotPersonality.berserker) {
      print('${bot.stats.name} bot: Switching to defensive stance!');
    }
    if (damage > 20) print('${bot.stats.name} bot: Heavy damage taken! Retreating!');
  }
}
