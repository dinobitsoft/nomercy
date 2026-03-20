import 'package:core/core.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';

/// Loads a [SpriteAnimation] from an asset-paths list entry or a sprite sheet.
/// Uses a fixed [stepTime] for every frame.
Future<SpriteAnimation?> loadAnim(
    FlameGame game,
    String charName,
    String animType, {
      required double stepTime,
      required bool loop,
      SpriteAnimation? fallback,
    }) async {
  try {
    final entry = AssetPaths.characterSprites[charName]?[animType];

    if (entry is List<dynamic> && entry.isNotEmpty) {
      final frames = <Sprite>[];
      for (final path in entry) {
        frames.add(Sprite(await game.images.load(path as String)));
      }
      return SpriteAnimation.spriteList(frames, stepTime: stepTime, loop: loop);
    }

    final img = await game.images.load('${charName}_$animType.png');
    if (img.width > img.height * 1.5) {
      final count = (img.width / img.height).round();
      return SpriteAnimation.fromFrameData(
        img,
        SpriteAnimationData.sequenced(
          amount: count,
          stepTime: stepTime,
          textureSize: Vector2(img.height.toDouble(), img.height.toDouble()),
          loop: loop,
        ),
      );
    }

    return SpriteAnimation.spriteList([Sprite(img)], stepTime: stepTime, loop: loop);
  } catch (_) {
    if (fallback != null) return fallback;
    try {
      final img = await game.loadSprite('$charName.png');
      return SpriteAnimation.spriteList([img], stepTime: stepTime, loop: loop);
    } catch (e) {
      throw Exception('No sprite found for $charName/$animType: $e');
    }
  }
}

/// Loads a [SpriteAnimation] where stepTime = [totalDuration] / frameCount.
/// Ties sprite speed directly to the game-mechanic duration.
Future<SpriteAnimation?> loadAnimDynamic(
    FlameGame game,
    String charName,
    String animType, {
      required double totalDuration,
      required bool loop,
      SpriteAnimation? fallback,
    }) async {
  try {
    final frames = await loadFrameSequence(game, charName, animType);
    final stepTime = totalDuration / frames.length;
    return SpriteAnimation.spriteList(frames, stepTime: stepTime, loop: loop);
  } catch (_) {
    return fallback;
  }
}

/// Loads a list of [Sprite] frames from an asset-paths list or numbered files.
Future<List<Sprite>> loadFrameSequence(
    FlameGame game,
    String charName,
    String animType,
    ) async {
  final entry = AssetPaths.characterSprites[charName]?[animType];

  if (entry is List<dynamic>) {
    final sprites = <Sprite>[];
    for (final path in entry) {
      sprites.add(Sprite(await game.images.load(path as String)));
    }
    if (sprites.isNotEmpty) return sprites;
  }

  final sprites = <Sprite>[];
  for (int i = 1; i <= 12; i++) {
    try {
      sprites.add(Sprite(await game.images.load('${charName}_${animType}_$i.png')));
    } catch (_) {
      break;
    }
  }
  if (sprites.isNotEmpty) return sprites;
  throw Exception('No frames found for $charName/$animType');
}