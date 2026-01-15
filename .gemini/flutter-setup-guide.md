# Flutter 2D Action Game - Complete Setup Guide

## 📋 Prerequisites

- Flutter SDK installed (https://flutter.dev/docs/get-started/install)
- Android Studio or VS Code
- iOS: Xcode (Mac only)
- Android: Android SDK

## 🚀 Quick Start (5 Steps)

### Step 1: Create Flutter Project

```bash
flutter create action_game
cd action_game
```

### Step 2: Update pubspec.yaml

Open `pubspec.yaml` and replace the dependencies section:

```yaml
name: action_game
description: A 2D multiplayer action game

publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flame: ^1.17.0
  flame_forge2d: ^0.17.0
  socket_io_client: ^2.0.3

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
  
  assets:
    - assets/images/knight.png
    - assets/images/thief.png
    - assets/images/wizard.png
    - assets/images/trader.png
    - assets/images/knight_attack.png
    - assets/images/thief_attack.png
    - assets/images/wizard_attack.png
    - assets/images/trader_attack.png
```

### Step 3: Install Dependencies

```bash
flutter pub get
```

### Step 4: Replace main.dart

Copy the complete game code from the artifact and replace the content of `lib/main.dart`

### Step 5: Add Sprite Assets

#### Option A: Generate Sprites (Easiest)
1. Open the "Character Sprite Generator (Web)" artifact in your browser
2. Click "Download All Sprites as ZIP"
3. Extract the ZIP
4. Create folder: `assets/images/` in your project root
5. Copy all PNG files into `assets/images/`

#### Option B: Use Placeholder Colors
- The game will work without sprites (colored rectangles as fallback)
- Just run the game and add sprites later

### Step 6: Run the Game

```bash
# For Android
flutter run

# For iOS (Mac only)
flutter run -d ios

# For Web
flutter run -d chrome
```

## 📱 Project Structure

```
action_game/
├── android/               # Android native code
├── ios/                   # iOS native code
├── lib/
│   └── main.dart         # Complete game code (paste here)
├── assets/
│   └── images/           # Character sprites
│       ├── knight.png
│       ├── knight_attack.png
│       ├── thief.png
│       ├── thief_attack.png
│       ├── wizard.png
│       ├── wizard_attack.png
│       ├── trader.png
│       └── trader_attack.png
├── pubspec.yaml          # Dependencies configuration
└── README.md
```

## 🎮 Game Features

### Implemented
- ✅ Character selection (4 classes)
- ✅ 2D platformer movement
- ✅ Jump, crouch, wall slide, climb
- ✅ Attack system (melee & ranged)
- ✅ AI enemies
- ✅ Stats system with upgrades
- ✅ Money/rewards system
- ✅ Health bars
- ✅ Virtual joystick for mobile
- ✅ Sprite animation support
- ✅ Platform collision detection

### Controls
- **Joystick** (bottom left): Move character
  - Left/Right: Walk
  - Up: Jump (or climb when on wall)
  - Down: Crouch
- **Red Button** (top right): Attack
- **Tap anywhere**: Also attacks

## 🔧 Troubleshooting

### "Package not found" error
```bash
flutter clean
flutter pub get
flutter run
```

### Sprites not loading
- Check that `assets/images/` folder exists in project root
- Verify `pubspec.yaml` has correct indentation for assets
- Run `flutter pub get` after modifying pubspec.yaml
- The game will show colored rectangles as fallback

### Performance issues
```dart
// In ActionGame.onLoad(), adjust camera zoom:
camera.viewfinder.zoom = 1.0; // Increase for better performance
```

### Black screen on startup
- Make sure main.dart is saved
- Try hot restart: `R` in terminal or Shift+R in IDE

## 📝 Customization

### Add More Characters

```dart
// In CharacterStats.fromClass(), add new case:
case CharacterClass.archer:
  return CharacterStats(
    type: type,
    power: 9,
    magic: 8,
    dexterity: 15,
    intelligence: 9,
    weaponName: 'Longbow',
    attackRange: 15.0,
    attackDamage: 14,
    color: Colors.cyan,
  );
```

### Change Difficulty

```dart
// In Enemy.update(), adjust AI speed:
velocity.x = toPlayer.normalized().x * (stats.dexterity / 2); // Faster enemies

// In ActionGame.onLoad(), add more enemies:
for (int i = 0; i < 5; i++) { // Change from 3 to 5
```

### Add Sound Effects

```yaml
# Add to pubspec.yaml:
dependencies:
  audioplayers: ^5.2.1

# Add assets:
flutter:
  assets:
    - assets/sounds/attack.mp3
    - assets/sounds/jump.mp3
```

```dart
// In main.dart:
import 'package:audioplayers/audioplayers.dart';

final audioPlayer = AudioPlayer();

void attack() {
  audioPlayer.play(AssetSource('sounds/attack.mp3'));
  // ... rest of attack code
}
```

## 🌐 Add Multiplayer

See the Network Manager code in previous responses or add:

```bash
# Install Socket.IO
npm install express socket.io

# Create server.js (Node.js backend)
# Run: node server.js
```

Then integrate NetworkManager class into the game.

## 📚 Resources

- **Flame Documentation**: https://docs.flame-engine.org/
- **Flutter Docs**: https://docs.flutter.dev/
- **Free Sprites**: https://opengameart.org/
- **Paid Assets**: https://itch.io/game-assets

## 🐛 Known Issues

1. **Stats upgrade buttons in HUD are not interactive** - They show current values but need UI overlay for interaction
2. **Camera bounds** - Player can move off-screen edges
3. **No game over screen** - Game just stops when player dies
4. **Enemy AI is basic** - Enemies just move toward player

## 🎯 Next Steps

1. Add win/lose conditions
2. Implement level system
3. Add more platforms and obstacles
4. Create boss enemies
5. Add power-ups and collectibles
6. Implement save/load system
7. Add multiplayer networking
8. Create main menu with settings
9. Add sound effects and music
10. Publish to App Store / Play Store

## 📄 License

Free to use and modify for personal or commercial projects.

---

**Need Help?** Check Flutter docs or Flame Engine documentation!
