import 'package:flutter/material.dart';
import 'package:flame/components.dart';

import '../game/action_game.dart';
import '../game/game_character.dart';

/// Add this to GameCharacter to visualize state issues
/// REMOVE AFTER DEBUGGING!
extension DebugVisualization on GameCharacter {

  void renderDebugInfo(Canvas canvas) {
    // Show current state as text
    final states = <String>[];

    if (isAirborne) states.add('AIRBORNE');
    if (isJumping) states.add('JUMPING');
    if (isLanding) states.add('LANDING');
    if (isStunned) states.add('STUNNED');
    if (isDodging) states.add('DODGING');
    if (isAttacking) states.add('ATTACKING');
    if (isBlocking) states.add('BLOCKING');
    if (groundPlatform != null) states.add('GROUNDED');

    // Show animation timers
    if (landingAnimationTimer > 0) states.add('LAND_ANIM:${landingAnimationTimer.toStringAsFixed(2)}');
    if (jumpAnimationTimer > 0) states.add('JUMP_ANIM:${jumpAnimationTimer.toStringAsFixed(2)}');

    // Render state text
    final textPainter = TextPainter(
      text: TextSpan(
        text: states.join('\n'),
        style: const TextStyle(
          color: Colors.yellow,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(-size.x / 2, size.y / 2 + 20));

    // Show velocity
    final velocityText = TextPainter(
      text: TextSpan(
        text: 'VEL: (${velocity.x.toStringAsFixed(0)}, ${velocity.y.toStringAsFixed(0)})',
        style: const TextStyle(
          color: Colors.cyan,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    velocityText.layout();
    velocityText.paint(canvas, Offset(-size.x / 2, size.y / 2 + 80));

    // Show priority
    final priorityText = TextPainter(
      text: TextSpan(
        text: 'PRIORITY: ${priority.toStringAsFixed(0)}',
        style: const TextStyle(
          color: Colors.orange,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    priorityText.layout();
    priorityText.paint(canvas, Offset(-size.x / 2, size.y / 2 + 95));

    // Draw collision box
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
      Paint()
        ..color = Colors.red.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Draw ground detection line
    if (groundPlatform != null) {
      canvas.drawLine(
        Offset(0, size.y / 2),
        Offset(0, size.y / 2 + 10),
        Paint()
          ..color = Colors.green
          ..strokeWidth = 3,
      );
    } else {
      canvas.drawLine(
        Offset(0, size.y / 2),
        Offset(0, size.y / 2 + 10),
        Paint()
          ..color = Colors.red
          ..strokeWidth = 3,
      );
    }
  }
}

/// Add this method to your GameCharacter render() method TEMPORARILY:
///
/// @override
/// void render(Canvas canvas) {
///   super.render(canvas);
///
///   // ... existing render code ...
///
///   // DEBUG: REMOVE AFTER FIXING
///   renderDebugInfo(canvas);
/// }

/// =============================================
/// CONSOLE DEBUG HELPER
/// =============================================
/// Add this to update() to log state changes:

/*void debugLogStateChanges() {
  // Log when landing
  if (!wasGrounded && groundPlatform != null) {
    print('🔵 ${stats.name} LANDED - velocity.y was ${velocity.y.toStringAsFixed(0)}');
  }

  // Log when jumping
  if (wasGrounded && groundPlatform == null && velocity.y < 0) {
    print('🟢 ${stats.name} JUMPED - velocity.y = ${velocity.y.toStringAsFixed(0)}');
  }

  // Log animation changes
  final currentAnim = animation;
  if (currentAnim != _lastAnimation) {
    String animName = 'unknown';
    if (currentAnim == jumpAnimation) animName = 'JUMP';
    if (currentAnim == landingAnimation) animName = 'LANDING';
    if (currentAnim == walkAnimation) animName = 'WALK';
    if (currentAnim == idleAnimation) animName = 'IDLE';
    if (currentAnim == attackAnimation) animName = 'ATTACK';

    print('🎬 ${stats.name} Animation changed to: $animName');
    _lastAnimation = currentAnim;
  }
}*/

// Add this variable to GameCharacter class:
// SpriteAnimation? _lastAnimation;

/// =============================================
/// PRIORITY DEBUG OVERLAY
/// =============================================
/// Add this to ActionGame to show all priorities:

class PriorityDebugOverlay extends PositionComponent with HasGameReference<ActionGame> {
  @override
  void render(Canvas canvas) {
    final components = game.world.children.toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    double y = 100;
    for (final comp in components) {
      final name = comp.runtimeType.toString();
      final priority = comp.priority;

      final textPainter = TextPainter(
        text: TextSpan(
          text: '$priority: $name',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            backgroundColor: Colors.black,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(10, y));

      y += 15;
      if (y > 400) break; // Don't overflow screen
    }
  }
}

// Add to ActionGame onLoad():
// camera.viewport.add(PriorityDebugOverlay());

/// =============================================
/// STATE MACHINE VISUALIZER
/// =============================================
/// Shows character state as colored circle

class StateVisualizer extends PositionComponent {
  final GameCharacter character;

  StateVisualizer(this.character) {
    position = character.position;
  }

  @override
  void update(double dt) {
    super.update(dt);
    position = character.position + Vector2(0, -100);
  }

  @override
  void render(Canvas canvas) {
    Color stateColor = Colors.grey;

    if (character.isStunned) {
      stateColor = Colors.yellow;
    } else if (character.landingAnimationTimer > 0) {
      stateColor = Colors.orange;
    } else if (character.isDodging) {
      stateColor = Colors.blue;
    } else if (character.isAttacking) {
      stateColor = Colors.red;
    } else if (character.isAirborne || character.jumpAnimationTimer > 0) {
      stateColor = Colors.purple;
    } else if (character.velocity.x.abs() > 10) {
      stateColor = Colors.green;
    }

    canvas.drawCircle(
      Offset.zero,
      15,
      Paint()..color = stateColor.withOpacity(0.7),
    );

    canvas.drawCircle(
      Offset.zero,
      15,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}

// Add to player in ActionGame:
// camera.viewport.add(StateVisualizer(player));

/// =============================================
/// USAGE INSTRUCTIONS
/// =============================================
///
/// 1. Add renderDebugInfo() call to render() method
/// 2. Add debugLogStateChanges() call to update() method
/// 3. Add PriorityDebugOverlay to camera viewport
/// 4. Add StateVisualizer for player
///
/// Look for:
/// - Red "AIRBORNE" when jumping
/// - Green "GROUNDED" when on platform
/// - "LANDING" appears briefly when landing
/// - "LAND_ANIM" timer counts down
/// - "JUMP_ANIM" timer counts down
/// - Velocity Y goes negative when jumping
/// - Velocity Y goes positive when falling
/// - Animation changes logged in console
/// - Priority values shown on screen
///
/// Common issues visible with debug:
/// - AIRBORNE and GROUNDED both true = timing issue
/// - JUMP_ANIM = 0 but still in air = animation ended too soon
/// - LANDING never appears = landing detection broken
/// - Priority all same number = priorities not set
/// - Animation flickers between JUMP and IDLE = state conflict