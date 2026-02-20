import 'dart:math' as math;

import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

typedef Player = GameCharacter;
typedef Enemy = GameCharacter;

abstract class GameCharacter extends SpriteAnimationComponent with HasGameReference<ActionGame> {

  final String uniqueId;

  final GameCharacterState characterState = GameCharacterState();

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

  bool facingRight = true;

  // Animation
  SpriteAnimation? idleAnimation;
  SpriteAnimation? walkAnimation;
  SpriteAnimation? attackAnimation;
  SpriteAnimation? jumpAnimation;
  SpriteAnimation? landingAnimation;


  bool spritesLoaded = false;
  bool prevJumpInput = false;
  bool isDead = false;

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

  @override
  void update(double dt) {
    super.update(dt);

    // Skip all updates if dead
    if (characterState.health <= 0) {
      velocity = Vector2.zero();
      return;
    }

    // Update state machine timer
    _stateMachine.update(dt);

    // Sync live state to logical state
    characterState.wasGrounded = characterState.groundPlatform != null;
    characterState.velocity = velocity;
    characterState.groundPlatform = characterState.groundPlatform;
    // Update timers first
    _updateTimers(dt);

    // Handle state-specific updates (stamina, dodge, etc.)
    _handleStates(dt);

    // Update based on type (skip if stunned)
    if (!characterState.isStunned && characterState.health > 0) {
      // Landing allows limited control but not full actions
      if (characterState.isLanding && characterState.landingAnimationTimer > 0.1) {
        // Can only apply friction during landing
        velocity.x *= GameConfig.landingFriction;
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
    final isGroundedNow = characterState.groundPlatform != null;

    // Detect takeoff (was grounded, now airborne)
    if (characterState.wasGrounded && !isGroundedNow && velocity.y < GameConfig.maxLandingUpwardVelocity) {
      characterState.jumpAnimationTimer = 0.3;
      characterState.isAirborne = true;
      characterState.isJumping = true;
      characterState.airborneTime = 0;

      _eventBus.emit(CharacterAirborneEvent(
        characterId: stats.name,
        position: position.clone(),
        velocity: velocity.clone(),
      ));
    }

    // Detect landing (was airborne, now grounded)
    if (!characterState.wasGrounded && isGroundedNow && velocity.y > GameConfig.landingVelocityThreshold) {
      handleLandingWithEvent();
      characterState.landingAnimationTimer = 0.25;
      characterState.isLanding = true;
      characterState.isAirborne = false;
      characterState.isJumping = false;
      characterState.hasDoubleJumped = false; // ← RESET double jump on land
    }

    // Update airborne state
    if (isGroundedNow) {
      characterState.isAirborne = false;
      characterState.airborneTime = 0;
      characterState.isJumping = false;
    } else {
      characterState.isAirborne = true;
      characterState.airborneTime += dt;
    }

    // Update animation using state machine
    updateAnimationWithEvents();

    // Update size
    size.y = characterState.isCrouching ? baseHeight / 2 : baseHeight;

    // Emit idle event if truly idle
    if (isGroundedNow && velocity.x.abs() < GameConfig.stopThreshold && !characterState.isAttacking &&
        !characterState.isBlocking && !characterState.isDodging && !characterState.isJumping && !characterState.isAirborne) {
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
    final desiredState = _stateMachine.evaluateState(characterState);

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

  void applyPhysics(double dt) {
    // Apply gravity (only when not on ground and not climbing)
    if (characterState.groundPlatform == null && !characterState.isClimbing && !characterState.isDodging) {
      velocity.y += GameConfig.gravity * dt;
      velocity.y = math.min(velocity.y, GameConfig.maxFallSpeed);
    }

    // Ground friction
    if (characterState.groundPlatform != null && !characterState.isAttackCommitted && !characterState.isDodging) {
      final currentFriction = characterState.isLanding ? GameConfig.landingFriction : GameConfig.groundFriction;
      velocity.x *= currentFriction;
      if (velocity.x.abs() < GameConfig.stopThreshold) velocity.x = 0;
    }

    // Air resistance
    if (characterState.groundPlatform == null && !characterState.isDodging) {
      velocity.x *= GameConfig.airResistance;
    }

    // ── collision ─────────────────────────────────────────────────────────────
    // Use CURRENT position (not proposed) so we can snap from any starting
    // offset — including spawning slightly above the surface.
    //
    // FIX: OLD code used `proposedPosition` for charBottom which meant a
    // character spawned even 1px above platformTop produced distanceToPlatform < 0,
    // failing the `>= 0` guard and letting gravity accumulate every frame.
    //
    // NEW approach:
    //   1. Compute proposedPosition for horizontal movement.
    //   2. For vertical collision, look at where the character's bottom WILL be
    //      after this frame AND allow a small upward snap window (snapUp) so
    //      a character standing 1–4 px above the surface is still treated as
    //      grounded and pulled flush to the surface.
    final proposedPosition = position + velocity * dt;

    // How far above the surface we're still willing to "snap" downward onto it.
    // Large enough to absorb a missed frame but small enough not to pull the
    // character through a thin platform from above.
    const double snapUp = 4.0;

    GamePlatform? newGroundPlatform;

    for (final platform in game.platforms) {
      final platformLeft  = platform.position.x - platform.size.x / 2;
      final platformRight = platform.position.x + platform.size.x / 2;
      final platformTop   = platform.position.y - platform.size.y / 2;

      final charLeft   = proposedPosition.x - size.x / 2;
      final charRight  = proposedPosition.x + size.x / 2;
      final charBottom = proposedPosition.y + size.y / 2;

      if (charRight <= platformLeft || charLeft >= platformRight) continue;

      final distanceToPlatform = charBottom - platformTop;

      // Accept the collision when:
      //   • velocity is downward (or zero) — not while jumping upward
      //   • character bottom is within the detection window:
      //       -snapUp  ..  platformDetectionRange
      //     The negative side handles spawning / landing a few px above surface.
      if (velocity.y >= 0 &&
          distanceToPlatform > -snapUp &&
          distanceToPlatform < GameConfig.platformDetectionRange) {
        position.y      = platformTop - size.y / 2;  // snap flush to surface
        velocity.y      = 0;
        newGroundPlatform = platform;
        break;
      }
    }

    // Apply movement
    if (newGroundPlatform == null) {
      position.add(velocity * dt);
    } else {
      position.x += velocity.x * dt;
    }

    characterState.groundPlatform = newGroundPlatform;
  }

  void _updateTimers(double dt) {
    if (characterState.attackCooldown > 0) characterState.attackCooldown -= dt;
    if (characterState.dodgeCooldown > 0) characterState.dodgeCooldown -= dt;
    if (characterState.landingAnimationTimer > 0) characterState.landingAnimationTimer -= dt;
    if (characterState.jumpAnimationTimer > 0) characterState.jumpAnimationTimer -= dt;

    if (characterState.comboTimer > 0) {
      characterState.comboTimer -= dt;
      if (characterState.comboTimer <= 0) {
        if (characterState.comboCount > 1) {
          _eventBus.emit(CharacterComboBrokenEvent(
            characterId: stats.name,
            position: position.clone(),
            maxComboReached: characterState.comboCount,
            reason: 'timeout',
          ));
        }
        characterState.comboCount = 0;
      }
    }

    if (characterState.attackAnimationTimer > 0) {
      characterState.attackAnimationTimer -= dt;
      if (characterState.attackAnimationTimer <= 0) {
        characterState.isAttacking = false;
        _eventBus.emit(CharacterAttackCompletedEvent(
          characterId: stats.name,
          position: position.clone(),
          attackType: stats.attackRange > 5 ? 'ranged' : 'melee',
          targetsHit: 0,
          totalDamage: 0,
        ));
      }
    }

    if (characterState.attackCommitTime > 0) {
      characterState.attackCommitTime -= dt;
      if (characterState.attackCommitTime <= 0) {
        characterState.isAttackCommitted = false;
      }
    }
  }

  void _handleStates(double dt) {
    if (characterState.stamina < characterState.maxStamina && !characterState.isBlocking && !characterState.isDodging && !characterState.isAttacking) {
      final oldStamina = characterState.stamina;
      characterState.stamina = math.min(characterState.maxStamina, characterState.stamina + 15 * dt);

      if (characterState.stamina - oldStamina > 5) {
        _eventBus.emit(CharacterStaminaRegenEvent(
          characterId: stats.name,
          position: position.clone(),
          amount: characterState.stamina - oldStamina,
          currentStamina: characterState.stamina,
          maxStamina: characterState.maxStamina,
        ));
      }
    }

    if (characterState.isBlocking) {
      characterState.stamina -= 15 * dt;
      if (characterState.stamina <= 0) {
        characterState.stamina = 0;
        breakGuard();
      }
    }

    if (characterState.isDodging) {
      characterState.dodgeDuration -= dt;
      if (characterState.dodgeDuration <= 0) {
        characterState.isDodging = false;
        velocity.x *= 0.3;
        _eventBus.emit(CharacterDodgeCompletedEvent(
          characterId: stats.name,
          position: position.clone(),
          avoidedDamage: false,
        ));
      } else {
        velocity.x = characterState.dodgeDirection.x * stats.dexterity * 15;
      }
    }

    if (characterState.isStunned) {
      characterState.stunDuration -= dt;
      velocity.x = 0;
      if (characterState.stunDuration <= 0) {
        recoverFromStun();
      }
      return;
    }

    if (characterState.isLanding) {
      characterState.landingRecoveryTime -= dt;
      velocity.x *= 0.5;
      if (characterState.landingRecoveryTime <= 0) {
        characterState.isLanding = false;
      }
    }
  }

  void dodge(Vector2 direction) {
    if (characterState.dodgeCooldown > 0 || characterState.isDodging || characterState.stamina < GameConfig.dodgeStaminaCost) return;

    characterState.isDodging = true;
    characterState.dodgeDuration = GameConfig.dodgeDuration;
    characterState.dodgeCooldown = GameConfig.dodgeCooldown;
    characterState.stamina -= GameConfig.dodgeStaminaCost;
    characterState.dodgeDirection = direction.normalized();

    _eventBus.emit(CharacterDodgeStartedEvent(
      characterId: stats.name,
      position: position.clone(),
      dodgeDirection: characterState.dodgeDirection,
      duration: 0.3,
      staminaCost: 20,
    ));
  }

  void startBlock() {
    if (characterState.stamina < 10 || characterState.isDodging || characterState.isAttacking) return;
    if (characterState.isBlocking) return;

    characterState.isBlocking = true;
    _blockStartTime = DateTime.now();

    _eventBus.emit(CharacterBlockStartedEvent(
      characterId: stats.name,
      position: position.clone(),
      staminaPerSecond: 15.0,
    ));
  }

  void stopBlock() {
    if (!characterState.isBlocking) return;

    final duration = _blockStartTime != null
        ? DateTime.now().difference(_blockStartTime!).inMilliseconds / 1000.0
        : 0.0;

    characterState.isBlocking = false;

    String reason = 'manual';
    if (characterState.stamina <= 0) {
      reason = 'stamina_depleted';
    } else if (characterState.isStunned) {
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

  bool prepareAttackWithEvent() {
    if (characterState.isLanding || characterState.isStunned || characterState.isDodging || characterState.attackCooldown > 0 || characterState.stamina < 15) {
      return false;
    }

    if (characterState.isAirborne) {
      characterState.attackCooldown = 1.0;
      characterState.stamina -= 20;
    } else {
      characterState.attackCooldown = 0.5;
      characterState.stamina -= 15;
    }

    characterState.isAttacking = true;
    characterState.isAttackCommitted = true;
    characterState.attackCommitTime = GameConfig.attackCommitTime;
    characterState.attackAnimationTimer = GameConfig.attackAnimationDuration;

    if (characterState.comboTimer > 0) {
      characterState.comboCount++;
      characterState.comboTimer = characterState.comboWindow;
    } else {
      characterState.comboCount = 1;
      characterState.comboTimer = characterState.comboWindow;

      _eventBus.emit(CharacterComboStartedEvent(
        characterId: stats.name,
        position: position.clone(),
      ));
    }

    characterState.lastAttackDirection = facingRight ? 1 : -1;
    if (!characterState.isAirborne) {
      velocity.x += characterState.lastAttackDirection * 50;
    }

    String attackType = 'melee';
    if (stats.attackRange > 5) {
      attackType = 'ranged';
    }

    _eventBus.emit(CharacterAttackStartedEvent(
      characterId: stats.name,
      position: position.clone(),
      attackType: attackType,
      comboCount: characterState.comboCount,
      staminaCost: characterState.isAirborne ? 20 : 15,
    ));

    return true;
  }

  void handleLandingWithEvent() {
    final fallSpeed = velocity.y;
    final isHard = fallSpeed > characterState.hardLandingThreshold;
    double damage = 0;

    if (isHard) {
      final stunTime = math.min(1.0, (fallSpeed - characterState.hardLandingThreshold) / 200);
      characterState.isStunned = true;
      characterState.stunDuration = stunTime;

      damage = (fallSpeed - characterState.hardLandingThreshold) / 50;
      takeDamage(damage);

      _eventBus.emit(CharacterStunnedEvent(
        characterId: stats.name,
        position: position.clone(),
        duration: stunTime,
        source: 'hard_landing',
      ));
    } else if (fallSpeed > 200) {
      characterState.isLanding = true;
      characterState.landingRecoveryTime = GameConfig.landingRecoveryTime;
    }

    velocity.y = 0;

    _eventBus.emit(CharacterLandedEvent(
      characterId: stats.name,
      position: position.clone(),
      fallSpeed: fallSpeed,
      isHardLanding: isHard,
      damage: damage,
    ));
  }

  void recoverFromStun() {
    if (!characterState.isStunned) return;

    characterState.isStunned = false;
    characterState.stunDuration = 0;

    _eventBus.emit(CharacterStunRecoveredEvent(
      characterId: stats.name,
      position: position.clone(),
    ));
  }

  void breakGuard() {
    if (!characterState.isBlocking) return;

    stopBlock();
    characterState.isStunned = true;
    characterState.stunDuration = 0.5;

    _eventBus.emit(CharacterGuardBrokenEvent(
      characterId: stats.name,
      position: position.clone(),
      stunDuration: 0.5,
    ));
  }

  /// Base jump power — subclasses override via [jumpPower] getter.
  double get jumpPower => GameConfig.jumpVelocity;

  /// 85 % of first jump for the double-jump burst.
  double get doubleJumpPower => jumpPower * 0.85;

  /// Call from subclass updateHumanControl / bot AI.
  /// Pass the RAW (non-edge-detected) bool from input this frame.
  /// Edge detection is handled here so subclasses stay simple.
  void handleJumpInput(bool jumpPressed) {
    final justPressed = jumpPressed && !prevJumpInput;
    prevJumpInput = jumpPressed;
    if (!justPressed) return;
    performJump();
  }

  void performJump({double? customPower, bool isDoubleJump = false}) {
    final isGrounded = characterState.groundPlatform != null;
    final stamina = characterState.stamina;

    // Ground jump
    if (isGrounded && stamina >= GameConfig.jumpStaminaCost) {
      final power = customPower ?? jumpPower;
      velocity.y = power;
      characterState.groundPlatform = null;
      characterState.stamina -= GameConfig.jumpStaminaCost;
      characterState.isJumping = true;
      characterState.isAirborne = true;
      characterState.airborneTime = 0;
      characterState.hasDoubleJumped = false;

      _eventBus.emit(CharacterJumpedEvent(
        characterId: stats.name,
        position: position.clone(),
        jumpPower: power.abs(),
        staminaCost: GameConfig.jumpStaminaCost.toDouble(),
        isDoubleJump: false,
      ));
      return;
    }

    // Double jump — airborne, hasn't used it yet, has stamina
    if (!isGrounded &&
        characterState.isAirborne &&
        characterState.canDoubleJump &&
        !characterState.hasDoubleJumped &&
        stamina >= GameConfig.jumpStaminaCost) {
      final power = customPower != null ? customPower * 0.85 : doubleJumpPower;
      velocity.y = power;
      characterState.stamina -= GameConfig.jumpStaminaCost;
      characterState.hasDoubleJumped = true;
      characterState.jumpAnimationTimer = 0.3;

      _eventBus.emit(CharacterJumpedEvent(
        characterId: stats.name,
        position: position.clone(),
        jumpPower: power.abs(),
        staminaCost: GameConfig.jumpStaminaCost.toDouble(),
        isDoubleJump: true,
      ));
    }
  }

  void performWalk(Vector2 direction, double speed) {
    if (velocity.x.abs() < GameConfig.stopThreshold && direction.x.abs() > 0) {
      _eventBus.emit(CharacterWalkStartedEvent(
        characterId: stats.name,
        position: position.clone(),
        direction: direction,
        speed: speed,
      ));
    }

    velocity.x = direction.x * speed;
    facingRight = direction.x > 0;

    if ((direction.x > 0 && !facingRight) || (direction.x < 0 && facingRight)) {
      _eventBus.emit(CharacterTurnedEvent(
        characterId: stats.name,
        position: position.clone(),
        nowFacingRight: direction.x > 0,
      ));
    }
  }

  void performStopWalk() {
    if (velocity.x.abs() > 5) {
      _eventBus.emit(CharacterWalkStoppedEvent(
        characterId: stats.name,
        position: position.clone(),
      ));
    }

    velocity.x *= 0.7;
  }

  void takeDamage(double damage) {
    if (characterState.isDodging) {
      return;
    }

    if (characterState.isBlocking && characterState.stamina > 0) {
      final blockedDamage = damage * 0.3;
      damage = blockedDamage;
      characterState.stamina -= GameConfig.blockStaminaDrain;

      if (characterState.stamina < 0) {
        characterState.stamina = 0;
        characterState.isBlocking = false;
      }
    }

    characterState.health = math.max(0, characterState.health - damage);
    characterState.lastDamageTaken = damage;

    if (!characterState.isAttackCommitted) {
      characterState.isAttacking = false;
      characterState.attackAnimationTimer = 0;
    }

    if (damage > 10 && !characterState.isBlocking) {
      velocity.x = -characterState.lastAttackDirection * 100;
      characterState.comboCount = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    // Immediately skip all rendering when dead — world.remove() may lag one frame
    if (isDead) return;

    // Player death: ghost + skull (player is not removed, game-over handled separately)
    if (isPlayer && characterState.health <= 0) {
      canvas.saveLayer(
        Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
        Paint()..color = Colors.white.withOpacity(0.3),
      );
      super.render(canvas);
      canvas.restore();

      final textPainter = TextPainter(
        text: const TextSpan(
          text: '💀',
          style: TextStyle(fontSize: 40),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -size.y / 2 - 50));
      return;
    }

    // Bot with health <= 0: render nothing (isDead will be true by next frame,
    // but guard here too so skull never flashes)
    if (isBot && characterState.health <= 0) return;

    super.render(canvas);

    if (!spritesLoaded) {
      final paint = Paint()..color = stats.color;
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
        paint,
      );
    }

    if (characterState.isStunned) _renderStunEffect(canvas);
    if (characterState.isDodging) _renderDodgeEffect(canvas);
    if (characterState.isBlocking) _renderBlockEffect(canvas);

    if (isBot && characterState.health > 0) {
      final healthBarWidth = size.x;
      final healthPercent = (characterState.health / 100).clamp(0.0, 1.0);
      canvas.drawRect(
        Rect.fromLTWH(-size.x / 2, -size.y / 2 - 20, healthBarWidth, 10),
        Paint()..color = Colors.red,
      );
      canvas.drawRect(
        Rect.fromLTWH(-size.x / 2, -size.y / 2 - 20, healthBarWidth * healthPercent, 10),
        Paint()..color = Colors.green,
      );
    }

    if (isPlayer) {
      final staminaPercent =
      (characterState.stamina / characterState.maxStamina).clamp(0.0, 1.0);
      canvas.drawRect(
        Rect.fromLTWH(-size.x / 2, size.y / 2 + 5, size.x, 5),
        Paint()..color = Colors.grey.withOpacity(0.5),
      );
      canvas.drawRect(
        Rect.fromLTWH(-size.x / 2, size.y / 2 + 5, size.x * staminaPercent, 5),
        Paint()..color = Colors.yellow,
      );
    }

    if (characterState.comboCount > 1) _renderComboIndicator(canvas);
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
    final opacity = (characterState.dodgeDuration / 0.3) * 0.5;
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
        text: 'x$characterState.comboCount',
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
