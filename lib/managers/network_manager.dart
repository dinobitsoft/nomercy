import 'dart:async' as dart_async;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:socket_io_common/src/util/event_emitter.dart';

import '../game/action_game.dart';
import '../character_stats.dart';
import '../entities/projectile/projectile.dart';
import '../game/character/knight.dart';
import '../game/character/thief.dart';
import '../game/character/trader.dart';
import '../game/character/wizard.dart';
import '../game/game_character.dart';
import '../game/stat/stats.dart';
import '../map/game_map.dart';
import '../player_type.dart';

class NetworkManager {
  static final NetworkManager _instance = NetworkManager._internal();
  factory NetworkManager() => _instance;
  NetworkManager._internal();

  late IO.Socket socket;
  final Map<String, GameCharacter> remotePlayers = {};
  ActionGame? game;
  bool isConnected = false;
  String? myPlayerId;
  double networkUpdateTimer = 0;
  dart_async.Timer? heartbeatTimer;

  void connect(String characterClass, CharacterStats stats, ActionGame gameInstance, {String? roomId}) {
    game = gameInstance;

    // Server configuration
    socket = IO.io('http://10.0.2.2:3000',
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(1000)
            .setTimeout(5000)
            .build()
    );

    socket.onConnect((_) {
      debugPrint('✓ Connected to multiplayer server');
      isConnected = true;
      myPlayerId = socket.id;

      if (roomId != null) {
        // Join existing room
        socket.emit('join-room', {
          'room_id': roomId,
          'username': 'Player_${socket.id?.substring(0, 8)}',
          'character_class': characterClass,
          'stats': {
            'power': stats.power,
            'magic': stats.magic,
            'dexterity': stats.dexterity,
            'intelligence': stats.intelligence,
            'attackDamage': stats.attackDamage,
            'attackRange': stats.attackRange,
          }
        });
      } else {
        // Create new room
        socket.emit('create-room', {
          'map_name': game!.mapName,
          'game_mode': game!.gameMode.toString(),
          'max_players': 4
        });
      }

      _startHeartbeat();
    });

    socket.onConnectError((error) {
      debugPrint('✗ Connection error: $error');
      isConnected = false;
    });

    socket.onDisconnect((_) {
      debugPrint('✗ Disconnected from server');
      isConnected = false;
      heartbeatTimer?.cancel();
    });

    socket.on('current-players', (data) {
      debugPrint('Received current players: ${(data as Map).length} players');
      data.forEach((playerId, playerData) {
        if (playerId != socket.id) {
          _addRemotePlayer(playerId, playerData);
        }
      });
    });

    socket.on('player-joined', (data) {
      debugPrint('New player joined: ${data['id']} as ${data['characterClass']}');
      _addRemotePlayer(data['id'], data);
    });

    socket.on('player-moved', (data) {
      final playerId = data['id'];
      if (remotePlayers.containsKey(playerId)) {
        remotePlayers[playerId]!.position = Vector2(
          data['position']['x'].toDouble(),
          data['position']['y'].toDouble(),
        );

        if (data['facingRight'] != null) {
          remotePlayers[playerId]!.facingRight = data['facingRight'];
        }

        if (data['velocity'] != null) {
          remotePlayers[playerId]!.velocity = Vector2(
            data['velocity']['x'].toDouble(),
            data['velocity']['y'].toDouble(),
          );
        }
      }
    });

    socket.on('player-attacked', (data) {
      final playerId = data['id'];
      if (remotePlayers.containsKey(playerId)) {
        final remotePlayer = remotePlayers[playerId]!;
        remotePlayer.isAttacking = true;
        remotePlayer.attackAnimationTimer = 0.2;

        // Create projectile for ranged attacks
        final characterClass = data['characterClass'] as String;
        if (characterClass != 'knight') {
          final direction = Vector2(
            data['direction']['x'].toDouble(),
            data['direction']['y'].toDouble(),
          );

          final projectile = Projectile(
            position: Vector2(
              data['position']['x'].toDouble(),
              data['position']['y'].toDouble(),
            ),
            direction: direction,
            damage: remotePlayer.stats.attackDamage,
            owner: null,
            enemyOwner: remotePlayer,
            color: _getColorForClass(characterClass),
            type: _getProjectileType(characterClass),
          );

          game?.add(projectile);
          game?.world.add(projectile);
          game?.projectiles.add(projectile);
        }
      }
    });

    socket.on('player-damaged', (data) {
      final targetId = data['id'];
      final health = data['health'].toDouble();

      if (targetId == socket.id) {
        // Local player took damage
        game?.player.health = health;
        debugPrint('You took damage! Health: $health');
      } else if (remotePlayers.containsKey(targetId)) {
        // Remote player took damage
        remotePlayers[targetId]!.health = health;
      }
    });

    socket.on('player-died', (data) {
      final deadId = data['id'];
      final killerId = data['killerId'];

      if (deadId == socket.id) {
        // Local player died
        debugPrint('You died! Killed by: $killerId');
        game?.player.health = 0;
      } else if (remotePlayers.containsKey(deadId)) {
        // Remote player died
        remotePlayers[deadId]!.health = 0;

        // Award money to killer if it's local player
        if (killerId == socket.id) {
          game?.player.stats.money += 20;
          game?.enemiesDefeated++;
          debugPrint('You got a kill! +\$20');
        }
      }
    });

    socket.on('player-respawned', (data) {
      final respawnedId = data['id'];

      if (respawnedId == socket.id) {
        // Local player respawned
        game?.player.health = 100;
        game?.player.position = Vector2(
          data['position']['x'].toDouble(),
          data['position']['y'].toDouble(),
        );
        debugPrint('You respawned!');
      } else if (remotePlayers.containsKey(respawnedId)) {
        // Remote player respawned
        final remotePlayer = remotePlayers[respawnedId]!;
        remotePlayer.health = 100;
        remotePlayer.position = Vector2(
          data['position']['x'].toDouble(),
          data['position']['y'].toDouble(),
        );
      }
    });

    socket.on('player-left', (playerId) {
      debugPrint('Player left: $playerId');
      final remotePlayer = remotePlayers[playerId];
      if (remotePlayer != null) {
        remotePlayer.removeFromParent();
        remotePlayers.remove(playerId);
      }
    });

    socket.on('stat-upgraded', (data) {
      debugPrint('Stat upgraded: ${data['stat']} to ${data['newValue']}');
      game?.player.stats.money = data['money'];
    });

    socket.on('pong', () { //TODO: fix for cast
      // Handle latency measurement if needed
    } as EventHandler<dynamic>);
  }

  void saveMapWithSpawns(String mapName, List<SpawnPoint> spawns) async {
    final socket = IO.io('http://10.0.2.2:3000');

    socket.emit('save-spawn-points', {
      'map_name': mapName,
      'spawn_points': spawns.map((s) => {
        'x': s.x,
        'y': s.y,
        'occupied': false
      }).toList(),
      'width': 1920,
      'height': 1080,
    });
  }

  void _startHeartbeat() {
    heartbeatTimer?.cancel();
    heartbeatTimer = dart_async.Timer.periodic(const Duration(seconds: 25), (timer) {
      if (isConnected) {
        socket.emit('ping');
      }
    });
  }

  void update(double dt) {
    if (!isConnected || game == null) return;

    networkUpdateTimer += dt;

    // Send position updates at 10Hz (every 100ms)
    if (networkUpdateTimer >= 0.1) {
      sendPosition(
        game!.player.position.x,
        game!.player.position.y,
        game!.player.facingRight,
        game!.player.velocity.x,
        game!.player.velocity.y,
      );
      networkUpdateTimer = 0;
    }
  }

  void sendPosition(double x, double y, bool facingRight, double velX, double velY) {
    if (isConnected) {
      socket.emit('player-move', {
        'position': {'x': x, 'y': y},
        'velocity': {'x': velX, 'y': velY},
        'facingRight': facingRight,
      });
    }
  }

  void sendAttack(String characterClass, double x, double y, double directionX, double directionY) {
    if (isConnected) {
      socket.emit('player-attack', {
        'type': characterClass,
        'position': {'x': x, 'y': y},
        'direction': {'x': directionX, 'y': directionY},
      });
    }
  }

  void sendDamage(String targetId, double damage) {
    if (isConnected) {
      socket.emit('player-damage', {
        'targetId': targetId,
        'damage': damage,
      });
    }
  }

  void upgradeStatOnServer(String stat) {
    if (isConnected) {
      socket.emit('upgrade-stat', {
        'stat': stat,
      });
    }
  }

  void _addRemotePlayer(String id, dynamic data) {
    if (game == null || remotePlayers.containsKey(id)) return;

    final characterClass = data['characterClass'] as String;
    final position = Vector2(
      data['position']['x'].toDouble(),
      data['position']['y'].toDouble(),
    );

    // Create stats based on character class
    CharacterStats stats;
    switch (characterClass.toLowerCase()) {
      case 'knight':
        stats = KnightStats();
        break;
      case 'thief':
        stats = ThiefStats();
        break;
      case 'wizard':
        stats = WizardStats();
        break;
      case 'trader':
        stats = TraderStats();
        break;
      default:
        stats = KnightStats();
    }

    // Apply received stats if available
    if (data['stats'] != null) {
      stats.power = data['stats']['power']?.toDouble() ?? stats.power;
      stats.magic = data['stats']['magic']?.toDouble() ?? stats.magic;
      stats.dexterity = data['stats']['dexterity']?.toDouble() ?? stats.dexterity;
      stats.intelligence = data['stats']['intelligence']?.toDouble() ?? stats.intelligence;
      stats.attackDamage = data['stats']['attackDamage']?.toDouble() ?? stats.attackDamage;
    }

    // Create the appropriate character type as a remote player
    GameCharacter remotePlayer;
    switch (characterClass.toLowerCase()) {
      case 'knight':
        remotePlayer = Knight(
          position: position,
          playerType: PlayerType.bot, // Use bot type for remote players
          botTactic: null, // No AI for remote players
        );
        break;
      case 'thief':
        remotePlayer = Thief(
          position: position,
          playerType: PlayerType.bot,
          botTactic: null,
        );
        break;
      case 'wizard':
        remotePlayer = Wizard(
          position: position,
          playerType: PlayerType.bot,
          botTactic: null,
        );
        break;
      case 'trader':
        remotePlayer = Trader(
          position: position,
          playerType: PlayerType.bot,
          botTactic: null,
        );
        break;
      default:
        remotePlayer = Knight(
          position: position,
          playerType: PlayerType.bot,
          botTactic: null,
        );
    }

    // Mark as remote player by storing the network ID
    remotePlayer.priority = 50; // Render above platforms but below local player

    game!.add(remotePlayer);
    game!.world.add(remotePlayer);
    remotePlayers[id] = remotePlayer;

    debugPrint('Added remote player: $id ($characterClass) at $position');
  }

  Color _getColorForClass(String characterClass) {
    switch (characterClass.toLowerCase()) {
      case 'knight':
        return Colors.blue;
      case 'thief':
        return Colors.green;
      case 'wizard':
        return Colors.purple;
      case 'trader':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getProjectileType(String characterClass) {
    switch (characterClass.toLowerCase()) {
      case 'thief':
        return 'knife';
      case 'wizard':
        return 'fireball';
      case 'trader':
        return 'arrow';
      default:
        return 'projectile';
    }
  }

  void disconnect() {
    if (isConnected) {
      heartbeatTimer?.cancel();
      socket.disconnect();
      isConnected = false;

      // Clean up all remote players
      remotePlayers.forEach((id, player) {
        player.removeFromParent();
      });
      remotePlayers.clear();

      debugPrint('Disconnected from multiplayer server');
    }
  }

  // Check if a character is a remote player
  bool isRemotePlayer(GameCharacter character) {
    return remotePlayers.containsValue(character);
  }

  // Get remote player ID
  String? getRemotePlayerId(GameCharacter character) {
    for (final entry in remotePlayers.entries) {
      if (entry.value == character) {
        return entry.key;
      }
    }
    return null;
  }
}