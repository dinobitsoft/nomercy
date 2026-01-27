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
  double reactionTime = 0.2; // Bot decision delay for realism
  double lastDecisionTime = 0;

  // Memory and learning
  int consecutiveHits = 0;
  int consecutiveMisses = 0;
  double lastPlayerAttackTime = 0;
  Vector2 lastPlayerPosition = Vector2.zero();
  double playerVelocityEstimate = 0;

  // Tactical parameters based on personality
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
        aggressionLevel = 0.9;
        cautionLevel = 0.2;
        staminaReserve = 20;
        optimalRange = 150;
        retreatThreshold = 20;
        reactionTime = 0.15;
        break;
      case BotPersonality.defensive:
        aggressionLevel = 0.3;
        cautionLevel = 0.9;
        staminaReserve = 40;
        optimalRange = 350;
        retreatThreshold = 50;
        reactionTime = 0.1;
        break;
      case BotPersonality.tactical:
        aggressionLevel = 0.6;
        cautionLevel = 0.7;
        staminaReserve = 30;
        optimalRange = 250;
        retreatThreshold = 30;
        reactionTime = 0.12;
        break;
      case BotPersonality.berserker:
        aggressionLevel = 1.0;
        cautionLevel = 0.0;
        staminaReserve = 10;
        optimalRange = 100;
        retreatThreshold = 0;
        reactionTime = 0.2;
        break;
      default: // balanced
        aggressionLevel = 0.6;
        cautionLevel = 0.5;
        staminaReserve = 25;
        optimalRange = 250;
        retreatThreshold = 35;
        reactionTime = 0.15;
    }
  }

  @override
  void executeAI(GameCharacter bot, GameCharacter target, double dt) {
    // CRITICAL: Don't execute AI if bot is dead
    if (bot.characterState.health <= 0) {
      bot.velocity = Vector2.zero();
      return;
    }

    // Also check if target is dead
    if (target.characterState.health <= 0) {
      bot.velocity.x *= 0.7; // Slow down
      currentState = BotState.idle;
      return;
    }

    stateTimer += dt;
    lastDecisionTime += dt;

    // Track player movement for prediction
    _updatePlayerTracking(target, dt);

    // Make decisions periodically (not every frame for realism)
    if (lastDecisionTime >= reactionTime) {
      final projectiles = bot.game.projectiles;
      final decision = makeDecision(bot, target, projectiles);
      _executeDecision(bot, target, decision, dt);
      lastDecisionTime = 0;
    }

    // Always check for immediate threats
    _handleImmediateThreats(bot, target, dt);
  }

  void _updatePlayerTracking(GameCharacter target, double dt) {
    final currentPos = target.position;
    final displacement = currentPos - lastPlayerPosition;
    playerVelocityEstimate = displacement.length / dt;
    lastPlayerPosition = currentPos.clone();
  }

  @override
  BotDecision makeDecision(GameCharacter bot, GameCharacter target, List<Projectile> projectiles) {
    final decisions = <BotDecision>[];

    final distance = bot.position.distanceTo(target.position);
    final healthPercent = bot.characterState.health / 100;
    final staminaPercent = bot.characterState.stamina / bot.characterState.maxStamina;
    final targetHealthPercent = target.characterState.health / 100;

    // Evaluate all possible actions
    decisions.add(_evaluateAttack(bot, target, distance, staminaPercent));
    decisions.add(_evaluateDefend(bot, target, distance, healthPercent));
    decisions.add(_evaluateReposition(bot, target, distance, healthPercent));
    decisions.add(_evaluateEvade(bot, target, projectiles, distance));
    decisions.add(_evaluateDodge(bot, target, distance, staminaPercent));
    decisions.add(_evaluateJumpAttack(bot, target, distance, staminaPercent));

    // Sort by priority and pick best
    decisions.sort((a, b) => b.priority.compareTo(a.priority));
    return decisions.first;
  }

  BotDecision _evaluateAttack(GameCharacter bot, GameCharacter target, double distance, double staminaPercent) {
    double priority = aggressionLevel;

    // Increase priority if target is vulnerable
    if (target.characterState.isLanding || target.characterState.isStunned) priority += 0.5;
    if (target.characterState.isAttacking && !target.characterState.isAttackCommitted) priority += 0.3;

    // Decrease if low stamina
    if (staminaPercent < 0.3) priority -= 0.4;

    // Range considerations
    final inRange = distance < bot.stats.attackRange * 30;
    if (!inRange) priority -= 0.5;

    // Combo opportunity
    if (bot.characterState.comboTimer > 0) priority += 0.3;

    // Don't attack if on cooldown
    if (bot.characterState.attackCooldown > 0) priority = 0;

    return BotDecision('attack', priority);
  }

  BotDecision _evaluateDefend(GameCharacter bot, GameCharacter target, double distance, double healthPercent) {
    double priority = cautionLevel;

    // High priority if low health
    if (healthPercent < 0.3) priority += 0.6;
    if (healthPercent < 0.5) priority += 0.3;

    // High priority if target is attacking nearby
    if (target.characterState.isAttacking && distance < 200) priority += 0.5;

    // Low priority if already blocking
    if (bot.characterState.isBlocking) priority += 0.2; // Slight boost to continue blocking

    // Can't block without stamina
    if (bot.characterState.stamina < 10) priority = 0;

    // Don't block if target is far
    if (distance > 300) priority -= 0.4;

    return BotDecision('defend', priority);
  }

  BotDecision _evaluateReposition(GameCharacter bot, GameCharacter target, double distance, double healthPercent) {
    double priority = 0.3;

    // Need to reposition if too close or too far
    final distanceFromOptimal = (distance - optimalRange).abs();
    priority += (distanceFromOptimal / optimalRange) * 0.5;

    // Reposition if low health
    if (healthPercent < 0.4) priority += 0.3;

    // Reposition to higher ground if available
    if (target.position.y < bot.position.y - 100) priority += 0.2;

    return BotDecision('reposition', priority, {
      'targetDistance': optimalRange,
      'currentDistance': distance,
    });
  }

  BotDecision _evaluateEvade(GameCharacter bot, GameCharacter target, List<Projectile> projectiles, double distance) {
    double priority = 0;

    final dangerousProjectiles = projectiles.where((p) {
      if (p.enemyOwner == bot) return false; // Own projectile
      final distToProjectile = bot.position.distanceTo(p.position);
      final isHeadingTowards = _isProjectileHeadingTowards(bot, p);
      return distToProjectile < 200 && isHeadingTowards;
    }).toList();

    if (dangerousProjectiles.isEmpty) return BotDecision('evade', 0);

    // Very high priority for immediate threats
    final closestDist = dangerousProjectiles
        .map((p) => bot.position.distanceTo(p.position))
        .reduce(math.min);

    if (closestDist < 100) priority = 1.0;
    else if (closestDist < 150) priority = 0.7;
    else priority = 0.4;

    // Defensive bots prioritize evasion
    priority *= (1 + cautionLevel);

    return BotDecision('evade', priority, {
      'projectiles': dangerousProjectiles,
    });
  }

  BotDecision _evaluateDodge(GameCharacter bot, GameCharacter target, double distance, double staminaPercent) {
    double priority = 0;

    // Dodge when target is attacking and close
    if (target.characterState.isAttacking && distance < 180 && bot.characterState.dodgeCooldown <= 0) {
      priority = 0.7 * cautionLevel;
    }

    // Dodge to escape combos
    if (target.characterState.comboCount >= 2 && distance < 150) {
      priority = 0.8;
    }

    // Can't dodge without stamina or on cooldown
    if (bot.characterState.stamina < 20 || bot.characterState.dodgeCooldown > 0) priority = 0;

    // Berserker doesn't dodge
    if (personality == BotPersonality.berserker) priority = 0;

    return BotDecision('dodge', priority);
  }

  BotDecision _evaluateJumpAttack(GameCharacter bot, GameCharacter target, double distance, double staminaPercent) {
    double priority = 0;

    // Jump attack if target is on lower platform
    if (target.position.y > bot.position.y + 50 && distance < 250) {
      priority = 0.6 * aggressionLevel;
    }

    // Aggressive personalities use more aerial attacks
    if (personality == BotPersonality.aggressive || personality == BotPersonality.berserker) {
      priority += 0.2;
    }

    // Can't jump attack without stamina or already airborne
    if (bot.characterState.stamina < 20 || bot.characterState.isAirborne || bot.characterState.groundPlatform == null) priority = 0;

    return BotDecision('jump_attack', priority);
  }

  void _executeDecision(GameCharacter bot, GameCharacter target, BotDecision decision, double dt) {
    switch (decision.action) {
      case 'attack':
        _performAttack(bot, target);
        break;
      case 'defend':
        _performDefend(bot, target);
        break;
      case 'reposition':
        _performReposition(bot, target, decision.params);
        break;
      case 'evade':
        _performEvade(bot, decision.params);
        break;
      case 'dodge':
        _performDodge(bot, target);
        break;
      case 'jump_attack':
        _performJumpAttack(bot, target);
        break;
    }
  }

  void _performAttack(GameCharacter bot, GameCharacter target) {
    final distance = bot.position.distanceTo(target.position);
    final toTarget = target.position - bot.position;

    // Face target
    bot.facingRight = toTarget.x > 0;

    // Predict target movement for ranged attacks
    if (bot.stats.attackRange > 5) {
      final prediction = _predictTargetPosition(target, 0.5);
      final predictedDirection = prediction - bot.position;
      bot.facingRight = predictedDirection.x > 0;
    }

    // Move slightly towards optimal range while attacking
    if (distance > optimalRange) {
      bot.velocity.x = toTarget.normalized().x * (bot.stats.dexterity / 3);
    } else if (distance < optimalRange * 0.7) {
      bot.velocity.x = -toTarget.normalized().x * (bot.stats.dexterity / 4);
    } else {
      bot.velocity.x = 0; // Stand still at optimal range
    }

    // Attack!
    if (bot.characterState.attackCooldown <= 0 && bot.characterState.stamina >= 15) {
      bot.attack();
      consecutiveMisses = 0;
    }

    currentState = BotState.attack;
  }

  void _performDefend(GameCharacter bot, GameCharacter target) {
    final toTarget = target.position - bot.position;
    bot.facingRight = toTarget.x > 0;

    // Stop moving and block
    bot.velocity.x = 0;
    bot.startBlock();

    currentState = BotState.defend;
  }

  void _performReposition(GameCharacter bot, GameCharacter target, Map<String, dynamic> params) {
    final targetDistance = params['targetDistance'] as double;
    final currentDistance = params['currentDistance'] as double;
    final toTarget = target.position - bot.position;

    bot.facingRight = toTarget.x > 0;
    bot.stopBlock(); // Don't block while repositioning

    if (currentDistance < targetDistance) {
      // Move away
      bot.velocity.x = -toTarget.normalized().x * (bot.stats.dexterity / 2);
    } else {
      // Move closer
      bot.velocity.x = toTarget.normalized().x * (bot.stats.dexterity / 2);
    }

    // Jump over obstacles or to platforms
    if (bot.characterState.groundPlatform != null && math.Random().nextDouble() < 0.1) {
      final platforms = bot.game.platforms;
      for (final platform in platforms) {
        // Check if there's a platform we should jump to
        if (platform.position.y < bot.position.y - 50 &&
            (platform.position.x - bot.position.x).abs() < 200 &&
            bot.characterState.stamina >= 20) {
          bot.velocity.y = -300;
          bot.characterState.groundPlatform = null;
          bot.characterState.stamina -= 20;
          break;
        }
      }
    }

    currentState = BotState.reposition;
  }

  void _performEvade(GameCharacter bot, Map<String, dynamic> params) {
    final projectiles = params['projectiles'] as List<Projectile>;
    if (projectiles.isEmpty) return;

    final closestProjectile = projectiles.reduce((a, b) {
      final distA = bot.position.distanceTo(a.position);
      final distB = bot.position.distanceTo(b.position);
      return distA < distB ? a : b;
    });

    // Move perpendicular to projectile direction
    final perpendicular = Vector2(-closestProjectile.direction.y, closestProjectile.direction.x);
    bot.velocity.x = perpendicular.x * (bot.stats.dexterity / 1.5);

    // Jump if projectile is low
    if (closestProjectile.position.y > bot.position.y - 50 &&
        bot.characterState.groundPlatform != null &&
        bot.characterState.stamina >= 20) {
      bot.velocity.y = -300;
      bot.characterState.groundPlatform = null;
      bot.characterState.stamina -= 20;
    }

    currentState = BotState.evade;
  }

  void _performDodge(GameCharacter bot, GameCharacter target) {
    final toTarget = target.position - bot.position;
    // Dodge away from target
    final dodgeDirection = Vector2(-toTarget.normalized().x, 0);
    bot.dodge(dodgeDirection);

    currentState = BotState.evade;
  }

  void _performJumpAttack(GameCharacter bot, GameCharacter target) {
    final toTarget = target.position - bot.position;
    bot.facingRight = toTarget.x > 0;

    // Jump towards target
    if (bot.characterState.groundPlatform != null && bot.characterState.stamina >= 20) {
      bot.velocity.y = -300;
      bot.velocity.x = toTarget.normalized().x * (bot.stats.dexterity / 2);
      bot.characterState.groundPlatform = null;
      bot.characterState.stamina -= 20;

      // Attack in air after a slight delay
      if (bot.characterState.attackCooldown <= 0) {
        bot.attack();
      }
    }

    currentState = BotState.attack;
  }

  void _handleImmediateThreats(GameCharacter bot, GameCharacter target, double dt) {
    // Emergency dodge for very close projectiles
    final immediateThreats = bot.game.projectiles.where((p) {
      if (p.enemyOwner == bot) return false;
      final dist = bot.position.distanceTo(p.position);
      return dist < 50 && _isProjectileHeadingTowards(bot, p);
    }).toList();

    if (immediateThreats.isNotEmpty && bot.characterState.dodgeCooldown <= 0 && bot.characterState.stamina >= 20) {
      final threat = immediateThreats.first;
      final dodgeDir = Vector2(-threat.direction.x, 0);
      bot.dodge(dodgeDir);
    }

    // Stop blocking if no immediate danger
    if (bot.characterState.isBlocking && !target.characterState.isAttacking && bot.position.distanceTo(target.position) > 250) {
      bot.stopBlock();
    }
  }

  bool _isProjectileHeadingTowards(GameCharacter bot, Projectile projectile) {
    final toBot = bot.position - projectile.position;
    final dot = toBot.dot(projectile.direction);
    return dot > 0; // Positive dot product means heading towards
  }

  Vector2 _predictTargetPosition(GameCharacter target, double timeAhead) {
    return target.position + (target.velocity * timeAhead);
  }

  @override
  bool shouldEvade(GameCharacter bot, List<Projectile> incomingProjectiles) {
    return incomingProjectiles.isNotEmpty && math.Random().nextDouble() < cautionLevel;
  }

  @override
  void onDamageTaken(GameCharacter bot, double damage) {
    consecutiveHits++;

    // Adapt behavior based on taking damage
    if (consecutiveHits > 3 && personality != BotPersonality.berserker) {
      // Become more defensive
      print('${bot.stats.name} bot: Switching to defensive stance!');
    }

    if (damage > 20) {
      print('${bot.stats.name} bot: Heavy damage taken! Retreating!');
    }
  }
}