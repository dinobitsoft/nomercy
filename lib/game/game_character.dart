import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'dart:math' as math;

import '../action_game.dart';
import '../character_stats.dart';
import '../player_type.dart';
import '../tiled_platform.dart';
import 'bot_tactic.dart';

typedef Player = GameCharacter;
typedef Enemy = GameCharacter;

abstract class GameCharacter extends SpriteAnimationComponent with HasGameRef<ActionGame> {
  final CharacterStats stats;
  final PlayerType playerType;
  BotTactic? botTactic;

  // Character dimensions
  static const double baseWidth = 160.0;
  static const double baseHeight = 160.0;

  // Physics
  Vector2 velocity = Vector2.zero();
  TiledPlatform? groundPlatform;
  bool facingRight = true;

  // State
  double health = 100;
  double stamina = 100;
  double maxStamina = 100;
  bool isCrouching = false;
  bool isClimbing = false;
  bool isWallSliding = false;
  bool isJumping = false;
  bool isAirborne = false;
  double airborneTime = 0;
  double attackCooldown = 0;

  // Landing and recovery mechanics
  bool isLanding = false;
  double landingRecoveryTime = 0;
  double hardLandingThreshold = 400;
  bool isStunned = false;
  double stunDuration = 0;

  // Attack momentum and commit
  bool isAttackCommitted = false;
  double attackCommitTime = 0;
  double lastAttackDirection = 0;

  // Dodge/Roll mechanic
  bool isDodging = false;
  double dodgeDuration = 0;
  double dodgeCooldown = 0;
  Vector2 dodgeDirection = Vector2.zero();

  // Parry/Block mechanic
  bool isBlocking = false;
  double blockStamina = 0;
  double lastDamageTaken = 0;

  // Combo system
  int comboCount = 0;
  double comboTimer = 0;
  double comboWindow = 1.5;

  // Animation
  SpriteAnimation? idleAnimation;
  SpriteAnimation? walkAnimation;
  SpriteAnimation? attackAnimation;
  SpriteAnimation? jumpAnimation;
  SpriteAnimation? landingAnimation;
  bool isAttacking = false;
  double attackAnimationTimer = 0;
  bool spritesLoaded = false;

  // State tracking
  bool wasGrounded = false;
  double landingAnimationTimer = 0;
  double jumpAnimationTimer = 0;

  GameCharacter({
    required Vector2 position,
    required this.stats,
    required this.playerType,
    this.botTactic,
  }) : super(position: position) {
    size = Vector2(baseWidth, baseHeight);
    anchor = Anchor.center;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _loadSprites();
  }

  Future<void> _loadSprites() async {
    final characterName = stats.name.toLowerCase();

    try {
      final sprite = await game.loadSprite('$characterName.png');
      idleAnimation = SpriteAnimation.spriteList([sprite], stepTime: 1.0);
      walkAnimation = SpriteAnimation.spriteList([sprite], stepTime: 0.2);
      jumpAnimation = SpriteAnimation.spriteList([sprite], stepTime: 0.1);
      landingAnimation = SpriteAnimation.spriteList([sprite], stepTime: 0.1);

      try {
        final attackSprite = await game.loadSprite('${characterName}_attack.png');
        attackAnimation = SpriteAnimation.spriteList([attackSprite, sprite], stepTime: 0.1);
      } catch (e) {
        attackAnimation = idleAnimation;
      }

      try {
        final jumpSprite = await game.loadSprite('${characterName}_jump.png');
        jumpAnimation = SpriteAnimation.spriteList([jumpSprite], stepTime: 0.1);
      } catch (e) {
        jumpAnimation = idleAnimation;
      }

      try {
        final landingSprite = await game.loadSprite('${characterName}_landing.png');
        landingAnimation = SpriteAnimation.spriteList([landingSprite], stepTime: 0.1);
      } catch (e) {
        landingAnimation = idleAnimation;
      }

      try {
        final walkSprite = await game.loadSprite('${characterName}_walk.png');
        landingAnimation = SpriteAnimation.spriteList([walkSprite], stepTime: 0.1);
      } catch (e) {
        landingAnimation = idleAnimation;
      }

      animation = idleAnimation;
      spritesLoaded = true;
    } catch (e) {
      print('Could not load sprite for $characterName: $e');
      spritesLoaded = false;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Update timers
    if (attackCooldown > 0) attackCooldown -= dt;
    if (dodgeCooldown > 0) dodgeCooldown -= dt;
    if (comboTimer > 0) {
      comboTimer -= dt;
      if (comboTimer <= 0) comboCount = 0;
    }

    // Track animation timers
    if (landingAnimationTimer > 0) landingAnimationTimer -= dt;
    if (jumpAnimationTimer > 0) jumpAnimationTimer -= dt;

    // ✅ Track attack animation timer separately
    if (attackAnimationTimer > 0) {
      attackAnimationTimer -= dt;
      if (attackAnimationTimer <= 0) {
        isAttacking = false; // Only clear when animation completes
      }
    }

    // Stamina regeneration
    if (stamina < maxStamina && !isBlocking && !isDodging && !isAttacking) {
      stamina = math.min(maxStamina, stamina + 15 * dt);
    }

    // Attack commit system
    if (attackCommitTime > 0) {
      attackCommitTime -= dt;
      if (attackCommitTime <= 0) {
        isAttackCommitted = false;
      }
    }

    // Handle dodge roll
    if (isDodging) {
      dodgeDuration -= dt;
      if (dodgeDuration <= 0) {
        isDodging = false;
        velocity.x *= 0.3;
      } else {
        velocity.x = dodgeDirection.x * stats.dexterity * 15;
      }
    }

    // Handle stun
    if (isStunned) {
      stunDuration -= dt;
      velocity.x = 0;
      if (stunDuration <= 0) {
        isStunned = false;
      }
      return;
    }

    // Handle landing recovery
    if (isLanding) {
      landingRecoveryTime -= dt;
      velocity.x *= 0.5;
      if (landingRecoveryTime <= 0) {
        isLanding = false;
      }
    }

    // Check if dying
    if (health <= 0) {
      if (playerType == PlayerType.bot) {
        game.removeEnemy(this);
      } else {
        game.gameOver();
      }
      return;
    }

    // Store ground state BEFORE physics
    wasGrounded = groundPlatform != null;

    // Update based on type
    if (!isStunned && !isLanding) {
      if (playerType == PlayerType.human) {
        updateHumanControl(dt);
      } else {
        updateBotControl(dt);
      }
    }

    // Apply physics
    applyPhysics(dt);

    // Check landing AFTER physics
    final isGroundedNow = groundPlatform != null;

    if (!wasGrounded && isGroundedNow) {
      // Just landed!
      _handleLanding();
      landingAnimationTimer = 0.25; // ✅ Increased for better visibility
    }

    if (wasGrounded && !isGroundedNow) {
      // Just left ground
      jumpAnimationTimer = 0.3;
      isAirborne = true;
      airborneTime = 0;
    }

    if (isGroundedNow) {
      isAirborne = false;
      airborneTime = 0;
    } else {
      isAirborne = true;
      airborneTime += dt;
    }

    // Update animation
    updateAnimation();

    // Update size
    size.y = isCrouching ? baseHeight / 2 : baseHeight;
  }

  void dodge(Vector2 direction) {
    if (dodgeCooldown > 0 || isDodging || stamina < 20) return;

    isDodging = true;
    dodgeDuration = 0.3;
    dodgeCooldown = 2.0;
    stamina -= 20;
    dodgeDirection = direction.normalized();

    print('${stats.name}: Dodge roll!');
  }

  void startBlock() {
    if (stamina < 10 || isDodging || isAttacking) return;
    isBlocking = true;
  }

  void stopBlock() {
    isBlocking = false;
  }

  void updateHumanControl(double dt);
  void updateBotControl(double dt);
  void attack();

  bool prepareAttack() {
    if (isLanding || isStunned || isDodging || attackCooldown > 0 || stamina < 15) {
      return false;
    }

    if (isAirborne) {
      attackCooldown = 1.0;
      stamina -= 20;
    } else {
      attackCooldown = 0.5;
      stamina -= 15;
    }

    isAttacking = true;
    isAttackCommitted = true;
    attackCommitTime = 0.3;
    attackAnimationTimer = 0.3; // ✅ Increased from 0.2 for better visibility

    // Combo system
    if (comboTimer > 0) {
      comboCount++;
      comboTimer = comboWindow;

      if (comboCount >= 3) {
        print('${stats.name}: COMBO x$comboCount!');
      }
    } else {
      comboCount = 1;
      comboTimer = comboWindow;
    }

    // Attack momentum
    lastAttackDirection = facingRight ? 1 : -1;
    if (!isAirborne) {
      velocity.x += lastAttackDirection * 50;
    }

    return true;
  }

  void applyPhysics(double dt) {
    // Apply gravity
    if (groundPlatform == null && !isClimbing && !isDodging) {
      velocity.y += 1000 * dt;
      velocity.y = math.min(velocity.y, 800);
    }

    // Friction when grounded
    if (groundPlatform != null && !isAttackCommitted) {
      velocity.x *= 0.85;
    }

    // Air resistance
    if (groundPlatform == null && !isDodging) {
      velocity.x *= 0.98;
    }

    // Move character
    position += velocity * dt;

    // Platform collision detection
    TiledPlatform? newGroundPlatform;

    for (final platform in game.platforms) {
      if (_checkPlatformCollision(platform)) {
        // Only land if falling down and above platform
        if (velocity.y > 0 && position.y < platform.position.y) {
          position.y = platform.position.y - platform.size.y / 2 - size.y / 2;
          newGroundPlatform = platform;
          velocity.y = 0;
          isJumping = false;
          break;
        }
      }
    }

    groundPlatform = newGroundPlatform;
  }

  void _handleLanding() {
    final fallSpeed = velocity.y;

    if (fallSpeed > hardLandingThreshold) {
      // Hard landing - stun
      final stunTime = math.min(1.0, (fallSpeed - hardLandingThreshold) / 200);
      isStunned = true;
      stunDuration = stunTime;

      final fallDamage = (fallSpeed - hardLandingThreshold) / 50;
      takeDamage(fallDamage);

      print('${stats.name}: Hard landing! Stunned for ${stunTime.toStringAsFixed(1)}s');
    } else if (fallSpeed > 200) {
      // Normal landing - brief recovery
      isLanding = true;
      landingRecoveryTime = 0.25; // ✅ Increased from 0.15 for better visibility
    }

    velocity.y = 0;
  }

  bool _checkPlatformCollision(TiledPlatform platform) {
    final dx = (position.x - platform.position.x).abs();
    final dy = (position.y - platform.position.y).abs();
    return dx < (size.x + platform.size.x) / 2 &&
        dy < (size.y + platform.size.y) / 2;
  }

  void updateAnimation() {
    if (!spritesLoaded) return;

    // ✅ FIXED PRIORITY ORDER:
    // 1. Stunned (overrides everything)
    // 2. Attacking (shows during any state - HIGHEST PRIORITY)
    // 3. Landing (just touched ground)
    // 4. Dodging
    // 5. Jumping/Airborne
    // 6. Moving/Idle

    if (isStunned) {
      animation = idleAnimation;
    }
    else if (isAttacking && attackAnimation != null && attackAnimationTimer > 0) {
      animation = attackAnimation;
    }
    // Landing animation
    else if ((isLanding || landingAnimationTimer > 0) && landingAnimation != null) {
      animation = landingAnimation;
    }
    // Jump/Airborne
    else if ((isAirborne || jumpAnimationTimer > 0) && jumpAnimation != null) {
      animation = jumpAnimation;
    }
    // Dodge roll
    else if (isDodging) {
      animation = walkAnimation;
    }
    // Ground movement
    else {
      if (velocity.x.abs() > 10) {
        animation = walkAnimation;
      } else {
        animation = idleAnimation;
      }
    }

    scale.x = facingRight ? 1 : -1;
  }

  void takeDamage(double damage) {
    if (isDodging) {
      print('${stats.name}: Dodged attack!');
      return;
    }

    if (isBlocking && stamina > 0) {
      final blockedDamage = damage * 0.3;
      damage = blockedDamage;
      stamina -= 15;

      if (stamina < 0) {
        stamina = 0;
        isBlocking = false;
        print('${stats.name}: Guard broken!');
      } else {
        print('${stats.name}: Blocked! (${damage.toInt()} damage)');
      }
    }

    health = math.max(0, health - damage);
    lastDamageTaken = damage;

    if (!isAttackCommitted) {
      isAttacking = false;
      attackAnimationTimer = 0;
    }

    if (damage > 10 && !isBlocking) {
      velocity.x = -lastAttackDirection * 100;
      comboCount = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (!spritesLoaded) {
      final paint = Paint()..color = stats.color;
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
        paint,
      );
    }

    if (isStunned) {
      _renderStunEffect(canvas);
    }

    if (isDodging) {
      _renderDodgeEffect(canvas);
    }

    if (isBlocking) {
      _renderBlockEffect(canvas);
    }

    // Health bar for bots
    if (playerType == PlayerType.bot) {
      final healthBarWidth = size.x;
      final healthPercent = (health / 100).clamp(0.0, 1.0);
      canvas.drawRect(
        Rect.fromLTWH(-size.x / 2, -size.y / 2 - 20, healthBarWidth, 10),
        Paint()..color = Colors.red,
      );
      canvas.drawRect(
        Rect.fromLTWH(-size.x / 2, -size.y / 2 - 20, healthBarWidth * healthPercent, 10),
        Paint()..color = Colors.green,
      );
    }

    // Stamina bar for human player
    if (playerType == PlayerType.human) {
      final staminaPercent = (stamina / maxStamina).clamp(0.0, 1.0);
      canvas.drawRect(
        Rect.fromLTWH(-size.x / 2, size.y / 2 + 5, size.x, 5),
        Paint()..color = Colors.grey.withOpacity(0.5),
      );
      canvas.drawRect(
        Rect.fromLTWH(-size.x / 2, size.y / 2 + 5, size.x * staminaPercent, 5),
        Paint()..color = Colors.yellow,
      );
    }

    if (comboCount > 1) {
      _renderComboIndicator(canvas);
    }

    // TODO: DEBUG: Show current state (REMOVE after testing)
    final debugStates = <String>[];
    if (isAttacking) debugStates.add('ATK');
    if (isLanding) debugStates.add('LAND');
    if (isAirborne) debugStates.add('AIR');
    if (attackAnimationTimer > 0) debugStates.add('ATK_ANIM:${attackAnimationTimer.toStringAsFixed(2)}');
    if (landingAnimationTimer > 0) debugStates.add('LAND_ANIM:${landingAnimationTimer.toStringAsFixed(2)}');

    if (debugStates.isNotEmpty) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: debugStates.join(' | '),
          style: const TextStyle(
            color: Colors.yellow,
            fontSize: 10,
            backgroundColor: Colors.black,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(-50, size.y / 2 + 20));
    }
  }

  void _renderStunEffect(Canvas canvas) {
    final starCount = 3;
    final radius = 40.0;
    final rotation = (DateTime.now().millisecondsSinceEpoch / 200) % (math.pi * 2);

    for (int i = 0; i < starCount; i++) {
      final angle = rotation + (i * math.pi * 2 / starCount);
      final x = math.cos(angle) * radius;
      final y = math.sin(angle) * radius - size.y / 2 - 20;

      final paint = Paint()..color = Colors.yellow;
      canvas.drawCircle(Offset(x, y), 5, paint);
    }
  }

  void _renderDodgeEffect(Canvas canvas) {
    final opacity = (dodgeDuration / 0.3) * 0.5;
    final paint = Paint()..color = stats.color.withOpacity(opacity);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
      paint,
    );
  }

  void _renderBlockEffect(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(Offset.zero, size.x / 2 + 10, paint);
  }

  void _renderComboIndicator(Canvas canvas) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'x$comboCount',
        style: const TextStyle(
          color: Colors.orange,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(-textPainter.width / 2, -size.y / 2 - 40));
  }
}