import 'dart:math' as math;

import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:gamepad/gamepad.dart';

typedef Player = GameCharacter;
typedef Enemy = GameCharacter;

abstract class GameCharacter extends SpriteAnimationComponent with HasGameReference<ActionGame> {

  final String uniqueId;

  final GameCharacterState characterState = GameCharacterState();

  final CharacterStats stats;
  final PlayerType playerType;
  BotTactic? botTactic;

  ActionStrategy get actionStrategy;
  double get jumpPower => actionStrategy.jumpPower;
  double get doubleJumpPower => actionStrategy.jumpPower * actionStrategy.doubleJumpMultiplier;


  MovementStrategy get movementStrategy;

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
  SpriteAnimation? runAnimation;
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

  bool get isPlayer => playerType == PlayerType.human;
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
        final idlePaths = AssetPaths.characterSprites[characterName]?['idle'];
        if (idlePaths is List<dynamic> && idlePaths.isNotEmpty) {
          final frames = <Sprite>[];
          for (final path in idlePaths) {
            final image = await game.images.load(path as String);
            frames.add(Sprite(image));
          }
          idleAnimation = SpriteAnimation.spriteList(frames, stepTime: 0.2);
          print('  ✅ Loaded idle frames (${frames.length})');
        } else {
          // Fallback: single image file
          final idleImage = await game.images.load('${characterName}_idle.png');
          if (idleImage.width > idleImage.height * 1.5) {
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
            idleAnimation = SpriteAnimation.spriteList([Sprite(idleImage)], stepTime: 0.5);
            print('  ✅ Loaded idle sprite');
          }
        }
      } catch (e) {
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
        final walkFrames = await _loadFrameSequence(characterName, 'walk');
        walkAnimation = SpriteAnimation.spriteList(walkFrames, stepTime: 0.1);
        print('  ✅ Loaded walk frames (${walkFrames.length})');
      } catch (e) {
        walkAnimation = idleAnimation;
        print('  ⚠️ Walk frames not found, using idle');
      }

      // === RUN ANIMATION ===
      try {
        final runFrames = await _loadFrameSequence(characterName, 'run');
        runAnimation = SpriteAnimation.spriteList(runFrames, stepTime: 0.07);
        print('  ✅ Loaded run frames (${runFrames.length})');
      } catch (e) {
        runAnimation = walkAnimation;
        print('  ⚠️ Run frames not found, using walk');
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
              loop: false,
            ),
          );
          print('  ✅ Loaded attack sprite sheet ($frameCount frames)');
        } else {
          attackAnimation = SpriteAnimation.spriteList([Sprite(attackImage)], stepTime: 0.1);
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
          jumpAnimation = SpriteAnimation.spriteList([Sprite(jumpImage)], stepTime: 0.1);
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
          landingAnimation = SpriteAnimation.spriteList([Sprite(landingImage)], stepTime: 0.1);
          print('  ✅ Loaded landing sprite');
        }
      } catch (e) {
        landingAnimation = idleAnimation;
        print('  ⚠️ Landing sprite not found, using idle');
      }

      animation = idleAnimation;
      spritesLoaded = true;
      print('✅ All sprites loaded for $characterName');
    } catch (e) {
      print('❌ Fatal error loading sprites for $characterName: $e');
      spritesLoaded = false;
    }
  }

  void handleMovementInput(Vector2 inputDelta) {
    if (inputDelta.x == 0 || characterState.isBlocking) {
      if (!characterState.isAttackCommitted && !characterState.isBlocking) {
        performStopWalk();
      }
      return;
    }

    final direction = Vector2(inputDelta.x, 0);
    final baseSpeed = stats.dexterity / 2;
    final speed = movementStrategy.resolveSpeed(
      baseSpeed: baseSpeed,
      inputMagnitude: inputDelta.x.abs(),
      isAttackCommitted: characterState.isAttackCommitted,
    );

    if (movementStrategy.isRunning(inputDelta.x.abs()) && !characterState.isAttackCommitted) {
      performRun(direction, speed);
    } else {
      performWalk(direction, speed);
    }
  }

  void handleBlockInput(GamepadManager gamepad) {
    if (gamepad.isBlockPressed && characterState.groundPlatform != null) {
      startBlock();
      velocity.x = 0;
    } else {
      stopBlock();
    }
  }

  void handleJumpFromInput(GamepadManager gamepad) {
    final jumpPressed = game.joystick.direction == JoystickDirection.up ||
        gamepad.isJumpPressed;
    if (!characterState.isBlocking && !characterState.isAttackCommitted) {
      handleJumpInput(jumpPressed);
    } else {
      prevJumpInput = jumpPressed;
    }
  }

  void handleDodgeInput(GamepadManager gamepad, Vector2 inputDelta) {
    final stickDodge = inputDelta.length > actionStrategy.dodgeStickThreshold &&
        (inputDelta.y * actionStrategy.dodgeStickYSign) > actionStrategy.dodgeStickThreshold;
    final buttonDodge = actionStrategy.dodgeEdgeDetect
        ? gamepad.isDodgeJustPressed()
        : gamepad.isDodgePressed;

    if ((stickDodge || buttonDodge) &&
        characterState.groundPlatform != null &&
        !characterState.isBlocking &&
        characterState.dodgeCooldown <= 0) {
      final dir = inputDelta.x != 0
          ? Vector2(inputDelta.x, 0)
          : Vector2(facingRight ? 1 : -1, 0);
      dodge(dir);
    }
  }

  void updateHumanControl(double dt) {
    if (characterState.isStunned || characterState.isLanding || characterState.isDodging) return;

    final gamepad = game.gamepadManager;
    Vector2 inputDelta = game.joystick.relativeDelta;
    if (gamepad.isGamepadConnected && gamepad.hasMovementInput()) {
      inputDelta = gamepad.getJoystickDirection();
    }

    handleMovementInput(inputDelta);
    handleBlockInput(gamepad);
    handleJumpFromInput(gamepad);
    handleDodgeInput(gamepad, inputDelta);
  }

  Future<List<Sprite>> _loadFrameSequence(String characterName, String animType) async {
    final entry = AssetPaths.characterSprites[characterName]?[animType];

    if (entry is List<dynamic>) {
      final sprites = <Sprite>[];
      for (final path in entry) {
        final image = await game.images.load(path as String);
        sprites.add(Sprite(image));
      }
      if (sprites.isEmpty) throw Exception('No frames loaded for $characterName/$animType');
      return sprites;
    }

    // Fallback: numbered files knight_walk_1..6
    final sprites = <Sprite>[];
    for (int i = 1; i <= 6; i++) {
      try {
        final image = await game.images.load('${characterName}_${animType}_$i.png');
        sprites.add(Sprite(image));
      } catch (_) {
        break;
      }
    }
    if (sprites.isEmpty) throw Exception('No frames found for $characterName/$animType');
    return sprites;
  }


  @override
  void update(double dt) {
    super.update(dt);

    if (characterState.health <= 0) {
      velocity = Vector2.zero();
      return;
    }

    _stateMachine.update(dt);

    characterState.wasGrounded = characterState.groundPlatform != null;
    characterState.velocity = velocity;
    characterState.groundPlatform = characterState.groundPlatform;

    _updateTimers(dt);
    _handleStates(dt);

    if (!characterState.isStunned && characterState.health > 0) {
      if (characterState.isLanding && characterState.landingAnimationTimer > 0.1) {
        velocity.x *= GameConfig.landingFriction;
      } else {
        if (playerType == PlayerType.human) {
          updateHumanControl(dt);
        } else {
          updateBotControl(dt);
        }
      }
    }

    applyPhysics(dt);

    final isGroundedNow = characterState.groundPlatform != null;

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

    if (!characterState.wasGrounded && isGroundedNow && velocity.y > GameConfig.landingVelocityThreshold) {
      handleLandingWithEvent();
      characterState.landingAnimationTimer = 0.25;
      characterState.isLanding = true;
      characterState.isAirborne = false;
      characterState.isJumping = false;
      characterState.hasDoubleJumped = false;
    }

    if (isGroundedNow) {
      characterState.isAirborne = false;
      characterState.airborneTime = 0;
      characterState.isJumping = false;
    } else {
      characterState.isAirborne = true;
      characterState.airborneTime += dt;
    }

    updateAnimationWithEvents();

    size.y = characterState.isCrouching ? baseHeight / 2 : baseHeight;

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

  void updateAnimationWithEvents() {
    if (!spritesLoaded) return;

    final desiredState = _stateMachine.evaluateState(characterState);
    final transitionSucceeded = _stateMachine.requestStateChange(desiredState);
    final currentStateEnum = _stateMachine.currentState;

    SpriteAnimation? newAnimation;

    switch (currentStateEnum) {
      case CharacterAnimState.idle:
        newAnimation = idleAnimation;
        break;
      case CharacterAnimState.walking:
        newAnimation = walkAnimation;
        break;
      case CharacterAnimState.running:
        newAnimation = runAnimation ?? walkAnimation;
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
        newAnimation = idleAnimation;
        break;
      case CharacterAnimState.dead:
        newAnimation = null;
        break;
    }

    if (transitionSucceeded) {
      final stateString = currentStateEnum.toString().split('.').last;

      _eventBus.emit(CharacterAnimationChangedEvent(
        characterId: stats.name,
        position: position.clone(),
        previousAnimation: _currentAnimationState,
        newAnimation: stateString,
        isLooping: currentStateEnum == CharacterAnimState.idle ||
            currentStateEnum == CharacterAnimState.walking ||
            currentStateEnum == CharacterAnimState.running,
      ));

      _currentAnimationState = stateString;
    }

    if (newAnimation != null && animation != newAnimation) {
      animation = newAnimation;
    }

    scale.x = facingRight ? 1 : -1;
  }

  void performRun(Vector2 direction, double speed) {
    final wasRight = facingRight;
    facingRight = direction.x > 0;

    if (facingRight != wasRight) {
      _eventBus.emit(CharacterTurnedEvent(
        characterId: stats.name,
        position: position.clone(),
        nowFacingRight: facingRight,
      ));
    }

    velocity.x = direction.x * speed;

    _eventBus.emit(CharacterRunStartedEvent(
      characterId: stats.name,
      position: position.clone(),
      direction: direction,
      speed: speed,
    ));
  }

  void applyPhysics(double dt) {
    if (characterState.groundPlatform == null && !characterState.isClimbing && !characterState.isDodging) {
      velocity.y += GameConfig.gravity * dt;
      velocity.y = math.min(velocity.y, GameConfig.maxFallSpeed);
    }

    if (characterState.groundPlatform != null && !characterState.isAttackCommitted && !characterState.isDodging) {
      final currentFriction = characterState.isLanding ? GameConfig.landingFriction : GameConfig.groundFriction;
      velocity.x *= currentFriction;
      if (velocity.x.abs() < GameConfig.stopThreshold) velocity.x = 0;
    }

    if (characterState.groundPlatform == null && !characterState.isDodging) {
      velocity.x *= GameConfig.airResistance;
    }

    final proposedPosition = position + velocity * dt;
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

      if (velocity.y >= 0 &&
          distanceToPlatform > -snapUp &&
          distanceToPlatform < GameConfig.platformDetectionRange) {
        position.y      = platformTop - size.y / 2;
        velocity.y      = 0;
        newGroundPlatform = platform;
        break;
      }
    }

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

    _eventBus.emit(CharacterAttackStartedEvent(
      characterId: stats.name,
      position: position.clone(),
      attackType: stats.attackRange > 5 ? 'ranged' : 'melee',
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

  /// Pass the RAW (non-edge-detected) bool from input this frame.
  void handleJumpInput(bool jumpPressed) {
    final justPressed = jumpPressed && !prevJumpInput;
    prevJumpInput = jumpPressed;
    if (!justPressed) return;
    performJump();
  }

  void performJump({double? customPower, bool isDoubleJump = false}) {
    final isGrounded = characterState.groundPlatform != null;
    final stamina = characterState.stamina;

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
    final wasRight = facingRight;
    facingRight = direction.x > 0;

    if (velocity.x.abs() < GameConfig.stopThreshold && direction.x.abs() > 0) {
      _eventBus.emit(CharacterWalkStartedEvent(
        characterId: stats.name,
        position: position.clone(),
        direction: direction,
        speed: speed,
      ));
    }

    if (facingRight != wasRight) {
      _eventBus.emit(CharacterTurnedEvent(
        characterId: stats.name,
        position: position.clone(),
        nowFacingRight: facingRight,
      ));
    }

    velocity.x = direction.x * speed;
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
    if (characterState.isDodging) return;

    if (characterState.isBlocking && characterState.stamina > 0) {
      damage *= 0.3;
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

  // ── Rendering ────────────────────────────────────────────────────────────────
  //
  // Flame local-canvas coordinate system with Anchor.center:
  //   (0, 0)              → top-left of component
  //   (size.x/2, size.y/2)→ center (world position)
  //   (size.x, size.y)    → bottom-right

  @override
  void render(Canvas canvas) {
    if (isDead) return;

    // Player death: ghost + skull
    if (isPlayer && characterState.health <= 0) {
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = Colors.white.withOpacity(0.3),
      );
      _renderSprite(canvas);
      canvas.restore();

      final textPainter = TextPainter(
        text: const TextSpan(text: '💀', style: TextStyle(fontSize: 40)),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(size.x / 2 - textPainter.width / 2, -50));
      return;
    }

    if (isBot && characterState.health <= 0) return;

    _renderSprite(canvas);

    if (characterState.isStunned) _renderStunEffect(canvas);
    if (characterState.isDodging) _renderDodgeEffect(canvas);
    if (characterState.isBlocking) _renderBlockEffect(canvas);

    if (isBot && characterState.health > 0) {
      final healthPercent = (characterState.health / 100).clamp(0.0, 1.0);
      canvas.drawRect(
        Rect.fromLTWH(0, -20, size.x, 10),
        Paint()..color = Colors.red,
      );
      canvas.drawRect(
        Rect.fromLTWH(0, -20, size.x * healthPercent, 10),
        Paint()..color = Colors.green,
      );
    }

    if (isPlayer) {
      final staminaPercent =
      (characterState.stamina / characterState.maxStamina).clamp(0.0, 1.0);
      canvas.drawRect(
        Rect.fromLTWH(0, size.y + 5, size.x, 5),
        Paint()..color = Colors.grey.withOpacity(0.5),
      );
      canvas.drawRect(
        Rect.fromLTWH(0, size.y + 5, size.x * staminaPercent, 5),
        Paint()..color = Colors.yellow,
      );
    }

    if (characterState.comboCount > 1) _renderComboIndicator(canvas);
  }

  void _renderSprite(Canvas canvas) {
    final sprite = animationTicker?.getSprite();
    if (sprite != null) {
      sprite.render(canvas, size: size);
    } else {
      // Visible fallback — always shown until sprites are ready
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = stats.color.withOpacity(0.7),
      );
    }
  }

  void _renderStunEffect(Canvas canvas) {
    const starCount = 3;
    const radius = 30.0;
    final cx = size.x / 2;
    final rotation = (DateTime.now().millisecondsSinceEpoch / 200) % (math.pi * 2);
    final paint = Paint()..color = Colors.yellow;

    for (int i = 0; i < starCount; i++) {
      final angle = rotation + (i * math.pi * 2 / starCount);
      canvas.drawCircle(
        Offset(cx + math.cos(angle) * radius, -20 + math.sin(angle) * 12),
        5,
        paint,
      );
    }
  }

  void _renderDodgeEffect(Canvas canvas) {
    final opacity = (characterState.dodgeDuration / 0.3).clamp(0.0, 1.0) * 0.5;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = stats.color.withOpacity(opacity),
    );
  }

  void _renderBlockEffect(Canvas canvas) {
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x / 2 + 10,
      Paint()
        ..color = Colors.blue.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  void _renderComboIndicator(Canvas canvas) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'x${characterState.comboCount}',
        style: const TextStyle(
          color: Colors.orange,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(size.x / 2 - textPainter.width / 2, -40));
  }
}