// network_manager.dart
import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'main.dart';

class NetworkManager {
  static final NetworkManager _instance = NetworkManager._internal();
  factory NetworkManager() => _instance;
  NetworkManager._internal();

  late IO.Socket socket;
  final Map<String, Player> remotePlayers = {};

  void connect(String characterClass, CharacterStats stats) {
    socket = IO.io('http://YOUR_SERVER_IP:3000',
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .build()
    );

    socket.onConnect((_) {
      print('Connected to server');
      socket.emit('join-game', {
        'characterClass': characterClass,
        'position': {'x': 0, 'y': 0},
        'stats': {
          'power': stats.power,
          'magic': stats.magic,
          'dexterity': stats.dexterity,
          'intelligence': stats.intelligence
        }
      });
    });

    socket.on('current-players', (data) {
      // Add existing players
      data.forEach((playerId, playerData) {
        if (playerId != socket.id) {
          _addRemotePlayer(playerId, playerData);
        }
      });
    });

    socket.on('player-joined', (data) {
      _addRemotePlayer(data['id'], data);
    });

    socket.on('player-moved', (data) {
      if (remotePlayers.containsKey(data['id'])) {
        // remotePlayers[data['id']]!.updatePosition( //TODO: fix here
        //     data['position']['x'],
        //     data['position']['y']
        // );
      }
    });

    socket.on('player-attacked', (data) {
      // Handle remote player attacks
    });

    socket.on('player-left', (playerId) {
      remotePlayers[playerId]?.removeFromParent();
      remotePlayers.remove(playerId);
    });
  }

  void sendPosition(double x, double y) {
    socket.emit('player-move', {
      'position': {'x': x, 'y': y}
    });
  }

  void sendAttack(String attackType, double x, double y) {
    socket.emit('player-attack', {
      'type': attackType,
      'position': {'x': x, 'y': y}
    });
  }

  void _addRemotePlayer(String id, dynamic data) {
    // Create NetworkPlayer component and add to game
  }

  void disconnect() {
    socket.disconnect();
  }
}

// In Player.update(), add:
// NetworkManager().sendPosition(position.x, position.y);