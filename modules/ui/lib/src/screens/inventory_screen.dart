import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flutter/material.dart';


class InventoryScreen extends StatefulWidget {
  final List<Item> inventory;
  final Weapon? equippedWeapon;
  final CharacterStats playerStats;
  final Function(Weapon?) onEquipWeapon;
  final Function(Item) onSellItem;
  final Function(Weapon) onBuyWeapon;

  const InventoryScreen({
    super.key,
    required this.inventory,
    required this.equippedWeapon,
    required this.playerStats,
    required this.onEquipWeapon,
    required this.onSellItem,
    required this.onBuyWeapon,
  });

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  int selectedTab = 0; // 0: Inventory, 1: Shop

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.8),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Tab selector
            _buildTabSelector(),

            // Content
            Expanded(
              child: selectedTab == 0
                  ? _buildInventoryTab()
                  : _buildShopTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 32),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'INVENTORY & SHOP',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(Icons.monetization_on, color: Colors.yellow, size: 20),
                  const SizedBox(width: 5),
                  Text(
                    '${widget.playerStats.money} Gold',
                    style: const TextStyle(
                      color: Colors.yellow,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildTab('INVENTORY', 0, Icons.backpack),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildTab('SHOP', 1, Icons.store),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index, IconData icon) {
    final isSelected = selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[800],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[600]!,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryTab() {
    final weapons = widget.inventory.whereType<Weapon>().toList();
    final potions = widget.inventory.whereType<HealthPotion>().toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Equipped weapon section
          _buildEquippedWeaponSection(),

          const SizedBox(height: 30),

          // Weapons in inventory
          const Text(
            'WEAPONS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          if (weapons.isEmpty)
            _buildEmptyMessage('No weapons in inventory')
          else
            ...weapons.map((weapon) => _buildInventoryWeaponCard(weapon)),

          const SizedBox(height: 30),

          // Potions
          const Text(
            'CONSUMABLES',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          if (potions.isEmpty)
            _buildEmptyMessage('No potions in inventory')
          else
            ...potions.map((potion) => _buildPotionCard(potion)),
        ],
      ),
    );
  }

  Widget _buildEquippedWeaponSection() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blue, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EQUIPPED WEAPON',
            style: TextStyle(
              color: Colors.blue,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          if (widget.equippedWeapon == null)
            const Text(
              'No weapon equipped',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            )
          else
            _buildWeaponStats(widget.equippedWeapon!, isEquipped: true),
        ],
      ),
    );
  }

  Widget _buildInventoryWeaponCard(Weapon weapon) {
    final isEquipped = widget.equippedWeapon?.id == weapon.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isEquipped ? Colors.blue : Colors.grey[700]!,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildWeaponStats(weapon)),
              Column(
                children: [
                  if (!isEquipped)
                    ElevatedButton.icon(
                      onPressed: () {
                        widget.onEquipWeapon(weapon);
                        setState(() {});
                      },
                      icon: const Icon(Icons.swap_horiz, size: 16),
                      label: const Text('EQUIP'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      _showSellConfirmation(weapon);
                    },
                    icon: const Icon(Icons.sell, size: 16),
                    label: Text('${weapon.value ~/ 2}g'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeaponStats(Weapon weapon, {bool isEquipped = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          weapon.name,
          style: TextStyle(
            color: isEquipped ? Colors.blue : Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          weapon.description,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 15,
          runSpacing: 5,
          children: [
            _buildStatChip('⚔️ ${weapon.damage.toInt()}', Colors.red),
            _buildStatChip('📏 ${weapon.range.toInt()}', Colors.blue),
            if (weapon.powerBonus > 0)
              _buildStatChip('💪 +${weapon.powerBonus.toInt()}', Colors.orange),
            if (weapon.magicBonus > 0)
              _buildStatChip('✨ +${weapon.magicBonus.toInt()}', Colors.purple),
            if (weapon.dexterityBonus > 0)
              _buildStatChip('🏃 +${weapon.dexterityBonus.toInt()}', Colors.green),
            if (weapon.intelligenceBonus > 0)
              _buildStatChip('🧠 +${weapon.intelligenceBonus.toInt()}', Colors.cyan),
          ],
        ),
      ],
    );
  }

  Widget _buildStatChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPotionCard(HealthPotion potion) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green, width: 2),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_drink, color: Colors.green, size: 40),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  potion.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Heals ${potion.healAmount.toInt()} HP',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              _showSellConfirmation(potion);
            },
            icon: const Icon(Icons.sell, size: 16),
            label: Text('${potion.value ~/ 2}g'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopTab() {
    final availableWeapons = Weapon.getAllWeapons();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WEAPONS FOR SALE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),

          ...availableWeapons.map((weapon) => _buildShopWeaponCard(weapon)),
        ],
      ),
    );
  }

  Widget _buildShopWeaponCard(Weapon weapon) {
    final canAfford = widget.playerStats.money >= weapon.value;
    final alreadyOwned = widget.inventory.any((item) => item.id == weapon.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: canAfford ? Colors.green : Colors.grey[700]!,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildWeaponStats(weapon)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.yellow.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.yellow, width: 2),
                    ),
                    child: Text(
                      '${weapon.value} Gold',
                      style: const TextStyle(
                        color: Colors.yellow,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: alreadyOwned || !canAfford
                        ? null
                        : () {
                      widget.onBuyWeapon(weapon);
                      setState(() {});
                    },
                    icon: Icon(
                      alreadyOwned ? Icons.check : Icons.shopping_cart,
                      size: 16,
                    ),
                    label: Text(alreadyOwned ? 'OWNED' : 'BUY'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: alreadyOwned
                          ? Colors.grey
                          : (canAfford ? Colors.green : Colors.grey),
                      disabledBackgroundColor: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (!canAfford && !alreadyOwned)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Need ${weapon.value - widget.playerStats.money} more gold',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyMessage(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  void _showSellConfirmation(Item item) {
    final sellPrice = item.value ~/ 2;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Sell Item?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Sell ${item.name} for $sellPrice gold?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.onSellItem(item);
              Navigator.pop(context);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Sell'),
          ),
        ],
      ),
    );
  }
}