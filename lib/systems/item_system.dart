import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';

import '../core/event_bus.dart';
import '../core/game_event.dart';
import '../item/item.dart';
import '../item/item_drop.dart';
import '../game/action_game.dart';
import '../game/game_character.dart';

/// Item management system - handles drops, pickups, inventory
class ItemSystem {
  final EventBus _eventBus = EventBus();
  final ActionGame game;
  final math.Random _random = math.Random();

  // Active item drops in world
  final List<ItemDrop> _activeDrops = [];

  // Drop statistics
  int _totalDrops = 0;
  int _totalPickups = 0;
  final Map<String, int> _itemsDropped = {};
  final Map<ItemType, int> _itemsPickedUp = {};

  // Subscriptions
  final List<EventSubscription> _subscriptions = [];

  ItemSystem({required this.game}) {
    _setupEventListeners();
  }

  void _setupEventListeners() {
    // Listen for character deaths (drop loot)
    _subscriptions.add(
      _eventBus.on<CharacterKilledEvent>(
        _onCharacterKilled,
        priority: ListenerPriority.high,
      ),
    );

    // Listen for item dropped events
    _subscriptions.add(
      _eventBus.on<ItemDroppedEvent>(
        _onItemDropped,
        priority: ListenerPriority.normal,
      ),
    );

    // Listen for item pickup events
    _subscriptions.add(
      _eventBus.on<ItemPickedUpEvent>(
        _onItemPickedUp,
        priority: ListenerPriority.normal,
      ),
    );

    // Listen for weapon equipped
    _subscriptions.add(
      _eventBus.on<WeaponEquippedEvent>(
        _onWeaponEquipped,
        priority: ListenerPriority.normal,
      ),
    );

    // Listen for chest opened
    _subscriptions.add(
      _eventBus.on<ChestOpenedEvent>(
        _onChestOpened,
        priority: ListenerPriority.normal,
      ),
    );

    print('✅ ItemSystem: Event listeners registered');
  }

  // ==========================================
  // EVENT HANDLERS
  // ==========================================

  void _onCharacterKilled(CharacterKilledEvent event) {
    // Don't drop loot for player death
    if (event.victimId == game.player.stats.name) return;

    // Drop loot if enabled
    if (event.shouldDropLoot) {
      dropLoot(event.deathPosition);
    }
  }

  void _onItemDropped(ItemDroppedEvent event) {
    // Create item drop in world
    final item = _createItemFromType(event.itemType);
    if (item == null) return;

    final itemDrop = ItemDrop(
      position: event.dropPosition,
      item: item,
    );

    // FIX: Set proper priority and add to world
    itemDrop.priority = 50; // Between platforms and characters
    game.add(itemDrop);
    game.world.add(itemDrop);
    game.itemDrops.add(itemDrop); // Add to tracking list

    _totalDrops++;
    _itemsDropped[event.itemType] = (_itemsDropped[event.itemType] ?? 0) + 1;

    print('📦 Item dropped: ${event.itemType} at ${event.dropPosition}');
  }

  void _onItemPickedUp(ItemPickedUpEvent event) {
    // Find and remove item drop
    ItemDrop? dropToRemove;

    for (final drop in game.itemDrops) {
      if (drop.item.id == event.itemId) {
        dropToRemove = drop;
        break;
      }
    }

    if (dropToRemove != null) {
      game.itemDrops.remove(dropToRemove);
      dropToRemove.removeFromParent();
      // game.world.children.remove(dropToRemove);
      game.world.remove(dropToRemove);
      // Add to inventory
      game.inventory.add(dropToRemove.item);

      // Apply item effect
      _applyItemEffect(event.characterId, dropToRemove.item);

      _totalPickups++;
      _itemsPickedUp[event.itemType] = (_itemsPickedUp[event.itemType] ?? 0) + 1;

      print('✅ ${event.characterId} picked up ${event.itemName}');
    }
  }

  void _onWeaponEquipped(WeaponEquippedEvent event) {
    print('⚔️  ${event.characterId} equipped ${event.weaponName}');
    print('   New damage: ${event.newDamage.toInt()}');
    print('   New range: ${event.newRange.toInt()}');
  }

  void _onChestOpened(ChestOpenedEvent event) {
    print('📦 Chest opened at ${event.position}');

    if (event.reward != null) {
      print('   Reward: ${event.reward}');
    } else {
      print('   Chest was empty!');
    }

    // Play sound
    _eventBus.emit(PlaySFXEvent(soundId: 'chest_open', volume: 0.8));
  }

  // ==========================================
  // LOOT DROPPING
  // ==========================================

  /// Drop loot at position
  void dropLoot(Vector2 position) {
    // Determine what to drop based on probabilities
    final roll = _random.nextDouble();

    if (roll < 0.5) {
      // 50% - Health potion
      final itemId = 'health_potion_${DateTime.now().millisecondsSinceEpoch}';
      _eventBus.emit(ItemDroppedEvent(
        itemId: itemId,
        itemType: 'healthPotion',
        dropPosition: position.clone(),
      ));
    } else if (roll < 0.75) {
      // 25% - Random weapon
      _dropRandomWeapon(position);
    }
    // 25% - Nothing
  }

  /// Drop random weapon
  void _dropRandomWeapon(Vector2 position) {
    final weapons = Weapon.getAllWeapons();
    final randomWeapon = weapons[_random.nextInt(weapons.length)];

    _eventBus.emit(ItemDroppedEvent(
      itemId: randomWeapon.id,
      itemType: 'weapon',
      dropPosition: position,
    ));
  }

  /// Drop specific item
  void dropItem(Item item, Vector2 position) {
    _eventBus.emit(ItemDroppedEvent(
      itemId: item.id,
      itemType: item.type.toString().split('.').last,
      dropPosition: position,
    ));
  }

  // ==========================================
  // ITEM EFFECTS
  // ==========================================

  /// Apply item effect to character
  void _applyItemEffect(String characterId, Item item) {
    final character = _findCharacter(characterId);
    if (character == null) return;

    if (item is HealthPotion) {
      _applyHealthPotion(character, item);
    } else if (item is Weapon) {
      // Weapon equipped via separate event
      print('Weapon added to inventory: ${item.name}');
    }
  }

  /// Apply health potion effect
  void _applyHealthPotion(GameCharacter character, HealthPotion potion) {
    final oldHealth = character.health;
    character.health = math.min(100, character.health + potion.healAmount);
    final actualHeal = character.health - oldHealth;

    if (actualHeal > 0) {
      // Emit heal event
      _eventBus.emit(CharacterHealedEvent(
        characterId: character.stats.name,
        healAmount: actualHeal,
        newHealth: character.health,
        healSource: 'potion',
      ));

      // Show heal number
      _eventBus.emit(ShowDamageNumberEvent(
        position: character.position.clone(),
        damage: actualHeal,
        color: const Color(0xFF00FF00),
      ));

      print('💚 ${character.stats.name} healed for ${actualHeal.toInt()} HP');
    }

    // Remove potion from inventory
    game.inventory.remove(potion);
  }

  // ==========================================
  // ITEM CREATION
  // ==========================================

  /// Create item from type string
  Item? _createItemFromType(String itemType) {
    switch (itemType.toLowerCase()) {
      case 'healthpotion':
        return HealthPotion();
      case 'weapon':
      // Random weapon
        final weapons = Weapon.getAllWeapons();
        return weapons[_random.nextInt(weapons.length)];
      default:
        return null;
    }
  }

  // ==========================================
  // UTILITIES
  // ==========================================

  /// Find character by ID
  GameCharacter? _findCharacter(String characterId) {
    if (game.player.stats.name == characterId) {
      return game.player;
    }

    return game.enemies.firstWhere(
          (e) => e.stats.name == characterId,
      orElse: () => null as GameCharacter,
    );
  }

  /// Update item system (call every frame)
  void update(double dt) {
    // Check for item pickups by player
    for (final drop in List.from(_activeDrops)) {
      final distance = drop.position.distanceTo(game.player.position);

      if (distance < 60) {
        // Player close enough to pick up
        _eventBus.emit(ItemPickedUpEvent(
          characterId: game.player.stats.name,
          itemId: drop.item.id,
          itemType: drop.item.type,
          itemName: drop.item.name,
        ));
      }
    }
  }

  // ==========================================
  // STATISTICS
  // ==========================================

  /// Get item statistics
  Map<String, dynamic> getStatistics() {
    return {
      'totalDrops': _totalDrops,
      'totalPickups': _totalPickups,
      'activeDrops': _activeDrops.length,
      'itemsDropped': Map.from(_itemsDropped),
      'itemsPickedUp': Map.from(_itemsPickedUp),
    };
  }

  /// Print statistics
  void printStats() {
    final stats = getStatistics();
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📦 ITEM SYSTEM STATISTICS');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('Total Drops: ${stats['totalDrops']}');
    print('Total Pickups: ${stats['totalPickups']}');
    print('Active Drops: ${stats['activeDrops']}');
    print('\nItems Dropped:');
    (stats['itemsDropped'] as Map).forEach((key, value) {
      print('  $key: $value');
    });
    print('\nItems Picked Up:');
    (stats['itemsPickedUp'] as Map).forEach((key, value) {
      print('  $key: $value');
    });
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  }

  // ==========================================
  // CLEANUP
  // ==========================================

  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _activeDrops.clear();

    print('🗑️  ItemSystem: Disposed');
  }
}