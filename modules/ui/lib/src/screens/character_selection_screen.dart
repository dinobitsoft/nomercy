import 'dart:async';

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
  State<CharacterSelectionScreen> createState() =>
      _CharacterSelectionScreenState();
}

class _CharacterSelectionScreenState extends State<CharacterSelectionScreen> {
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

  // ── Gamepad state ─────────────────────────────────────────────────────────
  // Two focus zones: 'menu' (left) or 'characters' (right)
  bool _inCharacterZone = false;

  // Index of focused menu item (0=SINGLE PLAYER, 1=MULTIPLAYER, 2=UPGRADE)
  int _menuFocus = 0;

  // Index of focused menu item (0=SINGLE PLAYER, 1=MULTIPLAYER, 2=UPGRADE)
  static const int _menuCount = 3;

  StreamSubscription<GamepadNavEvent>? _navSub;

  @override
  void initState() {
    super.initState();
    GamepadManager().checkConnection();

    _pageController = PageController(viewportFraction: 0.5, initialPage: 0);
    selectedCharacterClass = characterOptions[0].name.toLowerCase();

    _navSub = GamepadNavService().events.listen(_onNav);
  }

  @override
  void dispose() {
    _navSub?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _onNav(GamepadNavEvent event) {
    if (_inCharacterZone) {
      _onNavCharZone(event);
    } else {
      _onNavMenuZone(event);
    }
  }

  // ── Menu zone: up/down navigate, RIGHT enters char zone, A/confirm selects ──
  void _onNavMenuZone(GamepadNavEvent event) {
    switch (event) {
      case GamepadNavEvent.up:
        setState(() => _menuFocus = (_menuFocus - 1 + _menuCount) % _menuCount);
      case GamepadNavEvent.down:
        setState(() => _menuFocus = (_menuFocus + 1) % _menuCount);
      case GamepadNavEvent.right:
      // Enter char zone — highlight current carousel page
        setState(() => _inCharacterZone = true);
      case GamepadNavEvent.confirm:
        _activateMenuItem(_menuFocus);
      case GamepadNavEvent.back:
        Navigator.maybePop(context);
      case GamepadNavEvent.start:
        _startSinglePlayer(context);
      default:
        break;
    }
  }

  // ── Char zone: left/right scroll carousel, A confirms, B goes back to menu ─
  void _onNavCharZone(GamepadNavEvent event) {
    switch (event) {
      case GamepadNavEvent.left:
        _scrollCarousel(-1);
      case GamepadNavEvent.right:
        _scrollCarousel(1);
      case GamepadNavEvent.confirm:
        // Confirm character → exit char zone, return to menu
        setState(() {
          selectedCharacterClass = characterOptions[_currentPage].name
              .toLowerCase();
          _inCharacterZone = false;
        });
      case GamepadNavEvent.back:
        setState(() => _inCharacterZone = false);
      default:
        break;
    }
  }

  void _scrollCarousel(int delta) {
    final next = (_currentPage + delta).clamp(0, characterOptions.length - 1);
    if (next == _currentPage) return;
    setState(() {
      _currentPage = next;
      selectedCharacterClass = characterOptions[next].name.toLowerCase();
    });
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _activateMenuItem(int index) {
    switch (index) {
      case 0:
        _startSinglePlayer(context);
      case 1:
        _startMultiplayer(context);
      case 2:
        _openSettings(context);
    }
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
                            index: 0,
                            icon: FontAwesomeIcons.user,
                            label: 'SINGLE PLAYER',
                            color: Colors.blueAccent,
                            onTap: () => _startSinglePlayer(context),
                          ),
                          const SizedBox(height: 15),
                          _buildMenuItem(
                            index: 1,
                            icon: FontAwesomeIcons.users,
                            label: 'MULTIPLAYER',
                            color: Colors.orangeAccent,
                            onTap: () => _startMultiplayer(context),
                          ),
                          const SizedBox(height: 15),
                          _buildMenuItem(
                            index: 2,
                            icon: FontAwesomeIcons.gear,
                            label: 'SETTINGS',
                            color: Colors.grey[400]!,
                            onTap: () => _openSettings(context),
                          ),
                          const SizedBox(height: 15),
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
                          selectedCharacterClass = characterOptions[index].name
                              .toLowerCase();
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
                          child: _buildCharacterCard(
                            charClass,
                            stats,
                            index == _currentPage,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              // Settings / Language Toggle
              Positioned(top: 20, left: 20, child: _buildLanguageToggle()),

              // Gamepad Connection Indicator
              Positioned(
                top: 20,
                right: 20,
                child: ValueListenableBuilder<bool>(
                  valueListenable: GamepadManager().connected,
                  builder: (context, isConnected, child) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
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
    required int index,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final focused = !_inCharacterZone && _menuFocus == index;
    return GamepadMenuItem(
      focused: focused,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _inCharacterZone = false;
              _menuFocus = index;
            });
            onTap();
          },
          borderRadius: BorderRadius.circular(12),
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

  void _confirmCharacter(int index) {
    setState(() {
      _currentPage = index;
      selectedCharacterClass = characterOptions[index].name.toLowerCase();
    });
    _startSinglePlayer(context);
  }

  Widget _buildCharacterCard(
    String charClass,
    CharacterStats stats,
    bool isSelected,
  ) {
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
                ),
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
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.person, color: Colors.white, size: 100),
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
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
            ),
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
            position:
                Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
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
