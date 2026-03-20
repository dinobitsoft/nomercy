import 'package:engine/engine.dart';

abstract class ActionStrategy {
  double get jumpPower;
  double get doubleJumpMultiplier => 0.85;

  double get dodgeStickYSign;
  bool   get dodgeEdgeDetect;
  double get dodgeStickThreshold => 0.5;

  // ── Animation durations (total seconds for the full clip) ───────────────
  // Attack: should match or be slightly shorter than attackCooldown so the
  // player never fires the next attack before the sprite finishes.
  double get attackDuration;

  double get jumpStepTime    => 0.15;
  double get landingStepTime => 0.12;

  double get defaultAttackRange;
  String get defaultWeaponName;

  // Computed step time given the number of frames in the loaded clip.
  double attackStepTime(int frameCount) =>
      frameCount > 0 ? attackDuration / frameCount : attackDuration;

  /// Skills available to this character class.
  /// Slot 0 = primary skill (L1 / shoulder button).
  /// Slot 1 = secondary skill (R1 / shoulder button).
  List<Skill> get skills;
}