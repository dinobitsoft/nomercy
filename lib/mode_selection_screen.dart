import 'package:flutter/material.dart';
import 'package:nomercy/managers/localization_manager.dart';

import 'game_mode.dart';
import 'map/map_selection_screen.dart';

class ModeSelectionScreen extends StatelessWidget {
  final String selectedCharacterClass;

  const ModeSelectionScreen({
    super.key,
    required this.selectedCharacterClass,
  });

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
          child: Column(
            children: [
              // Header - Reduced padding
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 28, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 20),
                    Text(
                      context.translate('select_mode'),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Mode Cards - Optimized for landscape
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 2.8, // Shorter cards for landscape
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildModeCard(
                      context,
                      context.translate('survival'),
                      context.translate('survival_desc'),
                      Icons.shield,
                      Colors.orange,
                      GameMode.survival,
                    ),
                    _buildModeCard(
                      context,
                      context.translate('campaign'),
                      context.translate('campaign_desc'),
                      Icons.book,
                      Colors.blue,
                      GameMode.campaign,
                    ),
                    _buildModeCard(
                      context,
                      context.translate('boss_fight'),
                      context.translate('boss_fight_desc'),
                      Icons.dangerous,
                      Colors.red,
                      GameMode.bossFight,
                    ),
                    _buildModeCard(
                      context,
                      context.translate('training'),
                      context.translate('training_desc'),
                      Icons.fitness_center,
                      Colors.green,
                      GameMode.training,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard(
      BuildContext context,
      String title,
      String description,
      IconData icon,
      Color color,
      GameMode mode,
      ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MapSelectionScreen(
              selectedCharacterClass: selectedCharacterClass,
              gameMode: mode,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.8),
              color.withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white30, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row( // Using Row instead of Column to save vertical space
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 15),
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}
