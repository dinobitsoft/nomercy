# Game Map Editor - Landscape Mode Guide

## 📐 Overview

The game now supports **landscape mode only** with **16:9 aspect ratio** (1920×1080 pixels).

---

## 🎨 Map Editor Features

### Canvas Specifications
- **Size**: 1920×1080 pixels (16:9 ratio)
- **Orientation**: Landscape only
- **Grid**: 60px spacing for easy alignment
- **Safe Zone**: Red dashed boundary (50px margin)

### Tools Available
1. **Brick Platform** - Brown platforms for jumping
2. **Ground Platform** - Green solid ground
3. **Player Spawn** - Blue circle (starting position)
4. **Eraser** - Remove objects

### Using the Editor

**Create Platforms:**
1. Select tool (Brick or Ground)
2. Adjust width and height
3. Click on canvas to place
4. Right-click to remove

**Set Spawn Point:**
1. Select "Spawn" tool
2. Click where player should start
3. Usually place near bottom, left side

**Best Practices:**
- Create ground at bottom (y: ~1000)
- Leave 50px margins on all sides
- Use grid for alignment
- Test spawn point is safe (not in air!)

---

## 📊 JSON Format (16:9 Landscape)

```json
{
  "name": "level_1",
  "width": 1920,
  "height": 1080,
  "aspectRatio": "16:9",
  "orientation": "landscape",
  "platforms": [
    {
      "id": 1234567890,
      "type": "ground",
      "x": 0,
      "y": 1000,
      "width": 1920,
      "height": 80
    },
    {
      "id": 1234567891,
      "type": "brick",
      "x": 400,
      "y": 800,
      "width": 200,
      "height": 30
    }
  ],
  "playerSpawn": {
    "x": 200,
    "y": 900
  }
}
```

**Field Descriptions:**
- `width/height`: Always 1920×1080 for 16:9
- `aspectRatio`: "16:9" identifier
- `orientation`: "landscape" identifier
- Platform `x,y`: Top-left corner position
- Spawn `x,y`: Center point of player

---

## 🎮 Flutter Landscape Setup

### Step 1: Force Landscape Mode

Update `main.dart`:

```dart
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock to landscape
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]).then((_) {
    // Full screen mode
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky
    );
    
    runApp(const GameApp());
  });
}
```

### Step 2: Android Configuration

Edit `android/app/src/main/AndroidManifest.xml`:

```xml
<activity
    android:name=".MainActivity"
    android:screenOrientation="landscape"
    android:configChanges="orientation|keyboardHidden|keyboard|screenSize|locale"
    android:hardwareAccelerated="true"
    android:windowSoftInputMode="adjustResize">
    <!-- ... rest of activity config ... -->
</activity>
```

### Step 3: iOS Configuration

Edit `ios/Runner/Info.plist`:

```xml
<key>UISupportedInterfaceOrientations</key>
<array>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
</array>

<!-- Remove portrait orientations if present -->
```

### Step 4: Update Game Camera

In `ActionGame.onLoad()`:

```dart
// Set camera for 16:9 landscape
camera.viewfinder.zoom = 0.8;
camera.viewfinder.visibleGameSize = Vector2(1920, 1080);
```

---

## 📱 Project Structure

```
your_flutter_project/
├── android/
│   └── app/src/main/
│       └── AndroidManifest.xml    # Add landscape config
├── ios/
│   └── Runner/
│       └── Info.plist             # Add landscape config
├── assets/
│   └── maps/
│       ├── level_1.json           # 1920×1080
│       ├── level_2.json
│       └── level_3.json
├── lib/
│   ├── main.dart                  # Updated with landscape lock
│   └── map_loader.dart
└── pubspec.yaml
```

---

## 🎯 Example Level Designs

### Level 1: Tutorial (Easy)

```json
{
  "name": "tutorial",
  "width": 1920,
  "height": 1080,
  "aspectRatio": "16:9",
  "orientation": "landscape",
  "platforms": [
    {
      "id": 1,
      "type": "ground",
      "x": 0,
      "y": 1000,
      "width": 1920,
      "height": 80
    },
    {
      "id": 2,
      "type": "brick",
      "x": 500,
      "y": 850,
      "width": 200,
      "height": 30
    },
    {
      "id": 3,
      "type": "brick",
      "x": 900,
      "y": 700,
      "width": 200,
      "height": 30
    },
    {
      "id": 4,
      "type": "brick",
      "x": 1300,
      "y": 550,
      "width": 200,
      "height": 30
    }
  ],
  "playerSpawn": {
    "x": 200,
    "y": 920
  }
}
```

### Level 2: Platforms (Medium)

```json
{
  "name": "platforms",
  "width": 1920,
  "height": 1080,
  "platforms": [
    {
      "id": 1,
      "type": "ground",
      "x": 0,
      "y": 1000,
      "width": 600,
      "height": 80
    },
    {
      "id": 2,
      "type": "ground",
      "x": 1320,
      "y": 1000,
      "width": 600,
      "height": 80
    },
    {
      "id": 3,
      "type": "brick",
      "x": 700,
      "y": 850,
      "width": 150,
      "height": 30
    },
    {
      "id": 4,
      "type": "brick",
      "x": 1070,
      "y": 850,
      "width": 150,
      "height": 30
    },
    {
      "id": 5,
      "type": "brick",
      "x": 885,
      "y": 650,
      "width": 150,
      "height": 30
    }
  ],
  "playerSpawn": {
    "x": 200,
    "y": 920
  }
}
```

### Level 3: Cave (Hard)

```json
{
  "name": "cave",
  "width": 1920,
  "height": 1080,
  "platforms": [
    {
      "id": 1,
      "type": "ground",
      "x": 0,
      "y": 1000,
      "width": 1920,
      "height": 80
    },
    {
      "id": 2,
      "type": "brick",
      "x": 0,
      "y": 0,
      "width": 80,
      "height": 1080
    },
    {
      "id": 3,
      "type": "brick",
      "x": 1840,
      "y": 0,
      "width": 80,
      "height": 1080
    },
    {
      "id": 4,
      "type": "brick",
      "x": 300,
      "y": 750,
      "width": 400,
      "height": 40
    },
    {
      "id": 5,
      "type": "brick",
      "x": 900,
      "y": 600,
      "width": 400,
      "height": 40
    },
    {
      "id": 6,
      "type": "brick",
      "x": 1400,
      "y": 450,
      "width": 300,
      "height": 40
    }
  ],
  "playerSpawn": {
    "x": 200,
    "y": 920
  }
}
```

---

## 🎨 UI Adjustments for Landscape

### Character Selection Screen
- **Layout**: Side-by-side (title left, cards right)
- **Cards**: 2×2 grid
- **Aspect**: 1.2 ratio (wider cards)

### Level Selection Screen
- **Layout**: Horizontal grid
- **Cards**: 3 columns
- **Aspect**: 1.8 ratio (landscape cards)

### In-Game HUD
- **Health Bar**: Top-left corner (280×100px)
- **Attack Button**: Top-right corner (120px diameter)
- **Joystick**: Bottom-left (80px radius)

---

## 🔧 Troubleshooting

### Portrait Mode Still Appears

**Android:**
```bash
# Clean build
flutter clean
flutter pub get
flutter run
```

Check `AndroidManifest.xml` has:
```xml
android:screenOrientation="landscape"
```

**iOS:**
Verify `Info.plist` only has landscape orientations.

### Map Not Filling Screen

In `ActionGame`:
```dart
camera.viewfinder.zoom = 0.8; // Adjust 0.5-1.5
camera.viewfinder.visibleGameSize = Vector2(1920, 1080);
```

### Platforms Appear Stretched

Ensure map JSON has:
```json
"width": 1920,
"height": 1080
```

### Controls Too Small/Large

Adjust joystick size:
```dart
joystick = JoystickComponent(
  knob: CircleComponent(radius: 40),  // Increase/decrease
  background: CircleComponent(radius: 80),
  margin: const EdgeInsets.only(left: 60, bottom: 60),
);
```

---

## 📏 Design Guidelines

### Platform Sizing (16:9 Landscape)
- **Small platforms**: 120×30px
- **Medium platforms**: 200×40px
- **Large platforms**: 400×50px
- **Ground**: Full width (1920px) × 80px height

### Spacing
- **Vertical jump**: 150-200px between platforms
- **Horizontal gap**: 200-300px for skilled jumps
- **Safe margins**: 50px from edges

### Player Spawn
- **Position**: Bottom-left area (x: 100-300, y: 900-950)
- **Safety**: Place on solid ground, not in air
- **Space**: Leave 200px clearance above

---

## ✅ Quick Checklist

**Map Editor:**
- [ ] Canvas is 1920×1080
- [ ] Created ground platform
- [ ] Added jumping platforms
- [ ] Set player spawn point
- [ ] Exported JSON with correct name

**Flutter Setup:**
- [ ] Added landscape lock in `main()`
- [ ] Updated `AndroidManifest.xml`
- [ ] Updated `Info.plist` (iOS)
- [ ] Map JSON in `assets/maps/`
- [ ] Updated `pubspec.yaml`
- [ ] Tested on device in landscape

**Testing:**
- [ ] App starts in landscape
- [ ] Cannot rotate to portrait
- [ ] Map loads correctly
- [ ] Player spawns safely
- [ ] All platforms visible
- [ ] Controls accessible

---

## 🎮 Performance Tips

For smooth 60 FPS in landscape:

```dart
// Optimize camera
camera.viewfinder.zoom = 0.8;

// Limit enemy count
for (int i = 0; i < 3; i++) { // Max 3-5 enemies

// Reduce particle effects if needed
// Use simpler collision detection
```

---

**Ready to create landscape levels!** 🎉

Open the Map Editor, design your level, and export for Flutter!
