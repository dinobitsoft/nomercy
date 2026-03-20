import 'dart:math' as math;

import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class ItemDrop extends PositionComponent with HasGameReference<ActionGame> {
  final Item item;
  bool isPlayerNear = false;
  double glowTimer   = 0;
  double floatOffset = 0;

  Sprite? sprite;

  ItemDrop({required Vector2 position, required this.item}) : super(position: position) {
    size   = Vector2(60, 60);
    anchor = Anchor.center;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try { sprite = await game.loadSprite(item.iconAsset); }
    catch (_) {}
  }

  @override
  void update(double dt) {
    super.update(dt);
    glowTimer   += dt;
    floatOffset  = math.sin(glowTimer * 2) * 5;

    final dist = position.distanceTo(game.character.position);
    isPlayerNear = dist < 80;

    if (dist < 60) _pickup(game.character);
  }

  void _pickup(GameCharacter player) {
    if (item is HealthPotion) {
      final potion = item as HealthPotion;
      if (player.characterState.health >= 100) { _showText('Health Full!', Colors.grey); return; }
      player.characterState.health =
          math.min(100, player.characterState.health + potion.healAmount);
      _showText('+${potion.healAmount.toInt()} HP', Colors.green);
      game.eventBus.emit(ItemPickedUpEvent(
          characterId: player.stats.name, itemId: item.id,
          itemType: item.type, itemName: item.name));
      removeFromParent();
    } else if (item is Weapon) {
      final weapon = item as Weapon;
      // Equip the weapon asynchronously; fire pickup event first.
      game.eventBus.emit(ItemPickedUpEvent(
          characterId: player.stats.name, itemId: item.id,
          itemType: item.type, itemName: item.name));
      player.equipWeapon(weapon);           // async — fine, animation loads in bg
      game.addToInventory(weapon);
      _showText('${weapon.name}', Colors.orange);
      removeFromParent();
    }
  }

  void _showText(String text, Color color) {
    game.add(TextComponent(
      text: text,
      position: position.clone(),
      textRenderer: TextPaint(
        style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold,
            shadows: [const Shadow(color: Colors.black, blurRadius: 4)]),
      ),
    ));
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(0, floatOffset);

    if (isPlayerNear) {
      final glowColor = item is HealthPotion ? Colors.green : Colors.orange;
      canvas.drawCircle(Offset.zero, 40,
          Paint()
            ..color = glowColor.withOpacity(0.3 + math.sin(glowTimer * 5) * 0.2)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));
    }

    if (sprite != null) {
      sprite!.render(canvas, position: Vector2(-size.x/2, -size.y/2), size: size);
    } else {
      _renderFallback(canvas);
    }

    if (isPlayerNear) {
      final tp = TextPainter(
        text: const TextSpan(text: 'Pick Up', style: TextStyle(color: Colors.white,
            fontSize: 12, fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width/2, -size.y/2 - 15));
    }

    canvas.restore();
  }

  void _renderFallback(Canvas canvas) {
    if (item is HealthPotion) {
      final p = Paint()..color=Colors.white..strokeWidth=4..strokeCap=StrokeCap.round;
      canvas.drawLine(const Offset(-10,0), const Offset(10,0), p);
      canvas.drawLine(const Offset(0,-10), const Offset(0,10), p);
    } else if (item is Weapon) {
      final w = item as Weapon;
      canvas.drawCircle(Offset.zero, 20,
          Paint()..color=w.projectileColor.withOpacity(0.7)..style=PaintingStyle.stroke..strokeWidth=3);
      final tp = TextPainter(
        text: TextSpan(text: _weaponEmoji(w), style: const TextStyle(fontSize: 20)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width/2, -tp.height/2));
    }
  }

  String _weaponEmoji(Weapon w) {
    switch (w.weaponType) {
      case WeaponType.sword:    return '⚔️';
      case WeaponType.bow:      return '🏹';
      case WeaponType.staff:    return '🪄';
      case WeaponType.dagger:   return '🗡️';
      case WeaponType.axe:      return '🪓';
      case WeaponType.crossbow: return '🏹';
    }
  }
}