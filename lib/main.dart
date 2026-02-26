import 'package:engine/engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamepad/gamepad.dart';
import 'package:ui/ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock to landscape for better gameplay experience
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]).then((_) {
    // Enable immersive full-screen mode
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky
    );
    
    runApp(const GameApp());
  });
}

class GameApp extends StatelessWidget {
  const GameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LocalizationManager(),
      builder: (context, child) {
        return MaterialApp(
          title: LocalizationManager().translate('game_title'),
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          locale: LocalizationManager().locale,
          // ── Register the route observer so GamepadRouteAware works ──────────
          navigatorObservers: [gamepadRouteObserver],
          home: const CharacterSelectionScreen(),
        );
      },
    );
  }
}