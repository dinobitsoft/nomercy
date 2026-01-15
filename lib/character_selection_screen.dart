import 'package:flutter/material.dart';

import 'character_stats.dart';
import 'game/stat/stats.dart';
import 'gamepad_manager.dart';
import 'level_selection_screen.dart';

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
    // Initial check for already connected gamepads
    GamepadManager().checkConnection();
    
    _pageController = PageController(
      viewportFraction: 0.5,
      initialPage: 0,
    );
    
    // Set initial selection
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
                  // Left side - Title and info
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Choose Your\nCharacter',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (selectedCharacterClass != null) 
                            ElevatedButton(
                              onPressed: () => _startGame(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 30,
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'START GAME',
                                    style: TextStyle(fontSize: 24, color: Colors.white),
                                  ),
                                ],
                              ),
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
                        
                        // Calculate scale for carousel effect
                        return AnimatedBuilder(
                          animation: _pageController,
                          builder: (context, child) {
                            double value = 1.0;
                            if (_pageController.position.haveDimensions) {
                              value = _pageController.page! - index;
                              value = (1 - (value.abs() * 0.3)).clamp(0.7, 1.0);
                            } else {
                              // Initial state before dimensions are available
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

  void _startGame(BuildContext context) {
    if (selectedCharacterClass == null) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LevelSelectionScreen(
          selectedCharacterClass: selectedCharacterClass!,
        ),
      ),
    );
  }
}
