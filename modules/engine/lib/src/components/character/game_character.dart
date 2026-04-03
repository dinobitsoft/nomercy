import 'dart:math' as math;

import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:gamepad/gamepad.dart';

import '../../utils/sprite_utils.dart';

typedef Player = GameCharacter;
typedef Enemy  = GameCharacter;

abstract class GameCharacter extends SpriteAnimationComponent
    with HasGameReference<ActionGame> {

  final String uniqueId;
  final GameCharacterState characterState = GameCharacterState();
  final CharacterStats stats;
  final PlayerType playerType;
  BotTactic? botTactic;

  ActionStrategy  get actionStrategy;
  MovementStrategy get movementStrategy;

  double get jumpPower       => actionStrategy.jumpPower;
  double get doubleJumpPower => actionStrategy.jumpPower * actionStrategy.doubleJumpMultiplier;

  // ── Equipped weapon ───────────────────────────────────────────────────────
  Weapon? _equippedWeapon;
  Weapon? get equippedWeapon => _equippedWeapon;

  /// Total attack animation duration, weapon wins over class default.
  double get effectiveAttackDuration =>
      _equippedWeapon?.attackDurationOverride ?? actionStrategy.attackDuration;

  /// Movement speed multiplier from current weapon (1.0 if none).
  double get effectiveMoveSpeedMod => _equippedWeapon?.moveSpeedMod ?? 1.0;

  // ─────────────────────────────────────────────────────────────────────────
  final EventBus _eventBus = EventBus();

  String _currentAnimationState = 'idle';
  late final CharacterStateMachine _stateMachine = CharacterStateMachine();
  DateTime? _blockStartTime;

  static const double baseWidth  = GameConfig.characterWidth;
  static const double baseHeight = GameConfig.characterHeight;

  Vector2 velocity = Vector2.zero();
  bool facingRight = true;

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
  }) : uniqueId = customId ?? _generateUniqueId(),
        super(position: position) {
    size   = Vector2(baseWidth, baseHeight);
    anchor = Anchor.center;
  }

  static String _generateUniqueId() =>
      'char_${DateTime.now().millisecondsSinceEpoch}_${_idCounter++}';
  static int _idCounter = 0;

  bool get isPlayer => playerType == PlayerType.human;
  bool get isBot    => playerType == PlayerType.bot;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _loadSprites();
  }

  Future<void> _loadSprites() async {
    final name = stats.name.toLowerCase();
    final ms   = movementStrategy;
    final as_  = actionStrategy;
    try {
      idleAnimation    = await loadAnim(game, name, 'idle',    stepTime: ms.idleStepTime, loop: true);
      walkAnimation    = await loadAnim(game, name, 'walk',    stepTime: ms.walkStepTime, loop: true,  fallback: idleAnimation);
      runAnimation     = await loadAnim(game, name, 'run',     stepTime: ms.runStepTime,  loop: true,  fallback: walkAnimation);
      attackAnimation  = await _buildAttackAnim(name, effectiveAttackDuration);
      jumpAnimation    = await loadAnim(game, name, 'jump',    stepTime: as_.jumpStepTime,    loop: true,  fallback: idleAnimation);
      landingAnimation = await loadAnim(game, name, 'landing', stepTime: as_.landingStepTime, loop: false, fallback: idleAnimation);
      animation     = idleAnimation;
      spritesLoaded = true;
      print('✅ Sprites: $name');
    } catch (e) {
      print('❌ Sprites failed: $name — $e');
    }
  }

  Future<SpriteAnimation?> _buildAttackAnim(String charName, double duration) =>
      loadAnimDynamic(game, charName, 'attack',
          totalDuration: duration, loop: false, fallback: idleAnimation);

  // ── Weapon equip / unequip ────────────────────────────────────────────────

  Future<void> equipWeapon(Weapon? weapon) async {
    // Remove old bonuses
    if (_equippedWeapon != null) {
      final old = _equippedWeapon!;
      stats
        ..power        -= old.powerBonus
        ..magic        -= old.magicBonus
        ..dexterity    -= old.dexterityBonus
        ..intelligence -= old.intelligenceBonus
        ..attackDamage -= old.damage;
    }

    _equippedWeapon = weapon;

    if (weapon != null) {
      stats
        ..power        += weapon.powerBonus
        ..magic        += weapon.magicBonus
        ..dexterity    += weapon.dexterityBonus
        ..intelligence += weapon.intelligenceBonus
        ..attackDamage += weapon.damage
        ..attackRange   = weapon.range
        ..weaponName    = weapon.name;

      if (spritesLoaded) {
        attackAnimation = await _buildAttackAnim(
            stats.name.toLowerCase(),
            weapon.attackDurationOverride ?? actionStrategy.attackDuration);
      }

      _eventBus.emit(WeaponEquippedEvent(
        characterId: stats.name,
        weaponId:    weapon.id,
        weaponName:  weapon.name,
        newDamage:   stats.attackDamage,
        newRange:    stats.attackRange,
      ));

      print('🗡  ${stats.name} → ${weapon.name} '
          '(dur:${effectiveAttackDuration.toStringAsFixed(2)}s '
          'spd:${weapon.moveSpeedMod})');
    } else {
      // Revert to class defaults
      stats
        ..attackRange = actionStrategy.defaultAttackRange
        ..weaponName  = actionStrategy.defaultWeaponName;
      if (spritesLoaded) {
        attackAnimation =
        await _buildAttackAnim(stats.name.toLowerCase(), actionStrategy.attackDuration);
      }
    }
  }

  // ── Generic weapon attack (any character + any weapon) ────────────────────

  /// Call this instead of attack() when a weapon is equipped.
  /// Dispatches on WeaponType — knight with a bow fires arrows, etc.
  void performWeaponAttack() {
    if (_equippedWeapon == null) { attack(); return; }
    if (!prepareAttackWithEvent()) return;
    if (_equippedWeapon!.isRanged) {
      _fireProjectile(_equippedWeapon!);
    } else {
      _meleeSweep(_equippedWeapon!);
    }
  }

  void _fireProjectile(Weapon weapon) {
    final combo  = 1.0 + (characterState.comboCount - 1) * 0.18;
    final power  = characterState.comboCount >= 3;
    final count  = _projectileCount(weapon, power);
    final origin = position.clone() + (facingRight ? Vector2(40, 0) : Vector2(-40, 0));

    for (int i = 0; i < count; i++) {
      final spread = (i - (count - 1) / 2) * 0.15;
      final dir    = (facingRight ? Vector2(1, 0) : Vector2(-1, 0))..rotate(spread);
      final proj   = Projectile(
        position:    origin.clone(),
        direction:   dir,
        damage:      weapon.damage * combo * (power ? 1.5 : 1.0),
        owner:       isPlayer ? this : null,
        enemyOwner:  isBot    ? this : null,
        color:       power ? _powerColor(weapon) : weapon.projectileColor,
        type:        weapon.projectileType,
      );
      proj.priority = 75;
      game.world.add(proj);
      game.projectiles.add(proj);
    }

    if (!characterState.isAirborne) velocity.x -= facingRight ? 20 : -20;

    _eventBus.emit(ProjectileFiredEvent(
      shooterId:      stats.name,
      projectileType: weapon.projectileType,
      position:       position.clone(),
      direction:      facingRight ? Vector2(1, 0) : Vector2(-1, 0),
      damage:         weapon.damage * combo,
    ));
  }

  void _meleeSweep(Weapon weapon) {
    final targets = isPlayer ? game.enemies : [game.character];
    for (final target in targets) {
      final dist  = position.distanceTo(target.position);
      final range = weapon.range * 30 * (1 + characterState.comboCount * 0.1);
      if (dist >= range) continue;
      final dx = target.position.x - position.x;
      if (dist > 50 && !((facingRight && dx > 0) || (!facingRight && dx < 0))) continue;
      game.combatSystem.processAttack(attacker: this, target: target, attackType: 'melee');
      target.velocity.x += (facingRight ? 1 : -1) *
          (weapon.weaponType == WeaponType.axe ? 200 : 150);
      if (characterState.comboCount >= 3) target.velocity.y = -100;
    }
  }

  int _projectileCount(Weapon weapon, bool powerShot) {
    switch (weapon.weaponType) {
      case WeaponType.dagger:   return powerShot ? 5 : 3;
      case WeaponType.crossbow: return 1;
      default:                  return powerShot ? 2 : 1;
    }
  }

  Color _powerColor(Weapon weapon) {
    switch (weapon.weaponType) {
      case WeaponType.bow:      return Colors.red;
      case WeaponType.staff:    return Colors.blue;
      case WeaponType.dagger:   return Colors.purple;
      case WeaponType.crossbow: return Colors.yellow;
      default:                  return weapon.projectileColor;
    }
  }

  // ── Input ─────────────────────────────────────────────────────────────────

  void handleMovementInput(Vector2 inputDelta) {
    if (inputDelta.x == 0 || characterState.isBlocking) {
      if (!characterState.isAttackCommitted && !characterState.isBlocking) performStopWalk();
      return;
    }
    final dir   = Vector2(inputDelta.x, 0);
    final speed = movementStrategy.resolveSpeed(
      baseSpeed: stats.dexterity / 2,
      inputMagnitude: inputDelta.x.abs(),
      isAttackCommitted: characterState.isAttackCommitted,
    ) * effectiveMoveSpeedMod;
    if (movementStrategy.isRunning(inputDelta.x.abs()) && !characterState.isAttackCommitted) {
      performRun(dir, speed);
    } else {
      performWalk(dir, speed);
    }
  }

  void handleBlockInput(GamepadManager gamepad) {
    if (gamepad.isBlockPressed && characterState.groundPlatform != null) {
      startBlock(); velocity.x = 0;
    } else { stopBlock(); }
  }

  void handleJumpFromInput(GamepadManager gamepad) {
    final pressed = game.joystick.direction == JoystickDirection.up || gamepad.isJumpPressed;
    if (!characterState.isBlocking && !characterState.isAttackCommitted) {
      handleJumpInput(pressed);
    } else { prevJumpInput = pressed; }
  }

  void handleDodgeInput(GamepadManager gamepad, Vector2 inputDelta) {
    final stickDodge = inputDelta.length > actionStrategy.dodgeStickThreshold &&
        (inputDelta.y * actionStrategy.dodgeStickYSign) > actionStrategy.dodgeStickThreshold;
    final btnDodge   = actionStrategy.dodgeEdgeDetect
        ? gamepad.isDodgeJustPressed() : gamepad.isDodgePressed;
    if ((stickDodge || btnDodge) &&
        characterState.groundPlatform != null &&
        !characterState.isBlocking &&
        characterState.dodgeCooldown <= 0) {
      dodge(inputDelta.x != 0
          ? Vector2(inputDelta.x, 0) : Vector2(facingRight ? 1 : -1, 0));
    }
  }

  void updateHumanControl(double dt) {
    if (characterState.isStunned || characterState.isLanding || characterState.isDodging) return;
    final gp = game.gamepadManager;
    var input = game.joystick.relativeDelta;
    if (gp.isGamepadConnected && gp.hasMovementInput()) input = gp.getJoystickDirection();
    handleMovementInput(input);
    handleBlockInput(gp);
    handleJumpFromInput(gp);
    handleDodgeInput(gp, input);
  }

  // ── Update ────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    if (characterState.health <= 0) { velocity = Vector2.zero(); return; }

    _stateMachine.update(dt);
    characterState.wasGrounded = characterState.groundPlatform != null;
    characterState.velocity    = velocity;

    _updateTimers(dt);
    _handleStates(dt);

    if (!characterState.isStunned && characterState.health > 0) {
      if (characterState.isLanding && characterState.landingAnimationTimer > 0.1) {
        velocity.x *= GameConfig.landingFriction;
      } else {
        if (playerType == PlayerType.human) updateHumanControl(dt);
        else                                updateBotControl(dt);
      }
    }

    applyPhysics(dt);

    final grounded = characterState.groundPlatform != null;

    if (characterState.wasGrounded && !grounded && velocity.y < GameConfig.maxLandingUpwardVelocity) {
      characterState..jumpAnimationTimer=0.3..isAirborne=true..isJumping=true..airborneTime=0;
      _eventBus.emit(CharacterAirborneEvent(characterId: stats.name, position: position.clone(), velocity: velocity.clone()));
    }

    if (!characterState.wasGrounded && grounded && velocity.y > GameConfig.landingVelocityThreshold) {
      handleLandingWithEvent();
      characterState..landingAnimationTimer=0.25..isLanding=true..isAirborne=false..isJumping=false..hasDoubleJumped=false;
    }

    if (grounded) { characterState..isAirborne=false..airborneTime=0..isJumping=false; }
    else          { characterState.isAirborne=true; characterState.airborneTime+=dt; }

    _updateAnimation();
    size.y = characterState.isCrouching ? baseHeight / 2 : baseHeight;

    if (grounded && velocity.x.abs() < GameConfig.stopThreshold &&
        !characterState.isAttacking && !characterState.isBlocking &&
        !characterState.isDodging && !characterState.isJumping && !characterState.isAirborne &&
        _currentAnimationState != 'idle') {
      _eventBus.emit(CharacterIdleEvent(characterId: stats.name, position: position.clone()));
    }
  }

  void _updateAnimation() {
    if (!spritesLoaded) return;
    final desired  = _stateMachine.evaluateState(characterState);
    final changed  = _stateMachine.requestStateChange(desired);
    final cur      = _stateMachine.currentState;

    final anim = switch (cur) {
      CharacterAnimState.idle      => idleAnimation,
      CharacterAnimState.walking   => walkAnimation,
      CharacterAnimState.running   => runAnimation ?? walkAnimation,
      CharacterAnimState.jumping   => jumpAnimation,
      CharacterAnimState.falling   => jumpAnimation,
      CharacterAnimState.landing   => landingAnimation,
      CharacterAnimState.attacking => attackAnimation,
      _                            => idleAnimation,
      CharacterAnimState.dead      => null,
    };

    if (changed) {
      final s = cur.toString().split('.').last;
      _eventBus.emit(CharacterAnimationChangedEvent(
        characterId: stats.name, position: position.clone(),
        previousAnimation: _currentAnimationState, newAnimation: s,
        isLooping: cur == CharacterAnimState.idle || cur == CharacterAnimState.walking || cur == CharacterAnimState.running,
      ));
      _currentAnimationState = s;
    }
    if (anim != null && animation != anim) animation = anim;
    scale.x = facingRight ? 1 : -1;
  }

  // ── Render ────────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    if (isDead) return;

    if (isPlayer && characterState.health <= 0) {
      canvas.saveLayer(Rect.fromLTWH(0,0,size.x,size.y), Paint()..color=Colors.white.withOpacity(0.3));
      super.render(canvas);
      canvas.restore();
      _paintText(canvas, '💀', fontSize: 40, offset: Offset(size.x/2, -50));
      return;
    }
    if (isBot && characterState.health <= 0) return;

    super.render(canvas);

    if (characterState.isStunned)  _renderStunEffect(canvas);
    if (characterState.isDodging)  _renderDodgeEffect(canvas);
    if (characterState.isBlocking) _renderBlockEffect(canvas);
    if (_equippedWeapon != null)   _renderWeaponDot(canvas);

    if (isBot && characterState.health > 0) {
      final hp = (characterState.health/100).clamp(0.0,1.0);
      canvas.drawRect(Rect.fromLTWH(0,-20,size.x,10), Paint()..color=Colors.red);
      canvas.drawRect(Rect.fromLTWH(0,-20,size.x*hp,10), Paint()..color=Colors.green);
    }
    if (isPlayer) {
      final sp = (characterState.stamina/characterState.maxStamina).clamp(0.0,1.0);
      canvas.drawRect(Rect.fromLTWH(0,size.y+5,size.x,5), Paint()..color=Colors.grey.withOpacity(0.5));
      canvas.drawRect(Rect.fromLTWH(0,size.y+5,size.x*sp,5), Paint()..color=Colors.yellow);
    }
    if (characterState.comboCount > 1) _renderCombo(canvas);
  }

  void _renderWeaponDot(Canvas canvas) {
    canvas.drawCircle(
      Offset(facingRight ? size.x-10 : 10, size.y*0.45),
      6,
      Paint()..color = _equippedWeapon!.projectileColor.withOpacity(0.85),
    );
  }

  void _renderStunEffect(Canvas canvas) {
    final rot = (DateTime.now().millisecondsSinceEpoch/200)%(math.pi*2);
    final p   = Paint()..color=Colors.yellow;
    for (int i=0;i<3;i++) {
      final a = rot + i*math.pi*2/3;
      canvas.drawCircle(Offset(size.x/2+math.cos(a)*30, -20+math.sin(a)*12), 5, p);
    }
  }

  void _renderDodgeEffect(Canvas canvas) {
    final op = (characterState.dodgeDuration/0.3).clamp(0.0,1.0)*0.5;
    canvas.drawRect(Rect.fromLTWH(0,0,size.x,size.y), Paint()..color=stats.color.withOpacity(op));
  }

  void _renderBlockEffect(Canvas canvas) {
    canvas.drawCircle(Offset(size.x/2,size.y/2), size.x/2+10,
        Paint()..color=Colors.blue.withOpacity(0.3)..style=PaintingStyle.stroke..strokeWidth=3);
  }

  void _renderCombo(Canvas canvas) {
    _paintText(canvas, 'x${characterState.comboCount}',
        fontSize: 24, color: Colors.orange, offset: Offset(size.x/2,-40));
  }

  void _paintText(Canvas canvas, String text,
      {double fontSize=16, Color color=Colors.white, Offset offset=Offset.zero}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize,
          fontWeight: FontWeight.bold, shadows: const [Shadow(color: Colors.black, blurRadius: 4)])),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(offset.dx-tp.width/2, offset.dy-tp.height/2));
  }

  // ── Physics ───────────────────────────────────────────────────────────────

  void applyPhysics(double dt) {
    if (characterState.groundPlatform==null && !characterState.isClimbing && !characterState.isDodging) {
      velocity.y = math.min(velocity.y + GameConfig.gravity*dt, GameConfig.maxFallSpeed);
    }
    if (characterState.groundPlatform!=null && !characterState.isAttackCommitted && !characterState.isDodging) {
      velocity.x *= characterState.isLanding ? GameConfig.landingFriction : GameConfig.groundFriction;
      if (velocity.x.abs() < GameConfig.stopThreshold) velocity.x = 0;
    }
    if (characterState.groundPlatform==null && !characterState.isDodging) velocity.x *= GameConfig.airResistance;

    final proposed = position + velocity*dt;
    GamePlatform? newGround;
    for (final p in game.platforms) {
      final pL=p.position.x-p.size.x/2, pR=p.position.x+p.size.x/2, pT=p.position.y-p.size.y/2;
      if (proposed.x+size.x/2<=pL || proposed.x-size.x/2>=pR) continue;
      final dist = (proposed.y+size.y/2)-pT;
      if (velocity.y>=0 && dist>-4 && dist<GameConfig.platformDetectionRange) {
        position.y=pT-size.y/2; velocity.y=0; newGround=p; break;
      }
    }
    if (newGround==null) position.add(velocity*dt);
    else                 position.x+=velocity.x*dt;
    characterState.groundPlatform=newGround;
  }

  // ── Timers/states ─────────────────────────────────────────────────────────

  void _updateTimers(double dt) {
    if (characterState.attackCooldown>0)       characterState.attackCooldown-=dt;
    if (characterState.dodgeCooldown>0)        characterState.dodgeCooldown-=dt;
    if (characterState.landingAnimationTimer>0) characterState.landingAnimationTimer-=dt;
    if (characterState.jumpAnimationTimer>0)   characterState.jumpAnimationTimer-=dt;
    if (characterState.comboTimer>0) {
      characterState.comboTimer-=dt;
      if (characterState.comboTimer<=0) {
        if (characterState.comboCount>1) {
          _eventBus.emit(CharacterComboBrokenEvent(characterId:stats.name, position:position.clone(), maxComboReached:characterState.comboCount, reason:'timeout'));
        }
        characterState.comboCount=0;
      }
    }
    if (characterState.attackAnimationTimer>0) {
      characterState.attackAnimationTimer-=dt;
      if (characterState.attackAnimationTimer<=0) {
        characterState.isAttacking=false;
        _eventBus.emit(CharacterAttackCompletedEvent(characterId:stats.name, position:position.clone(),
            attackType:stats.attackRange>5?'ranged':'melee', targetsHit:0, totalDamage:0));
      }
    }
    if (characterState.attackCommitTime>0) {
      characterState.attackCommitTime-=dt;
      if (characterState.attackCommitTime<=0) characterState.isAttackCommitted=false;
    }
  }

  void _handleStates(double dt) {
    if (characterState.stamina<characterState.maxStamina &&
        !characterState.isBlocking && !characterState.isDodging && !characterState.isAttacking) {
      final old=characterState.stamina;
      characterState.stamina=math.min(characterState.maxStamina, characterState.stamina+15*dt);
      if (characterState.stamina-old>5) {
        _eventBus.emit(CharacterStaminaRegenEvent(characterId:stats.name, position:position.clone(),
            amount:characterState.stamina-old, currentStamina:characterState.stamina, maxStamina:characterState.maxStamina));
      }
    }
    if (characterState.isBlocking) {
      characterState.stamina-=15*dt;
      if (characterState.stamina<=0) { characterState.stamina=0; breakGuard(); }
    }
    if (characterState.isDodging) {
      characterState.dodgeDuration-=dt;
      if (characterState.dodgeDuration<=0) {
        characterState.isDodging=false; velocity.x*=0.3;
        _eventBus.emit(CharacterDodgeCompletedEvent(characterId:stats.name, position:position.clone(), avoidedDamage:false));
      } else { velocity.x=characterState.dodgeDirection.x*stats.dexterity*15; }
    }
    if (characterState.isStunned) {
      characterState.stunDuration-=dt; velocity.x=0;
      if (characterState.stunDuration<=0) recoverFromStun();
      return;
    }
    if (characterState.isLanding) {
      characterState.landingRecoveryTime-=dt; velocity.x*=0.5;
      if (characterState.landingRecoveryTime<=0) characterState.isLanding=false;
    }
  }

  // ── Combat ────────────────────────────────────────────────────────────────

  void updateBotControl(double dt);

  /// Class-default attack used when no weapon is equipped.
  void attack();

  bool prepareAttackWithEvent() {
    if (characterState.isLanding || characterState.isStunned || characterState.isDodging ||
        characterState.attackCooldown>0 || characterState.stamina<15) return false;
    if (characterState.isAirborne) { characterState.attackCooldown=1.0; characterState.stamina-=20; }
    else                           { characterState.attackCooldown=0.5; characterState.stamina-=15; }
    characterState
      ..isAttacking=true ..isAttackCommitted=true
      ..attackCommitTime=GameConfig.attackCommitTime
      ..attackAnimationTimer=effectiveAttackDuration;
    if (characterState.comboTimer>0) {
      characterState.comboCount++; characterState.comboTimer=characterState.comboWindow;
    } else {
      characterState.comboCount=1; characterState.comboTimer=characterState.comboWindow;
      _eventBus.emit(CharacterComboStartedEvent(characterId:stats.name, position:position.clone()));
    }
    characterState.lastAttackDirection=facingRight?1:-1;
    if (!characterState.isAirborne) velocity.x+=characterState.lastAttackDirection*50;
    final atkType = _equippedWeapon!=null
        ? (_equippedWeapon!.isRanged?'ranged':'melee')
        : (stats.attackRange>5?'ranged':'melee');
    _eventBus.emit(CharacterAttackStartedEvent(characterId:stats.name, position:position.clone(),
        attackType:atkType, comboCount:characterState.comboCount,
        staminaCost:characterState.isAirborne?20:15));
    return true;
  }

  void handleLandingWithEvent() {
    final fs=velocity.y; final hard=fs>characterState.hardLandingThreshold; double dmg=0;
    if (hard) {
      final st=math.min(1.0,(fs-characterState.hardLandingThreshold)/200);
      characterState..isStunned=true..stunDuration=st;
      dmg=(fs-characterState.hardLandingThreshold)/50; takeDamage(dmg);
      _eventBus.emit(CharacterStunnedEvent(characterId:stats.name, position:position.clone(), duration:st, source:'hard_landing'));
    } else if (fs>200) {
      characterState..isLanding=true..landingRecoveryTime=GameConfig.landingRecoveryTime;
    }
    velocity.y=0;
    _eventBus.emit(CharacterLandedEvent(characterId:stats.name, position:position.clone(), fallSpeed:fs, isHardLanding:hard, damage:dmg));
  }

  void recoverFromStun() {
    if (!characterState.isStunned) return;
    characterState..isStunned=false..stunDuration=0;
    _eventBus.emit(CharacterStunRecoveredEvent(characterId:stats.name, position:position.clone()));
  }

  void breakGuard() {
    if (!characterState.isBlocking) return;
    stopBlock(); characterState..isStunned=true..stunDuration=0.5;
    _eventBus.emit(CharacterGuardBrokenEvent(characterId:stats.name, position:position.clone(), stunDuration:0.5));
  }

  void handleJumpInput(bool pressed) {
    final just=pressed&&!prevJumpInput; prevJumpInput=pressed;
    if (!just) return; performJump();
  }

  void performJump({double? customPower}) {
    final grounded=characterState.groundPlatform!=null;
    if (grounded && characterState.stamina>=GameConfig.jumpStaminaCost) {
      final p=customPower??jumpPower; velocity.y=p;
      characterState..groundPlatform=null..stamina-=GameConfig.jumpStaminaCost..isJumping=true..isAirborne=true..airborneTime=0..hasDoubleJumped=false;
      _eventBus.emit(CharacterJumpedEvent(characterId:stats.name, position:position.clone(), jumpPower:p.abs(), staminaCost:GameConfig.jumpStaminaCost.toDouble(), isDoubleJump:false));
      return;
    }
    if (!grounded && characterState.isAirborne && characterState.canDoubleJump &&
        !characterState.hasDoubleJumped && characterState.stamina>=GameConfig.jumpStaminaCost) {
      final p=customPower!=null?customPower*0.85:doubleJumpPower; velocity.y=p;
      characterState..stamina-=GameConfig.jumpStaminaCost..hasDoubleJumped=true..jumpAnimationTimer=0.3;
      _eventBus.emit(CharacterJumpedEvent(characterId:stats.name, position:position.clone(), jumpPower:p.abs(), staminaCost:GameConfig.jumpStaminaCost.toDouble(), isDoubleJump:true));
    }
  }

  void performWalk(Vector2 dir, double speed) {
    final was=facingRight; facingRight=dir.x>0;
    if (velocity.x.abs()<GameConfig.stopThreshold && dir.x.abs()>0)
      _eventBus.emit(CharacterWalkStartedEvent(characterId:stats.name, position:position.clone(), direction:dir, speed:speed));
    if (facingRight!=was)
      _eventBus.emit(CharacterTurnedEvent(characterId:stats.name, position:position.clone(), nowFacingRight:facingRight));
    velocity.x=dir.x*speed;
  }

  void performRun(Vector2 dir, double speed) {
    final was=facingRight; facingRight=dir.x>0;
    if (facingRight!=was)
      _eventBus.emit(CharacterTurnedEvent(characterId:stats.name, position:position.clone(), nowFacingRight:facingRight));
    velocity.x=dir.x*speed;
    _eventBus.emit(CharacterRunStartedEvent(characterId:stats.name, position:position.clone(), direction:dir, speed:speed));
  }

  void performStopWalk() {
    if (velocity.x.abs()>5)
      _eventBus.emit(CharacterWalkStoppedEvent(characterId:stats.name, position:position.clone()));
    velocity.x*=0.7;
  }

  void dodge(Vector2 dir) {
    if (characterState.dodgeCooldown>0||characterState.isDodging||characterState.stamina<GameConfig.dodgeStaminaCost) return;
    characterState..isDodging=true..dodgeDuration=GameConfig.dodgeDuration..dodgeCooldown=GameConfig.dodgeCooldown..stamina-=GameConfig.dodgeStaminaCost..dodgeDirection=dir.normalized();
    _eventBus.emit(CharacterDodgeStartedEvent(characterId:stats.name, position:position.clone(),
        dodgeDirection:characterState.dodgeDirection, duration:GameConfig.dodgeDuration, staminaCost:GameConfig.dodgeStaminaCost));
  }

  void startBlock() {
    if (characterState.stamina<10||characterState.isDodging||characterState.isAttacking||characterState.isBlocking) return;
    characterState.isBlocking=true; _blockStartTime=DateTime.now();
    _eventBus.emit(CharacterBlockStartedEvent(characterId:stats.name, position:position.clone(), staminaPerSecond:15.0));
  }

  void stopBlock() {
    if (!characterState.isBlocking) return;
    final dur=_blockStartTime!=null?DateTime.now().difference(_blockStartTime!).inMilliseconds/1000.0:0.0;
    characterState.isBlocking=false;
    final reason=characterState.stamina<=0?'stamina_depleted':characterState.isStunned?'interrupted':'manual';
    _eventBus.emit(CharacterBlockStoppedEvent(characterId:stats.name, position:position.clone(), reason:reason, duration:dur));
    _blockStartTime=null;
  }

  void takeDamage(double damage) {
    if (characterState.isDodging) return;
    if (characterState.isBlocking && characterState.stamina>0) {
      damage*=0.3; characterState.stamina-=GameConfig.blockStaminaDrain;
      if (characterState.stamina<0) { characterState.stamina=0; characterState.isBlocking=false; }
    }
    characterState.health=math.max(0,characterState.health-damage);
    characterState.lastDamageTaken=damage;
    if (!characterState.isAttackCommitted) { characterState.isAttacking=false; characterState.attackAnimationTimer=0; }
    if (damage>10 && !characterState.isBlocking) { velocity.x=-characterState.lastAttackDirection*100; characterState.comboCount=0; }
  }
}