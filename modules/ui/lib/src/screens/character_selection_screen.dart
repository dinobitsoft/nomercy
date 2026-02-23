import 'package:engine/engine.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gamepad/gamepad.dart';
import 'package:service/service.dart';
import 'package:ui/ui.dart';

import 'game_screen.dart';
import 'settings_screen.dart';

class CharacterSelectionScreen extends StatefulWidget {
  const CharacterSelectionScreen({super.key});

  @override
  State<CharacterSelectionScreen> createState() => _CharacterSelectionScreenState();
}

class _CharacterSelectionScreenState extends State<CharacterSelectionScreen>
    with GamepadMenuController<CharacterSelectionScreen> {
  String? selectedCharacterClass;
  late PageController _pageController;
  int _currentPage = 0;

  static const int _kMenuItems = 3;

  final AudioSystem _audioSystem = AudioSystem();

  final List<CharacterStats> characterOptions = [
    KnightStats(),
    ThiefStats(),
    WizardStats(),
    TraderStats(),
  ];

  // Two focus zones: 'menu' (left) or 'characters' (right)
  bool _inCharacterZone = false;

  @override
  void initState() {
    super.initState();
    GamepadManager().checkConnection();

    _pageController = PageController(
      viewportFraction: 0.5,
      initialPage: 0,
    );

    selectedCharacterClass = characterOptions[0].name.toLowerCase();
    _rebuildItems();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _audioSystem.dispose();
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
                              fontSize: 24,
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
                            focused: !_inCharacterZone && isFocused(0),
                          ),
                          const SizedBox(height: 15),
                          _buildMenuItem(
                            icon: FontAwesomeIcons.users,
                            label: 'MULTIPLAYER',
                            color: Colors.orangeAccent,
                            onTap: () => _startMultiplayer(context),
                            focused: !_inCharacterZone && isFocused(1),
                          ),
                          const SizedBox(height: 15),
                          _buildMenuItem(
                            icon: FontAwesomeIcons.gear,
                            label: 'SETTINGS',
                            color: Colors.grey[400]!,
                            onTap: () => _openSettings(context),
                            focused: !_inCharacterZone && isFocused(2),
                          ),
                          const SizedBox(height: 15),
                          _buildMenuItem(
                            icon: FontAwesomeIcons.arrowUp,
                            label: 'UPGRADE',
                            color: Colors.greenAccent,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Upgrade screen coming soon!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            focused: !_inCharacterZone && isFocused(3),
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

              // Settings / Language Toggle
              Positioned(
                top: 20,
                left: 20,
                child: _buildLanguageToggle(),
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

  Widget _buildLanguageToggle() {
    return AnimatedBuilder(
      animation: LocalizationManager(),
      builder: (context, child) {
        final currentLocale = LocalizationManager().locale;
        return PopupMenuButton<Locale>(
          initialValue: currentLocale,
          onSelected: (Locale locale) {
            LocalizationManager().setLocale(locale);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.language, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  currentLocale.languageCode.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          itemBuilder: (BuildContext context) => <PopupMenuEntry<Locale>>[
            const PopupMenuItem<Locale>(
              value: Locale('en'),
              child: Text('English'),
            ),
            const PopupMenuItem<Locale>(
              value: Locale('tr'),
              child: Text('Türkçe'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool focused,
  }) {
    return GamepadMenuItem(
      focused: focused,
      child:     Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              if (_inCharacterZone) { _inCharacterZone = false; _rebuildItems(); }
              // update focus to tapped item
              registerItems([
                GamepadItem(onSelect: () => _startSinglePlayer(context)),
                GamepadItem(onSelect: () => _startMultiplayer(context)),
                GamepadItem(onSelect: () => _openSettings(context)),
              ]);
            });
            onTap();
          },
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(15),
              color: focused
                  ? color.withOpacity(0.25)
                  : Colors.black.withOpacity(0.3),
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
      ),
    );
  }

  void _rebuildItems() {
    if (_inCharacterZone) {
      // Character carousel: left/right cycle through chars
      registerItems([
        for (int i = 0; i < characterOptions.length; i++)
          GamepadItem(
            onSelect: () => _confirmCharacter(i),
            column: i,
            row: 0,
          ),
      ], columns: characterOptions.length);
    } else {
      // Main menu
      registerItems([
        GamepadItem(onSelect: () => _startSinglePlayer(context)),
        GamepadItem(onSelect: () => _startMultiplayer(context)),
        GamepadItem(onSelect: () => _openSettings(context)),
      ]);
    }
  }

  void _confirmCharacter(int index) {
    setState(() {
      _currentPage = index;
      selectedCharacterClass = characterOptions[index].name.toLowerCase();
    });
    _startSinglePlayer(context);
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
            context.translate(stats.name.toLowerCase()).toUpperCase(),
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

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            SettingsScreen(audioSystem: _audioSystem),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

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

  void _startMultiplayer(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiplayerLobbyScreen(
          selectedCharacterClass: selectedCharacterClass!,
        ),
      ),
    );

    if (result != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GameScreen(
            selectedCharacterClass: selectedCharacterClass!,
            enableMultiplayer: true,
            roomId: result['room_id'],
          ),
        ),
      );
    }
  }
}