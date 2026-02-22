import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:service/service.dart';

class SettingsScreen extends StatefulWidget {
  final AudioSystem audioSystem;

  const SettingsScreen({super.key, required this.audioSystem});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  late bool _musicEnabled;
  late bool _sfxEnabled;
  late double _musicVolume;
  late double _sfxVolume;

  @override
  void initState() {
    super.initState();
    _musicEnabled = widget.audioSystem.isMusicEnabled;
    _sfxEnabled = widget.audioSystem.isSFXEnabled;
    _musicVolume = widget.audioSystem.musicVolume;
    _sfxVolume = widget.audioSystem.sfxVolume;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
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
          child: FadeTransition(
            opacity: _fadeIn,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 48),
                  _buildSection(
                    icon: FontAwesomeIcons.music,
                    title: 'MUSIC',
                    color: Colors.purpleAccent,
                    children: [
                      _buildToggleTile(
                        label: 'Battle Theme',
                        subtitle: 'Background music during combat',
                        value: _musicEnabled,
                        color: Colors.purpleAccent,
                        onChanged: (val) {
                          setState(() => _musicEnabled = val);
                          widget.audioSystem.toggleMusic();
                          if (!val) {
                            widget.audioSystem.stopMusic();
                          } else {
                            widget.audioSystem.playMusic('battle_theme');
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildVolumeTile(
                        label: 'Music Volume',
                        value: _musicVolume,
                        color: Colors.purpleAccent,
                        enabled: _musicEnabled,
                        onChanged: (val) {
                          setState(() => _musicVolume = val);
                          widget.audioSystem.setMusicVolume(val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildSection(
                    icon: FontAwesomeIcons.volumeHigh,
                    title: 'SOUND EFFECTS',
                    color: Colors.blueAccent,
                    children: [
                      _buildToggleTile(
                        label: 'Sound Effects',
                        subtitle: 'Hit sounds, pickups, combat feedback',
                        value: _sfxEnabled,
                        color: Colors.blueAccent,
                        onChanged: (val) {
                          setState(() => _sfxEnabled = val);
                          widget.audioSystem.toggleSFX();
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildVolumeTile(
                        label: 'SFX Volume',
                        value: _sfxVolume,
                        color: Colors.blueAccent,
                        enabled: _sfxEnabled,
                        onChanged: (val) {
                          setState(() => _sfxVolume = val);
                          widget.audioSystem.setSFXVolume(val);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          ),
        ),
        const SizedBox(width: 20),
        const Text(
          'SETTINGS',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FaIcon(icon, color: color, size: 16),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildToggleTile({
    required String label,
    required String subtitle,
    required bool value,
    required Color color,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: color,
          inactiveTrackColor: Colors.grey[700],
        ),
      ],
    );
  }

  Widget _buildVolumeTile({
    required String label,
    required double value,
    required Color color,
    required bool enabled,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.white : Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${(value * 100).toInt()}%',
              style: TextStyle(
                color: enabled ? color : Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: enabled ? color : Colors.grey[700],
            inactiveTrackColor: Colors.grey[800],
            thumbColor: enabled ? color : Colors.grey[600],
            overlayColor: color.withOpacity(0.2),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value,
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ],
    );
  }
}