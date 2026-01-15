import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'character_selection_screen.dart';

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
    return MaterialApp(
      title: '2D Action Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const CharacterSelectionScreen(),
    );
  }
}
