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
  double stamina = 100; // NEW: Stamina system
  double maxStamina = 100;
  bool isCrouching = false;
  bool isClimbing = false;
  bool isWallSliding = false;
  bool isJumping = false;
  bool isAirborne = false; // NEW: Track if character is in air
  double airborneTime = 0; // NEW: How long in air
  double attackCooldown = 0;

  // NEW: Landing and recovery mechanics
  bool isLanding = false; // Character just landed
  double landingRecoveryTime = 0;
  double hardLandingThreshold = 400; // Fall speed for hard landing
  bool isStunned = false; // Stunned from hard landing
  double stunDuration = 0;

  // NEW: Attack momentum and commit
  bool isAttackCommitted = false; // Can't cancel attack
  double attackCommitTime = 0;
  double lastAttackDirection = 0; // Track attack momentum

  // NEW: Dodge/Roll mechanic
  bool isDodging = false;
  double dodgeDuration = 0;
  double dodgeCooldown = 0;
  Vector2 dodgeDirection = Vector2.zero();

  // NEW: Parry/Block mechanic
  bool isBlocking = false;
  double blockStamina = 0;
  double lastDamageTaken = 0;

  // NEW: Combo system
  int comboCount = 0;
  double comboTimer = 0;
  double comboWindow = 1.5; // Time window for combo

  // Animation
  SpriteAnimation? idleAnimation;
  SpriteAnimation? walkAnimation;
  SpriteAnimation? attackAnimation;
  SpriteAnimation? jumpAnimation;
  SpriteAnimation? landingAnimation;
  bool isAttacking = false;
  double attackAnimationTimer = 0;
  bool spritesLoaded = false;

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

    // Stamina regeneration (slower when blocking)
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

    // Handle attack animation
    if (attackAnimationTimer > 0) {
      attackAnimationTimer -= dt;
      if (attackAnimationTimer <= 0) {
        isAttacking = false;
      }
    }

    // Handle dodge roll
    if (isDodging) {
      dodgeDuration -= dt;
      if (dodgeDuration <= 0) {
        isDodging = false;
        velocity.x *= 0.3; // Slow down after dodge
      } else {
        // Fast movement during dodge with invincibility
        velocity.x = dodgeDirection.x * stats.dexterity * 15;
      }
    }

    // Handle stun from hard landing
    if (isStunned) {
      stunDuration -= dt;
      velocity.x = 0; // Can't move while stunned
      if (stunDuration <= 0) {
        isStunned = false;
      }
      return; // Skip other updates while stunned
    }

    // Handle landing recovery
    if (isLanding) {
      landingRecoveryTime -= dt;
      velocity.x *= 0.5; // Reduced movement during recovery
      if (landingRecoveryTime <= 0) {
        isLanding = false;
      }
    }

    // Check if character is dying
    if (health <= 0) {
      if (playerType == PlayerType.bot) {
        game.removeEnemy(this);
      } else {
        game.gameOver();
      }
      return;
    }

    // Update based on type (only if not stunned or in recovery)
    if (!isStunned && !isLanding) {
      if (playerType == PlayerType.human) {
        updateHumanControl(dt);
      } else {
        updateBotControl(dt);
      }
    }

    applyPhysics(dt);
    updateAnimation();

    size.y = isCrouching ? baseHeight / 2 : baseHeight;

    // Track airborne state
    bool wasAirborne = isAirborne;
    isAirborne = groundPlatform == null;

    if (isAirborne) {
      airborneTime += dt;
    } else if (wasAirborne && !isAirborne) {
      // Just landed - check for hard landing
      _handleLanding();
    }
  }

  // NEW: Dodge/Roll ability
  void dodge(Vector2 direction) {
    if (dodgeCooldown > 0 || isDodging || stamina < 20) return;

    isDodging = true;
    dodgeDuration = 0.3;
    dodgeCooldown = 2.0;
    stamina -= 20;
    dodgeDirection = direction.normalized();

    print('${stats.name}: Dodge roll!');
  }

  // NEW: Block ability
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

  // Helper method that child classes can call to handle common attack setup
  bool prepareAttack() {
    // Cannot attack while landing, stunned, dodging, or already attacking
    if (isLanding || isStunned || isDodging || attackCooldown > 0 || stamina < 15) {
      return false;
    }

    // Airborne attacks allowed but have longer recovery
    if (isAirborne) {
      attackCooldown = 1.0; // Longer cooldown for air attacks
      stamina -= 20;
    } else {
      attackCooldown = 0.5;
      stamina -= 15;
    }

    isAttacking = true;
    isAttackCommitted = true;
    attackCommitTime = 0.3; // Can't cancel attack for 0.3s
    attackAnimationTimer = 0.2;

    // Combo system
    if (comboTimer > 0) {
      comboCount++;
      comboTimer = comboWindow;

      // Bonus damage for combos
      if (comboCount >= 3) {
        print('${stats.name}: COMBO x${comboCount}!');
      }
    } else {
      comboCount = 1;
      comboTimer = comboWindow;
    }

    // Attack momentum - slight forward movement
    lastAttackDirection = facingRight ? 1 : -1;
    if (!isAirborne) {
      velocity.x += lastAttackDirection * 50;
    }

    return true;
  }

  void applyPhysics(double dt) {
    // Apply gravity (not during dodge)
    if (groundPlatform == null && !isClimbing && !isDodging) {
      velocity.y += 1000 * dt;
      velocity.y = math.min(velocity.y, 800); // Terminal velocity
    }

    // Friction when grounded and not attacking
    if (groundPlatform != null && !isAttackCommitted) {
      velocity.x *= 0.85;
    }

    // Reduced air control
    if (isAirborne && !isDodging) {
      velocity.x *= 0.98; // Air resistance
    }

    position += velocity * dt;

    // Platform collision detection
    groundPlatform = null;
    for (final platform in game.platforms) {
      if (_checkPlatformCollision(platform)) {
        if (velocity.y > 0 && position.y < platform.position.y) {
          position.y = platform.position.y - platform.size.y / 2 - size.y / 2;
          groundPlatform = platform;
          isJumping = false;
        }
      }
    }
  }

  void _handleLanding() {
    final fallSpeed = velocity.y;

    if (fallSpeed > hardLandingThreshold) {
      // Hard landing - stun and damage
      final stunTime = math.min(1.0, (fallSpeed - hardLandingThreshold) / 200);
      isStunned = true;
      stunDuration = stunTime;

      // Take minor fall damage
      final fallDamage = (fallSpeed - hardLandingThreshold) / 50;
      takeDamage(fallDamage);

      print('${stats.name}: Hard landing! Stunned for ${stunTime.toStringAsFixed(1)}s');
    } else if (fallSpeed > 200) {
      // Normal landing - brief recovery
      isLanding = true;
      landingRecoveryTime = 0.2;
    }

    airborneTime = 0;
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

    if (isStunned) {
      // Stunned animation (could be a special sprite)
      animation = idleAnimation;
      return;
    }

    if (isLanding && landingAnimation != null) {
      animation = landingAnimation;
    } else if (isDodging) {
      animation = walkAnimation; // Roll animation
    } else if (isAttacking && attackAnimation != null) {
      animation = attackAnimation;
    } else if (isAirborne && jumpAnimation != null) {
      animation = jumpAnimation;
    } else {
      if (velocity.x.abs() > 10) {
        animation = walkAnimation;
      } else {
        animation = idleAnimation;
      }
    }

    scale.x = facingRight ? 1 : -1;
  }

  void takeDamage(double damage) {
    // Invincibility during dodge
    if (isDodging) {
      print('${stats.name}: Dodged attack!');
      return;
    }

    // Block reduces damage
    if (isBlocking && stamina > 0) {
      final blockedDamage = damage * 0.3; // Block 70% of damage
      damage = blockedDamage;
      stamina -= 15; // Blocking costs stamina

      if (stamina < 0) {
        stamina = 0;
        isBlocking = false; // Guard broken
        print('${stats.name}: Guard broken!');
      } else {
        print('${stats.name}: Blocked! (${damage.toInt()} damage)');
      }
    }

    health = math.max(0, health - damage);
    lastDamageTaken = damage;

    // Interrupt attack if not committed
    if (!isAttackCommitted) {
      isAttacking = false;
      attackAnimationTimer = 0;
    }

    // Knockback effect
    if (damage > 10 && !isBlocking) {
      velocity.x = -lastAttackDirection * 100;
      comboCount = 0; // Reset combo on hit
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

    // Visual effects
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

    // Stamina bar (for human player in HUD)
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

    // Combo indicator
    if (comboCount > 1) {
      _renderComboIndicator(canvas);
    }
  }


  void _renderStunEffect(Canvas canvas) {
    // Stars spinning around head
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
    // Motion blur trail
    final opacity = (dodgeDuration / 0.3) * 0.5;
    final paint = Paint()..color = stats.color.withOpacity(opacity);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
      paint,
    );
  }

  void _renderBlockEffect(Canvas canvas) {
    // Shield effect
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
