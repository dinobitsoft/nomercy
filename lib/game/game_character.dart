import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'dart:math' as math;

import '../config/game_config.dart';
import '../core/action_events.dart';
import '../core/event_bus.dart';
import '../state/character_animation_state.dart';
import '../state/character_state_machine.dart';
import 'action_game.dart';
import '../character_stats.dart';
import '../player_type.dart';
import '../tiled_platform.dart';
import 'bot_tactic.dart';

typedef Player = GameCharacter;
typedef Enemy = GameCharacter;

abstract class GameCharacter extends SpriteAnimationComponent with HasGameReference<ActionGame> {

  final String uniqueId;

  final CharacterStats stats;
  final PlayerType playerType;
  BotTactic? botTactic;

  // Event bus for actions
  final EventBus _eventBus = EventBus();

  // Animation tracking
  String _currentAnimationState = 'idle';
  String _previousAnimationState = 'idle';
  late final CharacterStateMachine _stateMachine = CharacterStateMachine();

  // Block tracking
  DateTime? _blockStartTime;

  // Character dimensions
  static const double baseWidth = GameConfig.characterWidth;
  static const double baseHeight = GameConfig.characterHeight;

  // Physics
  Vector2 velocity = Vector2.zero();
  TiledPlatform? groundPlatform;
  bool facingRight = true;

  // State
  double health = GameConfig.characterBaseHealth;
  double stamina = GameConfig.characterBaseStamina;
  double maxStamina = 100;
  bool isCrouching = false;
  bool isClimbing = false;
  bool isWallSliding = false;
  bool isJumping = false;
  bool isAirborne = false;
  double airborneTime = 0;
  double attackCooldown = GameConfig.attackCooldown;

  // Landing and recovery mechanics
  bool isLanding = false;
  double landingRecoveryTime = GameConfig.landingRecoveryTime;
  double hardLandingThreshold = GameConfig.hardLandingThreshold;
  bool isStunned = false;
  double stunDuration = 0;

  // Attack momentum and commit
  bool isAttackCommitted = false;
  double attackCommitTime = GameConfig.attackCommitTime;
  double lastAttackDirection = 0;

  // Dodge/Roll mechanic
  bool isDodging = false;
  double dodgeDuration = GameConfig.dodgeDuration;
  double dodgeCooldown = GameConfig.dodgeCooldown;
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
    String? customId,
  }) : uniqueId = customId ?? _generateUniqueId(), super(position: position) {
    size = Vector2(baseWidth, baseHeight);
    anchor = Anchor.center;
  }

  static String _generateUniqueId() {
    return 'char_${DateTime.now().millisecondsSinceEpoch}_${_idCounter++}';
  }

  static int _idCounter = 0;

  // Helper method to check if this is the player
  bool get isPlayer => playerType == PlayerType.human;

  // Helper method to check if this is a bot
  bool get isBot => playerType == PlayerType.bot;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _loadSprites();
  }

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

// lib/game/game_character.dart - UPDATE METHOD ENHANCEMENT
// Replace the existing update() method with this enhanced version

  @override
  void update(double dt) {
    super.update(dt);

    // Skip all updates if dead
    if (health <= 0) {
      velocity = Vector2.zero();
      return;
    }

    // Update state machine timer
    _stateMachine.update(dt);

    // Store ground state BEFORE any updates
    wasGrounded = groundPlatform != null;

    // Update timers first
    _updateTimers(dt);

    // Handle state-specific updates (stamina, dodge, etc.)
    _handleStates(dt);

    // Update based on type (skip if stunned)
    if (!isStunned && health > 0) {
      // Landing allows limited control but not full actions
      if (isLanding && landingAnimationTimer > 0.1) {
        // Can only apply friction during landing
        velocity.x *= 0.8;
      } else {
        // Full control
        if (playerType == PlayerType.human) {
          updateHumanControl(dt);
        } else {
          updateBotControl(dt);
        }
      }
    }

    // Apply physics BEFORE checking ground state
    applyPhysics(dt);

    // NOW check ground state changes AFTER physics
    final isGroundedNow = groundPlatform != null;

    // Detect takeoff (was grounded, now airborne)
    if (wasGrounded && !isGroundedNow && velocity.y < -10) {
      jumpAnimationTimer = 0.3;
      isAirborne = true;
      isJumping = true;
      airborneTime = 0;

      _eventBus.emit(CharacterAirborneEvent(
        characterId: stats.name,
        position: position.clone(),
        velocity: velocity.clone(),
      ));
    }

    // Detect landing (was airborne, now grounded)
    if (!wasGrounded && isGroundedNow && velocity.y > 50) {
      handleLandingWithEvent();
      landingAnimationTimer = 0.25;
      isLanding = true;
      isAirborne = false;
      isJumping = false;
    }

    // Update airborne state
    if (isGroundedNow) {
      isAirborne = false;
      airborneTime = 0;
      isJumping = false;
    } else {
      isAirborne = true;
      airborneTime += dt;
    }

    // CRITICAL: Update animation using state machine
    updateAnimationWithEvents();

    // Update size
    size.y = isCrouching ? baseHeight / 2 : baseHeight;

    // Emit idle event if truly idle
    if (isGroundedNow && velocity.x.abs() < 5 && !isAttacking &&
        !isBlocking && !isDodging && !isJumping && !isAirborne) {
      if (_currentAnimationState != 'idle') {
        _eventBus.emit(CharacterIdleEvent(
          characterId: stats.name,
          position: position.clone(),
        ));
      }
    }
  }

  /// Enhanced animation update with proper state machine integration
  void updateAnimationWithEvents() {
    if (!spritesLoaded) return;

    // Evaluate what state we SHOULD be in
    final desiredState = _stateMachine.evaluateState(this);

    // Try to change state (respects transition rules)
    final transitionSucceeded = _stateMachine.requestStateChange(desiredState);

    // Get current state from machine
    final currentStateEnum = _stateMachine.currentState;

    // Map state to animation
    SpriteAnimation? newAnimation;

    switch (currentStateEnum) {
      case CharacterAnimState.idle:
        newAnimation = idleAnimation;
        break;
      case CharacterAnimState.walking:
        newAnimation = walkAnimation;
        break;
      case CharacterAnimState.jumping:
      case CharacterAnimState.falling:
        newAnimation = jumpAnimation;
        break;
      case CharacterAnimState.landing:
        newAnimation = landingAnimation;
        break;
      case CharacterAnimState.attacking:
        newAnimation = attackAnimation;
        break;
      case CharacterAnimState.dodging:
      case CharacterAnimState.blocking:
      case CharacterAnimState.stunned:
        newAnimation = idleAnimation; // Fallback
        break;
      case CharacterAnimState.dead:
        newAnimation = null;
        break;
    }

    // Only emit event if state ACTUALLY changed
    if (transitionSucceeded) {
      final stateString = currentStateEnum.toString().split('.').last;

      _eventBus.emit(CharacterAnimationChangedEvent(
        characterId: stats.name,
        position: position.clone(),
        previousAnimation: _currentAnimationState,
        newAnimation: stateString,
        isLooping: currentStateEnum == CharacterAnimState.idle ||
            currentStateEnum == CharacterAnimState.walking,
      ));

      _currentAnimationState = stateString;
    }

    // Apply animation if different
    if (newAnimation != null && animation != newAnimation) {
      animation = newAnimation;
    }

    // Apply facing direction
    scale.x = facingRight ? 1 : -1;
  }

  /// Enhanced physics with proper friction and air resistance
  void applyPhysics(double dt) {
    // Apply gravity (only when not on ground and not climbing)
    if (groundPlatform == null && !isClimbing && !isDodging) {
      velocity.y += GameConfig.gravity * dt;
      velocity.y = math.min(velocity.y, GameConfig.maxFallSpeed);
    }

    // Ground friction - stronger when not attacking or dodging
    if (groundPlatform != null && !isAttackCommitted && !isDodging) {
      // Enhanced friction based on state
      final frictionMultiplier = isLanding ? 0.7 : 1.0;
      velocity.x *= GameConfig.groundFriction * frictionMultiplier;

      // Stop completely if very slow
      if (velocity.x.abs() < 5) {
        velocity.x = 0;
      }
    }

    // Air resistance - apply when airborne
    if (groundPlatform == null && !isDodging) {
      velocity.x *= GameConfig.airResistance;
    }

    // Dodge has its own movement
    if (isDodging) {
      // Dodge movement is handled in _handleStates
      // Don't apply friction during dodge
    }

    // Move character
    position += velocity * dt;

    // Platform collision detection - ENHANCED VERSION
    TiledPlatform? newGroundPlatform;
    double closestPlatformY = double.infinity;

    for (final platform in game.platforms) {
      // Calculate platform bounds (Anchor.center)
      final platformLeft = platform.position.x - platform.size.x / 2;
      final platformRight = platform.position.x + platform.size.x / 2;
      final platformTop = platform.position.y - platform.size.y / 2;

      // Calculate character bounds (Anchor.center)
      final charLeft = position.x - size.x / 2;
      final charRight = position.x + size.x / 2;
      final charBottom = position.y + size.y / 2;

      // Check horizontal overlap
      final horizontalOverlap = charRight > platformLeft && charLeft < platformRight;

      if (!horizontalOverlap) continue;

      // Check if character is falling onto platform (velocity.y >= 0)
      // and character's bottom is near or past platform's top
      final distanceToPlatform = charBottom - platformTop;

      // Enhanced landing detection - more forgiving
      if (velocity.y >= -50 && distanceToPlatform >= 0 && distanceToPlatform < 30) {
        // Character is landing on this platform
        if (platformTop < closestPlatformY) {
          closestPlatformY = platformTop;
          newGroundPlatform = platform;
        }
      }
    }

    // Apply platform collision
    if (newGroundPlatform != null) {
      // Snap character to platform surface
      position.y = closestPlatformY - size.y / 2;

      // Stop vertical velocity only if falling
      if (velocity.y > 0) {
        velocity.y = 0;
      }
      isJumping = false;
    }

    groundPlatform = newGroundPlatform;
  }

  /// Update all timers
  void _updateTimers(double dt) {
    if (attackCooldown > 0) attackCooldown -= dt;
    if (dodgeCooldown > 0) dodgeCooldown -= dt;
    if (landingAnimationTimer > 0) landingAnimationTimer -= dt;
    if (jumpAnimationTimer > 0) jumpAnimationTimer -= dt;

    // Combo timer
    if (comboTimer > 0) {
      comboTimer -= dt;
      if (comboTimer <= 0) {
        if (comboCount > 1) {
          _eventBus.emit(CharacterComboBrokenEvent(
            characterId: stats.name,
            position: position.clone(),
            maxComboReached: comboCount,
            reason: 'timeout',
          ));
        }
        comboCount = 0;
      }
    }

    // Attack animation timer
    if (attackAnimationTimer > 0) {
      attackAnimationTimer -= dt;
      if (attackAnimationTimer <= 0) {
        isAttacking = false;
        _eventBus.emit(CharacterAttackCompletedEvent(
          characterId: stats.name,
          position: position.clone(),
          attackType: stats.attackRange > 5 ? 'ranged' : 'melee',
          targetsHit: 0,
          totalDamage: 0,
        ));
      }
    }

    // Attack commit timer
    if (attackCommitTime > 0) {
      attackCommitTime -= dt;
      if (attackCommitTime <= 0) {
        isAttackCommitted = false;
      }
    }
  }

  /// Handle state-specific updates
  void _handleStates(double dt) {
    // Stamina regeneration
    if (stamina < maxStamina && !isBlocking && !isDodging && !isAttacking) {
      final oldStamina = stamina;
      stamina = math.min(maxStamina, stamina + 15 * dt);

      if (stamina - oldStamina > 5) {
        _eventBus.emit(CharacterStaminaRegenEvent(
          characterId: stats.name,
          position: position.clone(),
          amount: stamina - oldStamina,
          currentStamina: stamina,
          maxStamina: maxStamina,
        ));
      }
    }

    // Block stamina drain
    if (isBlocking) {
      stamina -= 15 * dt;
      if (stamina <= 0) {
        stamina = 0;
        breakGuard();
      }
    }

    // Handle dodge roll
    if (isDodging) {
      dodgeDuration -= dt;
      if (dodgeDuration <= 0) {
        isDodging = false;
        velocity.x *= 0.3;
        _eventBus.emit(CharacterDodgeCompletedEvent(
          characterId: stats.name,
          position: position.clone(),
          avoidedDamage: false,
        ));
      } else {
        velocity.x = dodgeDirection.x * stats.dexterity * 15;
      }
    }

    // Handle stun
    if (isStunned) {
      stunDuration -= dt;
      velocity.x = 0;
      if (stunDuration <= 0) {
        recoverFromStun();
      }
      return; // Skip other states
    }

    // Handle landing recovery
    if (isLanding) {
      landingRecoveryTime -= dt;
      velocity.x *= 0.5;
      if (landingRecoveryTime <= 0) {
        isLanding = false;
      }
    }
  }

  @override
  void dodge(Vector2 direction) {
    if (dodgeCooldown > 0 || isDodging || stamina < 20) return;

    isDodging = true;
    dodgeDuration = 0.3;
    dodgeCooldown = 2.0;
    stamina -= 20;
    dodgeDirection = direction.normalized();

    _eventBus.emit(CharacterDodgeStartedEvent(
      characterId: stats.name,
      position: position.clone(),
      dodgeDirection: dodgeDirection,
      duration: 0.3,
      staminaCost: 20,
    ));
  }

  /// Start blocking with event emission
  @override
  void startBlock() {
    if (stamina < 10 || isDodging || isAttacking) return;
    if (isBlocking) return; // Already blocking

    isBlocking = true;
    _blockStartTime = DateTime.now();

    _eventBus.emit(CharacterBlockStartedEvent(
      characterId: stats.name,
      position: position.clone(),
      staminaPerSecond: 15.0,
    ));
  }

  @override
  void stopBlock() {
    if (!isBlocking) return;

    final duration = _blockStartTime != null
        ? DateTime.now().difference(_blockStartTime!).inMilliseconds / 1000.0
        : 0.0;

    isBlocking = false;

    String reason = 'manual';
    if (stamina <= 0) {
      reason = 'stamina_depleted';
    } else if (isStunned) {
      reason = 'interrupted';
    }

    _eventBus.emit(CharacterBlockStoppedEvent(
      characterId: stats.name,
      position: position.clone(),
      reason: reason,
      duration: duration,
    ));

    _blockStartTime = null;
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
    // Don't render if dead - component should be removed instead
    if (health <= 0) {
      return; // Don't render anything for dead characters
    }

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
    if (playerType == PlayerType.bot && health > 0) {
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

  // ==========================================
  // REFACTORED ACTION METHODS
  // ==========================================

  /// Jump with event emission
  void performJump({double? customPower, bool isDoubleJump = false}) {
    if (groundPlatform == null || stamina < 20) return;

    final jumpPower = customPower ?? -300.0;

    // Apply physics
    velocity.y = jumpPower;
    groundPlatform = null;
    stamina -= 20;
    isJumping = true;
    isAirborne = true;
    airborneTime = 0;

    // Emit jump event
    _eventBus.emit(CharacterJumpedEvent(
      characterId: stats.name,
      position: position.clone(),
      jumpPower: jumpPower.abs(),
      staminaCost: 20,
      isDoubleJump: isDoubleJump,
    ));
  }

  /// Walk with event emission
  void performWalk(Vector2 direction, double speed) {
    // Check if started walking
    if (velocity.x.abs() < 5 && direction.x.abs() > 0) {
      _eventBus.emit(CharacterWalkStartedEvent(
        characterId: stats.name,
        position: position.clone(),
        direction: direction,
        speed: speed,
      ));
    }

    // Apply movement
    velocity.x = direction.x * speed;
    facingRight = direction.x > 0;

    // Emit turn event if direction changed
    if ((direction.x > 0 && !facingRight) || (direction.x < 0 && facingRight)) {
      _eventBus.emit(CharacterTurnedEvent(
        characterId: stats.name,
        position: position.clone(),
        nowFacingRight: direction.x > 0,
      ));
    }
  }

  /// Stop walking with event emission
  void performStopWalk() {
    if (velocity.x.abs() > 5) {
      _eventBus.emit(CharacterWalkStoppedEvent(
        characterId: stats.name,
        position: position.clone(),
      ));
    }

    velocity.x *= 0.7;
  }

  bool prepareAttackWithEvent() {
    if (isLanding || isStunned || isDodging || attackCooldown > 0 || stamina < 15) {
      return false;
    }

    // Apply cooldown and stamina cost
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
    } else {
      comboCount = 1;
      comboTimer = comboWindow;

      // Emit combo started event
      _eventBus.emit(CharacterComboStartedEvent(
        characterId: stats.name,
        position: position.clone(),
      ));
    }

    // Attack momentum
    lastAttackDirection = facingRight ? 1 : -1;
    if (!isAirborne) {
      velocity.x += lastAttackDirection * 50;
    }

    // Determine attack type
    String attackType = 'melee';
    if (stats.attackRange > 5) {
      attackType = 'ranged';
    }

    // Emit attack started event
    _eventBus.emit(CharacterAttackStartedEvent(
      characterId: stats.name,
      position: position.clone(),
      attackType: attackType,
      comboCount: comboCount,
      staminaCost: isAirborne ? 20 : 15,
    ));

    return true;
  }

  void handleLandingWithEvent() {
    final fallSpeed = velocity.y;
    final isHard = fallSpeed > hardLandingThreshold;
    double damage = 0;

    if (isHard) {
      final stunTime = math.min(1.0, (fallSpeed - hardLandingThreshold) / 200);
      isStunned = true;
      stunDuration = stunTime;

      damage = (fallSpeed - hardLandingThreshold) / 50;
      takeDamage(damage);

      // Emit stun event
      _eventBus.emit(CharacterStunnedEvent(
        characterId: stats.name,
        position: position.clone(),
        duration: stunTime,
        source: 'hard_landing',
      ));
    } else if (fallSpeed > 200) {
      isLanding = true;
      landingRecoveryTime = 0.25;
    }

    velocity.y = 0;

    // Emit landed event
    _eventBus.emit(CharacterLandedEvent(
      characterId: stats.name,
      position: position.clone(),
      fallSpeed: fallSpeed,
      isHardLanding: isHard,
      damage: damage,
    ));
  }

  void recoverFromStun() {
    if (!isStunned) return;

    isStunned = false;
    stunDuration = 0;

    _eventBus.emit(CharacterStunRecoveredEvent(
      characterId: stats.name,
      position: position.clone(),
    ));
  }

  void breakGuard() {
    if (!isBlocking) return;

    stopBlock();
    isStunned = true;
    stunDuration = 0.5;

    _eventBus.emit(CharacterGuardBrokenEvent(
      characterId: stats.name,
      position: position.clone(),
      stunDuration: 0.5,
    ));
  }

}