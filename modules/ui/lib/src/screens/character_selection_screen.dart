import 'package:engine/engine.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gamepad/gamepad.dart';
import 'package:ui/ui.dart';

import 'game_screen.dart';

class CharacterSelectionScreen extends StatefulWidget {
  const CharacterSelectionScreen({super.key});

  @override
  State<CharacterSelectionScreen> createState() => _CharacterSelectionScreenState();
}

// Focus zones: 0-2 = main menu items, 3-6 = character cards
const int _kMenuItems = 3; // SINGLE PLAYER, MULTIPLAYER, UPGRADE

class _CharacterSelectionScreenState extends State<CharacterSelectionScreen>
    with GamepadMenuController {

  String? selectedCharacterClass;
  late PageController _pageController;
  int _currentPage = 0;

  final List<CharacterStats> characterOptions = [
    KnightStats(),
    ThiefStats(),
    WizardStats(),
    TraderStats(),
  ];

  // Two focus zones: 'menu' (left) or 'chars' (right)
  bool _inCharZone = false;

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

  void _rebuildItems() {
    if (_inCharZone) {
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
        GamepadItem(onSelect: () => _showUpgradeSnack()),
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

  @override
  void onStart() => _startSinglePlayer(context);

  @override
  void onBack() {
    if (_inCharZone) {
      setState(() { _inCharZone = false; });
      _rebuildItems();
    } else {
      super.onBack();
    }
  }

  // Override navigation to switch zones on left/right
  // We override _onNav indirectly via registerItems; switching zones on right arrow
  // when in menu zone is handled by listening to the service directly.

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showUpgradeSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Upgrade screen coming soon!')),
    );
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
              Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        // ── Left: Main Menu ─────────────────────────────────────
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
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
                                  focused: !_inCharZone && isFocused(0),
                                  icon: FontAwesomeIcons.user,
                                  label: 'SINGLE PLAYER',
                                  color: Colors.blueAccent,
                                  onTap: () => _startSinglePlayer(context),
                                ),
                                const SizedBox(height: 15),
                                _buildMenuItem(
                                  focused: !_inCharZone && isFocused(1),
                                  icon: FontAwesomeIcons.users,
                                  label: 'MULTIPLAYER',
                                  color: Colors.orangeAccent,
                                  onTap: () => _startMultiplayer(context),
                                ),
                                const SizedBox(height: 15),
                                _buildMenuItem(
                                  focused: !_inCharZone && isFocused(2),
                                  icon: FontAwesomeIcons.arrowUp,
                                  label: 'UPGRADE',
                                  color: Colors.greenAccent,
                                  onTap: _showUpgradeSnack,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // ── Right: Character Carousel ────────────────────────────
                        Expanded(
                          flex: 3,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: PageView.builder(
                                  controller: _pageController,
                                  itemCount: characterOptions.length,
                                  onPageChanged: (index) {
                                    setState(() {
                                      _currentPage = index;
                                      selectedCharacterClass =
                                          characterOptions[index].name.toLowerCase();
                                      if (_inCharZone) {
                                        // sync focus index when swiped
                                        registerItems([
                                          for (int i = 0; i < characterOptions.length; i++)
                                            GamepadItem(
                                              onSelect: () => _confirmCharacter(i),
                                              column: i,
                                              row: 0,
                                            ),
                                        ], columns: characterOptions.length);
                                        // can't call setState inside setState; handled by registerItems
                                      }
                                    });
                                  },
                                  itemBuilder: (context, index) {
                                    final charClass = characterOptions[index].name.toLowerCase();
                                    final stats = characterOptions[index];
                                    final isActive = index == _currentPage;

                                    final baseCard = _buildCharacterCard(charClass, stats, isActive);

                                    final wrappedCard = _inCharZone
                                        ? GamepadMenuItem(
                                      focused: isFocused(index),
                                      onTap: () => _confirmCharacter(index),
                                      borderRadius: BorderRadius.circular(20),
                                      child: baseCard,
                                    )
                                        : baseCard;

                                    return GestureDetector(
                                      onTap: () {
                                        if (_inCharZone) {
                                          _confirmCharacter(index);
                                        } else {
                                          setState(() {
                                            _currentPage = index;
                                            selectedCharacterClass = charClass;
                                          });
                                        }
                                      },
                                      child: PageViewBuildHelper(
                                        pageController: _pageController,
                                        index: index,
                                        child: wrappedCard,
                                      ),
                                    );
                                  },
                                ),
                              ),

                              // Zone switch hint
                              if (_inCharZone)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    'A = Confirm Character   B = Back to Menu',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const GamepadHintBar(confirmLabel: 'Select', backLabel: 'Back'),
                ],
              ),

              // Settings / Language Toggle
              Positioned(
                top: 20,
                left: 20,
                child: _buildLanguageToggle(),
              ),

              // Gamepad Indicator
              Positioned(
                top: 20,
                right: 20,
                child: ValueListenableBuilder<bool>(
                  valueListenable: GamepadManager().connected,
                  builder: (context, isConnected, _) {
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
                          Icon(Icons.videogame_asset_outlined,
                              color: isConnected ? Colors.green : Colors.grey, size: 20),
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
    required bool focused,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GamepadMenuItem(
      focused: focused,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              if (_inCharZone) { _inCharZone = false; _rebuildItems(); }
              // update focus to tapped item
              registerItems([
                GamepadItem(onSelect: () => _startSinglePlayer(context)),
                GamepadItem(onSelect: () => _startMultiplayer(context)),
                GamepadItem(onSelect: _showUpgradeSnack),
              ]);
            });
            onTap();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: focused
                  ? color.withOpacity(0.25)
                  : Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.5), width: 1),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 15),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCharacterCard(String charClass, CharacterStats stats, bool isActive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isActive
              ? [Colors.blue[800]!, Colors.blue[600]!]
              : [Colors.grey[800]!, Colors.grey[700]!],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? Colors.blue[300]! : Colors.grey[600]!,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person, size: 80, color: isActive ? Colors.white : Colors.grey[400]),
          const SizedBox(height: 15),
          Text(
            stats.name.toUpperCase(),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Weapon: ${stats.weaponName}',
            style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7)),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statCol('PWR', stats.power),
                _statCol('MAG', stats.magic),
                _statCol('DEX', stats.dexterity),
                _statCol('INT', stats.intelligence),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCol(String label, double value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
        const SizedBox(height: 4),
        Text(value.toInt().toString(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }

  Widget _buildLanguageToggle() {
    return AnimatedBuilder(
      animation: LocalizationManager(),
      builder: (context, _) {
        final locale = LocalizationManager().locale;
        return PopupMenuButton<Locale>(
          initialValue: locale,
          onSelected: (l) => LocalizationManager().setLocale(l),
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
                Text(locale.languageCode.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          itemBuilder: (_) => [
            const PopupMenuItem(value: Locale('en'), child: Text('English')),
            const PopupMenuItem(value: Locale('tr'), child: Text('Türkçe')),
          ],
        );
      },
    );
  }

  void _startSinglePlayer(BuildContext context) {
    if (selectedCharacterClass == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ModeSelectionScreen(selectedCharacterClass: selectedCharacterClass!),
    ));
  }

  void _startMultiplayer(BuildContext context) async {
    final result = await Navigator.push(context, MaterialPageRoute(
      builder: (_) => MultiplayerLobbyScreen(selectedCharacterClass: selectedCharacterClass!),
    ));
    if (result != null && mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => GameScreen(
          selectedCharacterClass: selectedCharacterClass!,
          enableMultiplayer: true,
          roomId: result['room_id'],
        ),
      ));
    }
  }
}

// Helper to apply PageView scale transform
class PageViewBuildHelper extends StatelessWidget {
  final PageController pageController;
  final int index;
  final Widget child;
  const PageViewBuildHelper({super.key, required this.pageController, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pageController,
      builder: (_, __) {
        double value = 1.0;
        if (pageController.position.haveDimensions) {
          value = pageController.page! - index;
          value = (1 - (value.abs() * 0.3)).clamp(0.7, 1.0);
        } else {
          value = index == 0 ? 1.0 : 0.7;
        }
        return Center(
          child: SizedBox(height: 450 * value, width: 350 * value, child: child),
        );
      },
    );
  }
}