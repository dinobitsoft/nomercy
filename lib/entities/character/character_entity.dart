import 'package:flame/components.dart';

import '../../action_game.dart';
import '../../character_stats.dart';
import '../../components/health_component.dart';
import '../../config/game_config.dart';
import '../../core/event_bus.dart';
import '../../game/bot_tactic.dart';
import '../../managers/resource_manager.dart' hide Vector2;
import '../../player_type.dart';
import '../../tiled_platform.dart';

class CharacterEntity extends SpriteAnimationComponent
    with HasGameReference<ActionGame> {

  // Components (composition over inheritance)
  late final HealthComponent health;
  late final StaminaComponent stamina;
  late final AnimationComponent animationManager;

  // Core properties
  final CharacterStats stats;
  final PlayerType playerType;
  final BotTactic? botTactic;

  // Physics
  Vector2 velocity = Vector2.zero();
  TiledPlatform? groundPlatform;
  bool facingRight = true;

  // State flags (could be extracted to StateComponent)
  bool isAttacking = false;
  bool isBlocking = false;
  bool isDodging = false;
  bool isStunned = false;
  bool isAirborne = false;

  // Combat
  int comboCount = 0;
  double comboTimer = 0;
  double attackCooldown = 0;
  double dodgeCooldown = 0;

  CharacterEntity({
    required Vector2 position,
    required this.stats,
    required this.playerType,
    this.botTactic,
  }) : super(position: position) {
    size = Vector2(GameConfig.characterWidth, GameConfig.characterHeight);
    anchor = Anchor.center;
    priority = 100;

    // Initialize components
    health = HealthComponent(max: GameConfig.characterBaseHealth);
    stamina = StaminaComponent(max: GameConfig.characterBaseStamina);

    // Setup callbacks
    health.onDamage(_onDamageTaken);
    health.onDeath(_onDeath);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _initializeAnimations();
  }

  Future<void> _initializeAnimations() async {
    final resourceManager = ResourceManager();
    final characterName = stats.name.toLowerCase();

    // Load all animations
    final anims = {
      'idle': resourceManager.getAnimation(
        characterName, 'idle',
        stepTime: 0.2,
        loop: true,
      ),
      'walk': resourceManager.getAnimation(
        characterName, 'walk',
        stepTime: 0.1,
        loop: true,
      ),
      'attack': resourceManager.getAnimation(
        characterName, 'attack',
        stepTime: 0.06,
        loop: false,
      ),
      'jump': resourceManager.getAnimation(
        characterName, 'jump',
        stepTime: 0.15,
        loop: false,
      ),
      'land': resourceManager.getAnimation(
        characterName, 'landing',
        stepTime: 0.125,
        loop: false,
      ),
    };

    // Animation priorities (higher = can interrupt lower)
    final priorities = {
      'idle': 0,
      'walk': 1,
      'jump': 2,
      'land': 3,
      'attack': 4,
      'stun': 5,
    };

    animationManager = AnimationComponent(
      animations: anims,
      initialState: 'idle',
      statePriority: priorities,
    );

    animation = animationManager.animation;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Update components
    stamina.update(dt);
    animationManager.update(dt);

    // Update timers
    if (attackCooldown > 0) attackCooldown -= dt;
    if (dodgeCooldown > 0) dodgeCooldown -= dt;
    if (comboTimer > 0) {
      comboTimer -= dt;
      if (comboTimer <= 0) comboCount = 0;
    }

    // Update animation state based on flags
    _updateAnimationState();

    // Apply current animation
    animation = animationManager.animation;
    scale.x = facingRight ? 1 : -1;
  }

  void _updateAnimationState() {
    if (isStunned) {
      animationManager.setState('idle', force: true);
    } else if (isAttacking) {
      animationManager.setState('attack');
      if (animationManager.isAnimationFinished) {
        isAttacking = false;
      }
    } else if (isAirborne) {
      animationManager.setState('jump');
    } else if (velocity.x.abs() > 5) {
      animationManager.setState('walk');
    } else {
      animationManager.setState('idle');
    }
  }

  /// Combat methods
  void attack() {
    if (attackCooldown > 0 || !stamina.use(15)) return;

    isAttacking = true;
    attackCooldown = GameConfig.attackCooldown;

    // Update combo
    if (comboTimer > 0) {
      comboCount++;
    } else {
      comboCount = 1;
    }
    comboTimer = GameConfig.comboWindow;

    // Emit event
    EventBus().emit(CharacterAttackedEvent(
      attackerId: stats.name,
      targetId: 'target',
      damage: stats.attackDamage,
    ));
  }

  void takeDamage(double amount) {
    health.takeDamage(amount);
  }

  void _onDamageTaken(double amount) {
    // Reset combo on damage
    comboCount = 0;

    // Visual feedback
    DebugConfig.log('${stats.name} took $amount damage');
  }

  void _onDeath() {
    DebugConfig.log('${stats.name} died');

    // Emit death event
    EventBus().emit(CharacterKilledEvent(
      victimId: stats.name,
      killerId: 'unknown',
      bounty: 20,
    ));
  }
}