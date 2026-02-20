import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';

class GameCharacterState {
  // State
  double health = GameConfig.characterBaseHealth;
  double stamina = GameConfig.characterBaseStamina;
  double maxStamina = 100;
  bool isCrouching = false;
  bool isClimbing = false;
  bool isWallSliding = false;
  bool isJumping = false;
  bool isAirborne = false;
  bool isAttacking = false;
  double airborneTime = 0;
  double attackCooldown = GameConfig.attackCooldown;
  double attackAnimationTimer = 0;

  // State tracking
  bool wasGrounded = false;
  double landingAnimationTimer = 0;
  double jumpAnimationTimer = 0;

  // Double jump
  bool hasDoubleJumped = false;
  bool canDoubleJump = true;

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
  Vector2 velocity = Vector2.zero();

  // Parry/Block mechanic
  bool isBlocking = false;
  double blockStamina = 0;
  double lastDamageTaken = 0;

  // Combo system
  int comboCount = 0;
  double comboTimer = 0;
  double comboWindow = 1.5;

  GamePlatform? groundPlatform; //TODO: it should not belong to this class
}