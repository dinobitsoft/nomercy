// modules/engine/lib/src/components/character/game_character_3d.dart

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../utils/sprite_utils.dart';
import '../obstacle/obstacle_3d.dart';
import '../platform/game_platform_3d.dart';
import '../projectile/projectile_3d.dart';

/// Base class for all 3D characters.
///
/// Physics and world logic run entirely in [WorldPos] / 3D space.
/// The Flame [position] is derived every frame via [IsoProjection] so the
/// camera, HUD anchors and Flame event system all work without changes.
///
/// Movement axes:
///   X  → strafe left / right
///   Y  → up / down (gravity)
///   Z  → forward / backward (main run direction)
abstract class GameCharacter3D extends SpriteAnimationGroupComponent<CharacterAnimState>
    with HasGameReference<ActionGame3D> {

  // ── 3D state ───────────────────────────────────────────────────────────────
  WorldPos worldPos = WorldPos.zero();
  WorldPos velocity = WorldPos.zero();

  /// Facing angle in XZ plane (radians, 0 = +X right, π/2 = +Z forward).
  double facingAngle = math.pi / 2;   // default: facing toward camera (-Z)

  /// Last non-zero XZ move direction (unit vector), used for projectile aim.
  WorldPos _lastMoveDir = WorldPos(0, 0, 1);

  /// Current platform the character stands on (null = airborne or on floor).
  GamePlatform3D? groundPlatform;

  /// Current obstacle the character stands on top of (null if not on one).
  Obstacle3D? groundObstacle;

  /// True when the character is resting on the infinite ground floor (Y=0).
  bool _onInfiniteFloor = false;

  // ── stats & state machine ─────────────────────────────────────────────────
  final GameCharacterState characterState;
  final CharacterStats stats;
  final PlayerType playerType;
  final String uniqueId;

  // strategy pattern — unchanged from 2D
  ActionStrategy  get actionStrategy;
  MovementStrategy get movementStrategy;

  // ── timers ────────────────────────────────────────────────────────────────
  bool _prevJumpInput = false;

  double get jumpPower       => GameConfig3D.jumpVelocity;
  double get doubleJumpPower => GameConfig3D.doubleJumpVelocity;

  // ── cached assets ─────────────────────────────────────────────────────────
  bool spritesLoaded = false;

  // ── shadow ────────────────────────────────────────────────────────────────
  static final Paint _shadowPaint = Paint()
    ..color = Colors.black.withOpacity(0.35)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

  GameCharacter3D({
    required this.stats,
    required this.playerType,
    required this.uniqueId,
    required WorldPos initialPos,
    Map<CharacterAnimState, SpriteAnimation>? animations,
  })  : characterState = GameCharacterState(),
        super(
        animations: animations ?? {},
        current: CharacterAnimState.idle,
        anchor: Anchor.bottomCenter,
        size: Vector2(GameConfig.characterWidth, GameConfig.characterHeight),
      ) {
    worldPos = initialPos.clone();
  }

  // ── lifecycle ─────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Scale sprite so the character occupies the same visual fraction of the
    // screen as in 2D mode (which uses a virtual 1280/1.2 ≈ 1067 px canvas).
    final screenW = game.size.x;
    final scale3d = screenW / (1280.0 / 1.2);
    final w = GameConfig.characterWidth  * scale3d;
    final h = GameConfig.characterHeight * scale3d;
    size = Vector2(w, h);
    await _loadAnimations();
    spritesLoaded = true;
    _syncScreenPosition();
  }

  Future<void> _loadAnimations() async {
    final charName = stats.name.toLowerCase();
    final ms       = movementStrategy;
    final as_      = actionStrategy;

    SpriteAnimation fb() => SpriteAnimation.spriteList([], stepTime: 0.2);

    final idle  = await loadAnim(game, charName, 'idle',    stepTime: ms.idleStepTime, loop: true)  ?? fb();
    final walk  = await loadAnim(game, charName, 'walk',    stepTime: ms.walkStepTime, loop: true,  fallback: idle) ?? idle;
    final run   = await loadAnim(game, charName, 'run',     stepTime: ms.runStepTime,  loop: true,  fallback: walk) ?? walk;
    final jump  = await loadAnim(game, charName, 'jump',    stepTime: as_.jumpStepTime,    loop: true,  fallback: idle) ?? idle;
    final land  = await loadAnim(game, charName, 'landing', stepTime: as_.landingStepTime, loop: false, fallback: idle) ?? idle;
    final atk   = await loadAnimDynamic(game, charName, 'attack',
        totalDuration: as_.attackDuration, loop: false, fallback: idle) ?? idle;

    animations = {
      CharacterAnimState.idle:      idle,
      CharacterAnimState.walking:   walk,
      CharacterAnimState.running:   run,
      CharacterAnimState.jumping:   jump,
      CharacterAnimState.falling:   jump,
      CharacterAnimState.landing:   land,
      CharacterAnimState.attacking: atk,
      CharacterAnimState.dead:      idle,
    };
  }

  // ── update ────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    if (characterState.health <= 0) {
      velocity.setZero();
      current = CharacterAnimState.dead;
      return;
    }

    characterState.wasGrounded = groundPlatform != null || _onInfiniteFloor;

    _updateTimers(dt);

    if (!characterState.isStunned) {
      if (playerType == PlayerType.human) updateHumanControl(dt);
      else                                updateBotControl(dt);
    }

    _applyPhysics3D(dt);
    _detectLandingTakeoff();
    _updateAnimation3D();
    _syncScreenPosition();
    _syncDepthPriority();
  }

  // ── physics ───────────────────────────────────────────────────────────────

  void _applyPhysics3D(double dt) {
    final grounded = groundPlatform != null || groundObstacle != null || _onInfiniteFloor;

    // Gravity
    if (!grounded) {
      velocity.y = math.max(
          velocity.y - GameConfig3D.gravity * dt,
          -GameConfig3D.maxFallSpeed);
    }

    // XZ friction
    if (grounded) {
      final f = characterState.isLanding
          ? GameConfig3D.landingFriction
          : GameConfig3D.groundFrictionXZ;
      velocity.x *= f;
      velocity.z *= f;
      if (velocity.x.abs() < GameConfig3D.stopThreshold) velocity.x = 0;
      if (velocity.z.abs() < GameConfig3D.stopThreshold) velocity.z = 0;
      velocity.y = 0; // flush to ground
    } else {
      velocity.x *= GameConfig3D.airResistanceXZ;
      velocity.z *= GameConfig3D.airResistanceXZ;
    }

    // Proposed position
    final proposed = WorldPos(
      worldPos.x + velocity.x * dt,
      worldPos.y + velocity.y * dt,
      worldPos.z + velocity.z * dt,
    );

    GamePlatform3D? newGround;
    Obstacle3D?    newObstGround;

    // AABB of character at proposed position (XZ footprint for platform checks)
    final charAabb = AABB3D.fromCenter(
      center: WorldPos(proposed.x, proposed.y + GameConfig3D.characterSizeY / 2, proposed.z),
      sizeX: GameConfig3D.characterSizeX,
      sizeY: GameConfig3D.characterSizeY,
      sizeZ: GameConfig3D.characterSizeZ,
    );

    // ── Platform top-landing (unchanged) ──────────────────────────────────
    for (final platform in game.platforms3D) {
      if (!platform.footprintOverlaps(charAabb)) continue;

      final charBottom = proposed.y;
      final dist       = charBottom - platform.topY;

      if (velocity.y <= 0 && dist > -GameConfig3D.landSnapWindow && dist < 16) {
        proposed.y = platform.topY;
        velocity.y = 0;
        newGround  = platform;
        break;
      }
    }

    // ── Obstacle collision (top-landing + lateral wall push-back) ─────────
    for (final obs in game.obstacles3D) {
      // -- TOP LANDING: same snap logic as platforms ----------------------
      if (newGround == null && obs.footprintOverlaps(charAabb)) {
        final dist = proposed.y - obs.topY;
        if (velocity.y <= 0 && dist > -GameConfig3D.landSnapWindow && dist < 16) {
          proposed.y  = obs.topY;
          velocity.y  = 0;
          newObstGround = obs;
          continue; // standing on top — skip lateral check for this obstacle
        }
      }

      // -- LATERAL WALL: full XYZ AABB overlap → MTD push-back -----------
      //
      // Build character AABB at proposed position (full height, not just
      // footprint) so we detect side-entry correctly.
      final hcx = GameConfig3D.characterSizeX / 2;
      final hcz = GameConfig3D.characterSizeZ / 2;
      final charFull = AABB3D(
        minX: proposed.x - hcx,
        maxX: proposed.x + hcx,
        minY: proposed.y,
        maxY: proposed.y + GameConfig3D.characterSizeY,
        minZ: proposed.z - hcz,
        maxZ: proposed.z + hcz,
      );

      final ob = obs.aabb;
      if (!charFull.overlapsXYZ(ob)) continue;

      // Minimum Translation Distance on X and Z axes.
      final penXLeft  = charFull.maxX - ob.minX;   // char entered from -X side
      final penXRight = ob.maxX - charFull.minX;    // char entered from +X side
      final penZNear  = charFull.maxZ - ob.minZ;    // char entered from -Z side
      final penZFar   = ob.maxZ - charFull.minZ;    // char entered from +Z side

      final penX = math.min(penXLeft,  penXRight);
      final penZ = math.min(penZNear,  penZFar);

      if (penX < penZ) {
        // Resolve along X axis
        if (proposed.x < ob.centerX) {
          proposed.x = ob.minX - hcx;   // push left
        } else {
          proposed.x = ob.maxX + hcx;   // push right
        }
        velocity.x = 0;
      } else {
        // Resolve along Z axis
        if (proposed.z < ob.centerZ) {
          proposed.z = ob.minZ - hcz;   // push toward camera (-Z)
        } else {
          proposed.z = ob.maxZ + hcz;   // push away from camera (+Z)
        }
        velocity.z = 0;
      }
    }

    // ── Infinite ground floor ─────────────────────────────────────────────
    if (newGround == null && newObstGround == null &&
        proposed.y <= GameConfig3D.groundSurfaceY && velocity.y <= 0) {
      proposed.y       = GameConfig3D.groundSurfaceY;
      velocity.y       = 0;
      _onInfiniteFloor = true;
    } else if (proposed.y > GameConfig3D.groundSurfaceY) {
      _onInfiniteFloor = false;
    }

    worldPos.setFrom(proposed);
    groundPlatform = newGround;
    groundObstacle = newObstGround;
    // Note: characterState.groundPlatform is typed GamePlatform? (2D), not used in 3D path.
  }

  // ── landing / takeoff events ──────────────────────────────────────────────

  void _detectLandingTakeoff() {
    final grounded = groundPlatform != null || groundObstacle != null || _onInfiniteFloor;

    if (characterState.wasGrounded && !grounded) {
      characterState
        ..jumpAnimationTimer = 0.3
        ..isAirborne         = true
        ..isJumping          = true
        ..airborneTime       = 0;
    }

    if (!characterState.wasGrounded && grounded) {
      characterState
        ..landingAnimationTimer = 0.22
        ..isLanding             = true
        ..isAirborne            = false
        ..isJumping             = false
        ..hasDoubleJumped       = false;
    }

    if (grounded) {
      characterState
        ..isAirborne   = false
        ..airborneTime = 0
        ..isJumping    = false;
      groundObstacle ??= null; // keep; already set in _applyPhysics3D
    } else {
      characterState.isAirborne  = true;
      characterState.airborneTime += 0.016; // dt not available here; safe approx
    }
  }

  // ── actions ───────────────────────────────────────────────────────────────

  void performJump3D({double? customPower}) {
    final grounded = groundPlatform != null || groundObstacle != null || _onInfiniteFloor;
    final stamina  = characterState.stamina;

    if (grounded && stamina >= GameConfig3D.jumpStaminaCost) {
      velocity.y       = customPower ?? jumpPower;
      groundPlatform   = null;
      groundObstacle   = null;
      _onInfiniteFloor = false;
      characterState
        ..groundPlatform = null
        ..stamina -= GameConfig3D.jumpStaminaCost
        ..isJumping      = true
        ..isAirborne     = true
        ..hasDoubleJumped = false;
      return;
    }

    if (!grounded && characterState.isAirborne &&
        characterState.canDoubleJump && !characterState.hasDoubleJumped &&
        stamina >= GameConfig3D.jumpStaminaCost) {
      velocity.y = customPower != null ? customPower * 0.85 : doubleJumpPower;
      characterState
        ..stamina -= GameConfig3D.jumpStaminaCost
        ..hasDoubleJumped     = true
        ..jumpAnimationTimer  = 0.3;
    }
  }

  /// Move in 3D XZ plane. [inputX] = strafe, [inputZ] = forward/back.
  void performMove3D(double inputX, double inputZ, {bool run = false}) {
    final speed = run ? GameConfig3D.runSpeedX : GameConfig3D.walkSpeedX;

    if (inputX.abs() > 0.1 || inputZ.abs() > 0.1) {
      velocity.x = inputX * speed;
      velocity.z = inputZ * (run ? GameConfig3D.runSpeedZ : GameConfig3D.walkSpeedZ);
      facingAngle = math.atan2(inputZ, inputX);
    } else {
      // Decelerate
      velocity.x *= 0.7;
      velocity.z *= 0.7;
    }
  }

  // ── control ───────────────────────────────────────────────────────────────

  void updateHumanControl(double dt) {
    if (characterState.isStunned || characterState.isLanding ||
        characterState.isDodging) return;

    final gp    = game.gamepadManager;
    final gpDir = gp.joystickDelta;
    final stick = gpDir.length > 0.1 ? gpDir : game.joystick.relativeDelta;

    // In the 3D corridor runner:
    //   joystick.x → world X (strafe)
    //   joystick.y → world Z (forward/backward — y-axis of stick = -z of world)
    final isRun = stick.length > 0.65;
    performMove3D(stick.x, -stick.y, run: isRun);

    // Jump
    final jumpJustPressed = gp.isGamepadConnected
        ? (gp.isJumpPressed && !_prevJumpInput)
        : (gp.isJumpPressed && !_prevJumpInput);
    _prevJumpInput = gp.isJumpPressed;
    if (jumpJustPressed) performJump3D();

    // Attack
    if (gp.isAttackPressed && !characterState.isAttacking &&
        characterState.attackCooldown <= 0) {
      performAttack3D();
    }
  }

  /// Override in bot subclasses.
  void updateBotControl(double dt) {}

  void performAttack3D() {
    characterState
      ..isAttacking          = true
      ..attackAnimationTimer = actionStrategy.attackDuration
      ..attackCooldown       = GameConfig.attackCooldown;

    // Ranged characters (attackRange > 3.0) fire a projectile in 3D space.
    if (stats.attackRange > 3.0) {
      _spawnProjectile3D();
    }
  }

  void _spawnProjectile3D() {
    // Spawn from character chest height.
    final spawnPos = WorldPos(
      worldPos.x,
      worldPos.y + GameConfig3D.characterSizeY * 0.65,
      worldPos.z,
    );

    // Direction: follow the character's last move direction.
    // Enemies override this to always aim at the player.
    WorldPos vel;
    if (playerType == PlayerType.human) {
      vel = WorldPos(
        _lastMoveDir.x * Projectile3D.speed,
        0,
        _lastMoveDir.z * Projectile3D.speed,
      );
    } else {
      final target = game.character.worldPos;
      final dx = target.x - worldPos.x;
      final dz = target.z - worldPos.z;
      final len = math.sqrt(dx * dx + dz * dz);
      if (len > 0.1) {
        vel = WorldPos(dx / len * Projectile3D.speed, 0, dz / len * Projectile3D.speed);
      } else {
        vel = WorldPos(_lastMoveDir.x * Projectile3D.speed, 0, _lastMoveDir.z * Projectile3D.speed);
      }
    }

    final proj = Projectile3D(
      spawnPos:   spawnPos,
      velocity3D: vel,
      damage:     stats.attackDamage,
      fromPlayer: playerType == PlayerType.human,
      type:       _projectileType(),
      color:      stats.color,
    );
    game.world.add(proj);
    game.projectiles3D.add(proj);
  }

  String _projectileType() => switch (stats.weaponName.toLowerCase()) {
    'fireball'          => 'fireball',
    'throwing knives'   => 'knife',
    'bow & arrow'       => 'arrow',
    _                   => 'default',
  };

  // ── timers ────────────────────────────────────────────────────────────────

  void _updateTimers(double dt) {
    if (characterState.attackAnimationTimer  > 0) characterState.attackAnimationTimer  -= dt;
    if (characterState.attackCooldown        > 0) characterState.attackCooldown        -= dt;
    if (characterState.landingAnimationTimer > 0) characterState.landingAnimationTimer -= dt;
    if (characterState.jumpAnimationTimer    > 0) characterState.jumpAnimationTimer    -= dt;
    if (characterState.dodgeCooldown         > 0) characterState.dodgeCooldown         -= dt;
    if (characterState.stunDuration          > 0) characterState.stunDuration          -= dt;

    if (characterState.attackAnimationTimer  <= 0) characterState.isAttacking  = false;
    if (characterState.landingAnimationTimer <= 0) characterState.isLanding    = false;
    if (characterState.stunDuration          <= 0) characterState.isStunned    = false;

    // Stamina regen
    if (characterState.stamina < characterState.maxStamina) {
      characterState.stamina = math.min(
          characterState.stamina + 15 * dt, characterState.maxStamina);
    }
  }

  // ── animation ─────────────────────────────────────────────────────────────

  void _updateAnimation3D() {
    final cs = characterState;
    CharacterAnimState next;

    if (cs.health <= 0)                                    next = CharacterAnimState.dead;
    else if (cs.isStunned)                                 next = CharacterAnimState.stunned;
    else if (cs.isAttacking && cs.attackAnimationTimer > 0.01) next = CharacterAnimState.attacking;
    else if (cs.isLanding   && cs.landingAnimationTimer > 0.01) next = CharacterAnimState.landing;
    else if (!cs.wasGrounded || cs.jumpAnimationTimer > 0) {
      next = velocity.y > 0 ? CharacterAnimState.jumping : CharacterAnimState.falling;
    } else if (velocity.x.abs() > 15 || velocity.z.abs() > 15) {
      next = (velocity.x.abs() + velocity.z.abs() > 350)
          ? CharacterAnimState.running
          : CharacterAnimState.walking;
    } else {
      next = CharacterAnimState.idle;
    }

    if (current != next) current = next;

    // Track last move direction for projectile aiming.
    final vx = velocity.x, vz = velocity.z;
    final vlen = math.sqrt(vx * vx + vz * vz);
    if (vlen > GameConfig3D.stopThreshold) {
      _lastMoveDir = WorldPos(vx / vlen, 0, vz / vlen);
    }

    // Flip sprite based on X movement direction
    if (velocity.x.abs() > GameConfig3D.stopThreshold) {
      scale.x = velocity.x > 0 ? 1.0 : -1.0;
    }
  }

  // ── projection helpers ────────────────────────────────────────────────────

  void _syncScreenPosition() {
    // Character sprite anchored at bottomCenter.
    // worldPos.y = bottom of character in world.
    final origin = game.worldOriginOnScreen;
    position = IsoProjection.projectXYZ(
      worldPos.x, worldPos.y, worldPos.z,
      screenOrigin: origin,
    );
  }

  void _syncDepthPriority() {
    priority = IsoProjection.depthPriority(worldPos) + 200;
  }

  // ── render ────────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    if (characterState.health <= 0 && current != CharacterAnimState.dead) return;

    // Drop shadow on ground
    _renderShadow(canvas);

    super.render(canvas);

    // Health / stamina bars drawn in world space above character head.
    _renderBars(canvas);
  }

  void _renderShadow(Canvas canvas) {
    final shadowY   = _screenYForWorldY(GameConfig3D.infiniteGroundY);
    final shadowDY  = position.y - shadowY; // how high above ground
    if (shadowDY.abs() > 800) return;

    final alpha   = (1.0 - shadowDY.abs() / 800).clamp(0.0, 0.35);
    final scaleW  = (1.0 - shadowDY.abs() / 800).clamp(0.3, 1.0);
    final shadow  = Rect.fromCenter(
      center: Offset(size.x / 2, size.y + shadowDY),
      width: size.x * 0.55 * scaleW,
      height: 18 * scaleW,
    );
    canvas.drawOval(shadow, Paint()..color = Colors.black.withOpacity(alpha));
  }

  double _screenYForWorldY(double wy) {
    final origin = game.worldOriginOnScreen;
    return IsoProjection.projectXYZ(worldPos.x, wy, worldPos.z, screenOrigin: origin).y
        - position.y;
  }

  void _renderBars(Canvas canvas) {
    const barW = 80.0;
    const barH = 8.0;
    const gap  = 4.0;
    final barX = size.x / 2 - barW / 2;
    final barY = -28.0;

    // Health bar
    _drawBar(canvas, barX, barY, barW, barH,
        characterState.health / stats.maxHealth,
        const Color(0xFF22cc44), const Color(0xFF333333));

    // Stamina bar
    _drawBar(canvas, barX, barY - barH - gap, barW, barH,
        characterState.stamina / characterState.maxStamina,
        const Color(0xFF4488ff), const Color(0xFF222244));
  }

  void _drawBar(Canvas canvas, double x, double y, double w, double h,
      double fill, Color fillColor, Color bgColor) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(3)),
      Paint()..color = bgColor,
    );
    if (fill > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, w * fill.clamp(0, 1), h),
            const Radius.circular(3)),
        Paint()..color = fillColor,
      );
    }
  }

  // ── damage ────────────────────────────────────────────────────────────────

  void takeDamage3D(double damage, {WorldPos? knockback}) {
    if (characterState.isDodging) return;
    if (characterState.isBlocking && characterState.stamina > 0) {
      damage *= 0.3;
      characterState.stamina -= GameConfig.blockStaminaDrain;
    }
    characterState.health = math.max(0, characterState.health - damage);
    if (knockback != null) {
      velocity.x += knockback.x;
      velocity.y += knockback.y;
      velocity.z += knockback.z;
    }
    if (characterState.health <= 0) onDeath();
  }

  void onDeath() {
    velocity.setZero();
    characterState.health = 0;
  }
}