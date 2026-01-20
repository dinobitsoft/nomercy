# No Mercy - 2D Multiplayer Action Game

## 🎮 Overview
**No Mercy** is a high-octane, 2D platformer action game built using the **Flutter** framework and the **Flame** game engine. It features a robust class-based character system, intelligent AI-driven bots, dynamic map loading, and a reward-based progression system. The game is optimized for a 16:9 landscape experience on mobile devices.

---

## 🏗 Architecture
The project follows a modular, strategy-oriented architecture:
- **GameCharacter (Base)**: An abstract class handling core physics (AABB collision, gravity, movement) and animations.
- **Specialized Classes**: Knight, Thief, Wizard, and Trader each inherit from `GameCharacter` with unique attack logic.
- **Control System**: Characters can be assigned a `PlayerType` (Human or Bot).
- **Tactic System**: Uses the **Strategy Pattern** for AI. `BotTactic` interfaces allow enemies to switch between Aggressive, Defensive, Balanced, or Cowardly behaviors.
- **Map System**: Decoupled JSON-based map loading via `MapLoader`, supporting platforms, player spawns, and interactive chests.

---

## 🎭 Game Agents & Classes
Characters are rendered with high-resolution sprites (Base size: 128x128 to 160x240) and feature unique stats:

| Class | Weapon | Attack Style | Base Stats |
| :--- | :--- | :--- | :--- |
| **Knight** | Sword Slash | Melee | High Power & Defense |
| **Thief** | Throwing Knives | Fast Ranged | High Dexterity & Evasion |
| **Wizard** | Fireball | Heavy Ranged | High Magic & Intelligence |
| **Trader** | Bow & Arrow | Long Ranged | Balanced Stats |

---

## 🤖 AI & Bot Tactics
Enemies utilize an intelligent state machine (**Patrol → Chase → Attack → Evade**):
- **Aggressive**: Charges the player relentlessly at 2x speed.
- **Defensive**: Maintains distance and kiters the player.
- **Balanced**: Circle-strafes and uses medium-range attacks.
- **Coward**: Runs away when health is low or projectiles are detected.
- **Evasion**: Bots can "Duck" or "Jump" to dodge incoming projectiles based on their character signature.

---

## ⚔️ Core Mechanics
- **Movement**: Standard platforming including jumping, crouching, wall-sliding, and climbing.
- **Combat System**:
    - **Melee**: Area-of-effect hits for the Knight.
    - **Ranged**: Projectile system with configurable speeds, unique trails, and particle-based impact effects.
- **Interactive Chests**: Golden chests (`dower_chest.png`) that provide random rewards:
    - 💚 **Health**: Restores HP.
    - 💰 **Money**: Increases player funds for upgrades.
    - 📦 **Nothing**: The "Empty!" trap.
- **Physics**: Custom AABB collision detection against tiled and enhanced platforms.

---

## 🗺 Level Design & Visuals
- **Landscape Lock**: The game is hard-locked to 16:9 landscape mode with a base resolution of 1920x1080 (scaled to 1280x720 for mobile performance).
- **Textured Platforms**: Supports seamless tiling for Brick and Ground textures, moving away from solid color placeholders.
- **Backgrounds**: Dynamic linear gradient backgrounds combined with sprite-based environment layers.
- **Map Editor**: Support for custom level creation via JSON exports including platform positioning and entity spawns.

---

## 📱 User Interface (UI)
- **Character Selection**: A visual grid showcasing high-res hero previews, weapon info, and detailed stat columns.
- **Gamepad Support**: Real-time detection for **2.4 GHz Cordless Gamepads** and Bluetooth controllers with a "Gamepad Ready" status indicator.
- **In-Game HUD**: A transparent, top-aligned overlay using **FontAwesome Icons**:
    - 💀 **Heart (Red)**: Health status.
    - 💰 **Coins**: Money/Gold count.
    - 💀 **Skull (White)**: Kill counter.
    - **Health Bar**: Dynamic color-changing bar (Green → Orange → Red).

---

## 🌐 Networking
- **Multiplayer Ready**: Integrated `NetworkManager` using **Socket.IO**.
- Supports real-time position syncing, attack broadcasting, and remote player spawning for a competitive multiplayer experience.

---

## 🛠 Prerequisites & Setup
- **Flutter SDK**: ^3.10.4
- **Flame Engine**: ^1.17.0
- **Key Assets**: Located in `assets/images/` and `assets/maps/`.
- **Entry Point**: `lib/main.dart` handles the landscape initialization and character selection launch.
