import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'character_stats.dart';
import 'game/stat/stats.dart';
import 'gamepad_manager.dart';
import 'level_selection_screen.dart';
import 'mode_selection_screen.dart';

class CharacterSelectionScreen extends StatefulWidget {
  const CharacterSelectionScreen({super.key});

  @override
  State<CharacterSelectionScreen> createState() => _CharacterSelectionScreenState();
}

class _CharacterSelectionScreenState extends State<CharacterSelectionScreen> {
  String? selectedCharacterClass;
  late PageController _pageController;
  int _currentPage = 0;

  final List<CharacterStats> characterOptions = [
    KnightStats(),
    ThiefStats(),
    WizardStats(),
    TraderStats(),
  ];

  @override
  void initState() {
    super.initState();
    GamepadManager().checkConnection();

    _pageController = PageController(
      viewportFraction: 0.5,
      initialPage: 0,
    );

    selectedCharacterClass = characterOptions[0].name.toLowerCase();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey[900]!, Colors.grey[800]!],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Row(
                children: [
                  // Left side - Main Menu
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NO MERCY',
                            style: TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(height: 40),
                          _buildMenuItem(
                            icon: FontAwesomeIcons.user,
                            label: 'SINGLE PLAYER',
                            color: Colors.blueAccent,
                            onTap: () => _startSinglePlayer(context),
                          ),
                          const SizedBox(height: 15),
                          _buildMenuItem(
                            icon: FontAwesomeIcons.users,
                            label: 'MULTIPLAYER',
                            color: Colors.orangeAccent,
                            onTap: () => _startMultiplayer(context),
                          ),
                          const SizedBox(height: 15),
                          _buildMenuItem(
                            icon: FontAwesomeIcons.arrowUp,
                            label: 'UPGRADE',
                            color: Colors.greenAccent,
                            onTap: () {
                              // TODO: Implement Upgrade Screen
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Upgrade screen coming soon!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Right side - Character Carousel
                  Expanded(
                    flex: 3,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: characterOptions.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                          selectedCharacterClass = characterOptions[index].name.toLowerCase();
                        });
                      },
                      itemBuilder: (context, index) {
                        final stats = characterOptions[index];
                        final charClass = stats.name.toLowerCase();

                        return AnimatedBuilder(
                          animation: _pageController,
                          builder: (context, child) {
                            double value = 1.0;
                            if (_pageController.position.haveDimensions) {
                              value = _pageController.page! - index;
                              value = (1 - (value.abs() * 0.3)).clamp(0.7, 1.0);
                            } else {
                              value = index == 0 ? 1.0 : 0.7;
                            }

                            return Center(
                              child: SizedBox(
                                height: 450 * value,
                                width: 350 * value,
                                child: child,
                              ),
                            );
                          },
                          child: _buildCharacterCard(charClass, stats, index == _currentPage),
                        );
                      },
                    ),
                  ),
                ],
              ),

              // Gamepad Connection Indicator
              Positioned(
                top: 20,
                right: 20,
                child: ValueListenableBuilder<bool>(
                  valueListenable: GamepadManager().connected,
                  builder: (context, isConnected, child) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isConnected ? Colors.green : Colors.grey,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.videogame_asset_outlined,
                            color: isConnected ? Colors.green : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isConnected ? 'GAMEPAD READY' : 'NO GAMEPAD',
                            style: TextStyle(
                              color: isConnected ? Colors.green : Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white24),
            borderRadius: BorderRadius.circular(15),
            color: Colors.white.withOpacity(0.05),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(icon, color: color, size: 20),
              const SizedBox(width: 20),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCharacterCard(String charClass, CharacterStats stats, bool isSelected) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
      decoration: BoxDecoration(
        color: isSelected ? stats.color.withOpacity(0.3) : Colors.grey[800],
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isSelected ? stats.color : Colors.transparent,
          width: 4,
        ),
        boxShadow: isSelected
            ? [
          BoxShadow(
            color: stats.color.withOpacity(0.5),
            blurRadius: 30,
            spreadRadius: 5,
          )
        ]
            : [],
      ),
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              clipBehavior: Clip.none,
              child: Transform.scale(
                scale: 2.2,
                child: Image.asset(
                  'assets/images/$charClass.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: Colors.white, size: 100),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            stats.name.toUpperCase(),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Weapon: ${stats.weaponName}',
            style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7)),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statColumn('PWR', stats.power),
                _statColumn('MAG', stats.magic),
                _statColumn('DEX', stats.dexterity),
                _statColumn('INT', stats.intelligence),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statColumn(String label, double value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[400],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value.toInt().toString(),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // Single Player - Goes to mode selection
  void _startSinglePlayer(BuildContext context) {
    if (selectedCharacterClass == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ModeSelectionScreen(
          selectedCharacterClass: selectedCharacterClass!,
        ),
      ),
    );
  }

  // Multiplayer - Goes to level selection with multiplayer enabled
  void _startMultiplayer(BuildContext context) {
    if (selectedCharacterClass == null) return;

    // Show multiplayer info dialog first
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            Icon(Icons.wifi, color: Colors.orangeAccent),
            const SizedBox(width: 10),
            const Text(
              'Multiplayer Mode',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You\'re about to enter multiplayer mode!',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 15),
            Text(
              '• Fight against real players online\n'
                  '• Server: localhost:3000\n'
                  '• Make sure server is running\n'
                  '• Your character: ${selectedCharacterClass!.toUpperCase()}',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Server must be running at http://10.0.2.2:3000',
                      style: TextStyle(color: Colors.orange[200], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LevelSelectionScreen(
                    selectedCharacterClass: selectedCharacterClass!,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
            ),
            child: const Text('Connect', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}