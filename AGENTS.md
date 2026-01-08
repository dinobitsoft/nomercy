# Game Agents Documentation

## Overview
This document describes the various agents (entities) in the game, including the Player, Enemies, and their properties.

## 1. Player
The main character controlled by the user.

### Properties
- **Health**: 100
- **Movement**:
    - Controlled via Joystick.
    - Supports walking, crouching, climbing, and wall sliding.
    - Jumping and gravity physics.
- **Combat**:
    - **Melee Attack**: Available for Knight class.
    - **Ranged Attack**: Projectiles for other classes.
    - **Attack Cooldown**: 0.5 seconds.
- **Animations**: Idle, Walk, Attack.

### Classes (CharacterClass)
The player can select one of the following classes, which determines their stats:

| Class | Power | Magic | Dexterity | Intelligence | Weapon | Range | Damage | Color |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Knight** | 15 | 5 | 8 | 7 | Sword Slash | 2.0 | 15 | Blue |
| **Thief** | 8 | 6 | 16 | 10 | Throwing Knives | 8.0 | 10 | Green |
| **Wizard** | 6 | 18 | 7 | 14 | Fireball | 10.0 | 20 | Purple |
| **Trader** | 10 | 7 | 12 | 11 | Bow & Arrow | 12.0 | 12 | Orange |

## 2. Enemy
AI-controlled opponents that attack the player.

### Behavior
- **Movement**:
    - Moves towards the player when within 300 distance units.
    - Uses dexterity stat for movement speed.
    - Jumps if no ground is detected.
- **Combat**:
    - **Melee Attack**: Damages player when within range.
    - **Attack Cooldown**: 2.0 seconds.
- **Health**: 100 (visualized with a health bar).
- **Spawn**: Spawns at specific locations relative to the player spawn point.

### Types
Enemies use the same `CharacterClass` types as the player, cycling through them.

## 3. Projectile
Ranged attacks fired by the player (except Knight).

### Properties
- **Damage**: Based on player's attack damage.
- **Direction**: Horizontal (left or right) based on player facing.
- **Lifetime**: 3.0 seconds.
- **Collision**:
    - Destroys on impact with enemies (dealing damage).
    - Destroys on impact with platforms/walls.

## 4. Systems
- **Physics**: Simple AABB collision detection with gravity and velocity.
- **Camera**: Follows the player, locked to 16:9 landscape aspect ratio (1920x1080 visible area).
- **Input**: Virtual Joystick for movement, Tap for attack.
