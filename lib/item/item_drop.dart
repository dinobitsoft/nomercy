import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game/action_game.dart';
import '../game/game_character.dart';
import 'item.dart';

class ItemDrop extends PositionComponent with HasGameReference<ActionGame> {
  final Item item;
  bool isPlayerNear = false;
  double glowTimer = 0;
  double floatOffset = 0;
  double bobSpeed = 2.0;

  Sprite? sprite;

  ItemDrop({
    required Vector2 position,
    required this.item,
  }) : super(position: position) {
    size = Vector2(60, 60);
    anchor = Anchor.center;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Try to load item sprite
    try {
      sprite = await game.loadSprite(item.iconAsset);
    } catch (e) {
      // Fallback - will use colored circle
      print('Could not load sprite for ${item.name}: $e');
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    glowTimer += dt;
    floatOffset = math.sin(glowTimer * bobSpeed) * 5;

    // Check if player is near
    final player = game.player;
    final distance = position.distanceTo(player.position);
    isPlayerNear = distance < 80;

    // Auto-pickup if very close
    if (distance < 50) {
      pickup(player);
    }
  }

  void pickup(GameCharacter player) {
    if (item is HealthPotion) {
      final potion = item as HealthPotion;
      player.health = math.min(100, player.health + potion.healAmount);
      _showPickupText('+${potion.healAmount.toInt()} HP', Colors.green);
    } else if (item is Weapon) {
      final weapon = item as Weapon;
      game.addToInventory(item);
      _showPickupText('${weapon.name}', Colors.orange);
    }

    // Remove from game
    removeFromParent();
    // game.itemDrops.remove(this); // TODO: think about this
  }

  void _showPickupText(String text, Color color) {
    // You can reuse RewardText component
    final textComponent = TextComponent(
      text: text,
      position: position.clone(),
      textRenderer: TextPaint(
        style: TextStyle(
          color: color,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(color: Colors.black, blurRadius: 4),
          ],
        ),
      ),
    );
    game.add(textComponent);
  }

  @override
  void render(Canvas canvas) {
    canvas.save();

    // Float effect
    canvas.translate(0, floatOffset);

    // Glow effect
    if (isPlayerNear) {
      final glowColor = item is HealthPotion
          ? Colors.green
          : Colors.orange;

      final glowPaint = Paint()
        ..color = glowColor.withOpacity(0.3 + math.sin(glowTimer * 5) * 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
      canvas.drawCircle(Offset.zero, 40, glowPaint);
    }

    // Item background circle
    final bgColor = item is HealthPotion
        ? Colors.green.withOpacity(0.8)
        : Colors.orange.withOpacity(0.8);

    canvas.drawCircle(
      Offset.zero,
      30,
      Paint()..color = bgColor,
    );

    // Item sprite or icon
    if (sprite != null) {
      sprite!.render(
        canvas,
        position: Vector2(-size.x / 2, -size.y / 2),
        size: size,
      );
    } else {
      // Fallback rendering
      _renderFallbackIcon(canvas);
    }

    // Border
    canvas.drawCircle(
      Offset.zero,
      30,
      Paint()
        ..color = Colors.white.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Pickup hint
    if (isPlayerNear) {
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'E to Pick Up',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 4),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
          canvas,
          Offset(-textPainter.width / 2, -size.y / 2 - 15)
      );
    }

    canvas.restore();
  }

  void _renderFallbackIcon(Canvas canvas) {
    if (item is HealthPotion) {
      // Draw + symbol
      final paint = Paint()
        ..color = Colors.white
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        const Offset(-10, 0),
        const Offset(10, 0),
        paint,
      );
      canvas.drawLine(
        const Offset(0, -10),
        const Offset(0, 10),
        paint,
      );
    } else if (item is Weapon) {
      // Draw sword icon
      final paint = Paint()..color = Colors.white;

      // Blade
      final bladePath = Path()
        ..moveTo(0, -15)
        ..lineTo(-3, 10)
        ..lineTo(3, 10)
        ..close();
      canvas.drawPath(bladePath, paint);

      // Handle
      canvas.drawRect(
        const Rect.fromLTWH(-4, 10, 8, 6),
        Paint()..color = Colors.brown,
      );
    }
  }
}