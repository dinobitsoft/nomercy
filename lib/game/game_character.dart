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

abstract class GameCharacter extends SpriteAnimationComponent with HasGameReference<ActionGame> {
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

  /// ✅ IMPROVED: Separate idle and walk sprites with sprite sheet support
  Future<void> _loadSprites() async {
    final characterName = stats.name.toLowerCase();
    print('Loading sprites for: $characterName');

    try {
      // === IDLE ANIMATION ===
      try {
        final idleImage = await game.images.load('${characterName}_idle.png');

        // Check if it's a sprite sheet (width > height means multiple frames)
        if (idleImage.width > idleImage.height * 1.5) {
          // Sprite sheet detected
          final frameCount = (idleImage.width / idleImage.height).round();
          idleAnimation = SpriteAnimation.fromFrameData(
            idleImage,
            SpriteAnimationData.sequenced(
              amount: frameCount,
              stepTime: 0.2,
              textureSize: Vector2(idleImage.height.toDouble(), idleImage.height.toDouble()),
            ),
          );
          print('  ✅ Loaded idle sprite sheet ($frameCount frames)');
        } else {
          // Single sprite
          final idleSprite = Sprite(idleImage);
          idleAnimation = SpriteAnimation.spriteList([idleSprite], stepTime: 0.5);
          print('  ✅ Loaded idle sprite');
        }
      } catch (e) {
        // Fallback to base character sprite
        try {
          final baseSprite = await game.loadSprite('$characterName.png');
          idleAnimation = SpriteAnimation.spriteList([baseSprite], stepTime: 1.0);
          print('  ⚠️ Using base sprite for idle');
        } catch (e2) {
          throw Exception('No idle sprite found for $characterName');
        }
      }

      // === WALK ANIMATION ===
      try {
        final walkImage = await game.images.load('${characterName}_walk.png');

        if (walkImage.width > walkImage.height * 1.5) {
          // Walk sprite sheet
          final frameCount = (walkImage.width / walkImage.height).round();
          walkAnimation = SpriteAnimation.fromFrameData(
            walkImage,
            SpriteAnimationData.sequenced(
              amount: frameCount,
              stepTime: 0.1,  // Faster for smooth walk cycle
              textureSize: Vector2(walkImage.height.toDouble(), walkImage.height.toDouble()),
            ),
          );
          print('  ✅ Loaded walk sprite sheet ($frameCount frames)');
        } else {
          // Single walk sprite
          final walkSprite = Sprite(walkImage);
          walkAnimation = SpriteAnimation.spriteList([walkSprite], stepTime: 0.15);
          print('  ✅ Loaded walk sprite');
        }
      } catch (e) {
        // Fallback to idle animation
        walkAnimation = idleAnimation;
        print('  ⚠️ Walk sprite not found, using idle');
      }

      // === ATTACK ANIMATION ===
      try {
        final attackImage = await game.images.load('${characterName}_attack.png');

        if (attackImage.width > attackImage.height * 1.5) {
          final frameCount = (attackImage.width / attackImage.height).round();
          attackAnimation = SpriteAnimation.fromFrameData(
            attackImage,
            SpriteAnimationData.sequenced(
              amount: frameCount,
              stepTime: 0.06,
              textureSize: Vector2(attackImage.height.toDouble(), attackImage.height.toDouble()),
              loop: false,  // Attack shouldn't loop
            ),
          );
          print('  ✅ Loaded attack sprite sheet ($frameCount frames)');
        } else {
          final attackSprite = Sprite(attackImage);
          attackAnimation = SpriteAnimation.spriteList([attackSprite], stepTime: 0.1);
          print('  ✅ Loaded attack sprite');
        }
      } catch (e) {
        attackAnimation = idleAnimation;
        print('  ⚠️ Attack sprite not found, using idle');
      }

      // === JUMP ANIMATION ===
      try {
        final jumpImage = await game.images.load('${characterName}_jump.png');

        if (jumpImage.width > jumpImage.height * 1.5) {
          final frameCount = (jumpImage.width / jumpImage.height).round();
          jumpAnimation = SpriteAnimation.fromFrameData(
            jumpImage,
            SpriteAnimationData.sequenced(
              amount: frameCount,
              stepTime: 0.15,
              textureSize: Vector2(jumpImage.height.toDouble(), jumpImage.height.toDouble()),
            ),
          );
          print('  ✅ Loaded jump sprite sheet ($frameCount frames)');
        } else {
          final jumpSprite = Sprite(jumpImage);
          jumpAnimation = SpriteAnimation.spriteList([jumpSprite], stepTime: 0.1);
          print('  ✅ Loaded jump sprite');
        }
      } catch (e) {
        jumpAnimation = idleAnimation;
        print('  ⚠️ Jump sprite not found, using idle');
      }

      // === LANDING ANIMATION ===
      try {
        final landingImage = await game.images.load('${characterName}_landing.png');

        if (landingImage.width > landingImage.height * 1.5) {
          final frameCount = (landingImage.width / landingImage.height).round();
          landingAnimation = SpriteAnimation.fromFrameData(
            landingImage,
            SpriteAnimationData.sequenced(
              amount: frameCount,
              stepTime: 0.125,
              textureSize: Vector2(landingImage.height.toDouble(), landingImage.height.toDouble()),
              loop: false,
            ),
          );
          print('  ✅ Loaded landing sprite sheet ($frameCount frames)');
        } else {
          final landingSprite = Sprite(landingImage);
          landingAnimation = SpriteAnimation.spriteList([landingSprite], stepTime: 0.1);
          print('  ✅ Loaded landing sprite');
        }
      } catch (e) {
        landingAnimation = idleAnimation;
        print('  ⚠️ Landing sprite not found, using idle');
      }

      // Set initial animation
      animation = idleAnimation;
      spritesLoaded = true;

      print('✅ All sprites loaded for $characterName');
    } catch (e) {
      print('❌ Fatal error loading sprites for $characterName: $e');
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

    // Track attack animation timer
    if (attackAnimationTimer > 0) {
      attackAnimationTimer -= dt;
      if (attackAnimationTimer <= 0) {
        isAttacking = false;
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
      _handleLanding();
      landingAnimationTimer = 0.25;
      isLanding = true;
    }

    if (wasGrounded && !isGroundedNow) {
      jumpAnimationTimer = 0.3;
      isAirborne = true;
      isJumping = true;
      airborneTime = 0;
    }

    if (isGroundedNow) {
      isAirborne = false;
      airborneTime = 0;
      isJumping = false;
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
    attackAnimationTimer = 0.3;

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
      final stunTime = math.min(1.0, (fallSpeed - hardLandingThreshold) / 200);
      isStunned = true;
      stunDuration = stunTime;

      final fallDamage = (fallSpeed - hardLandingThreshold) / 50;
      takeDamage(fallDamage);

      print('${stats.name}: Hard landing! Stunned for ${stunTime.toStringAsFixed(1)}s');
    } else if (fallSpeed > 200) {
      isLanding = true;
      landingRecoveryTime = 0.25;
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

    // Priority: Stun > Attack > Landing > Dodge > Jump > Walk > Idle

    if (isStunned) {
      animation = idleAnimation;
    }
    else if (isAttacking && attackAnimation != null && attackAnimationTimer > 0) {
      animation = attackAnimation;
    }
    else if (isLanding && landingAnimation != null && landingAnimationTimer > 0) {
      animation = landingAnimation;
    }
    else if (isDodging) {
      animation = walkAnimation;
    }
    else if ((isAirborne || isJumping || jumpAnimationTimer > 0) && jumpAnimation != null) {
      animation = jumpAnimation;
    }
    // ✅ FIXED: Separate walk and idle based on velocity
    else {
      if (velocity.x.abs() > 5) {
        animation = walkAnimation;  // Uses knight_walk.png
      } else {
        animation = idleAnimation;  // Uses knight_idle.png
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