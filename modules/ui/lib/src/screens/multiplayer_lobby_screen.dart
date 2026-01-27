import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class MultiplayerLobbyScreen extends StatefulWidget {
  final String selectedCharacterClass;

  const MultiplayerLobbyScreen({
    super.key,
    required this.selectedCharacterClass,
  });

  @override
  State<MultiplayerLobbyScreen> createState() => _MultiplayerLobbyScreenState();
}

class _MultiplayerLobbyScreenState extends State<MultiplayerLobbyScreen> {
  late IO.Socket socket;
  List<Map<String, dynamic>> availableRooms = [];
  bool isConnecting = true;
  bool isConnected = false;

  @override
  void initState() {
    super.initState();
    _connectToServer();
  }

  void _connectToServer() {
    socket = IO.io('http://10.0.2.2:3000',
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .setReconnectionAttempts(5)
            .build()
    );

    socket.onConnect((_) {
      setState(() {
        isConnecting = false;
        isConnected = true;
      });
      _refreshRooms();
    });

    socket.on('rooms-list', (data) {
      setState(() {
        availableRooms = List<Map<String, dynamic>>.from(data['rooms']);
      });
    });

    socket.on('room-created', (data) {
      Navigator.pop(context, {
        'room_id': data['room_id'],
        'is_host': true,
      });
    });

    socket.onConnectError((error) {
      setState(() {
        isConnecting = false;
        isConnected = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection error: $error')),
      );
    });
  }

  void _refreshRooms() {
    socket.emit('list-rooms', {});
  }

  void _createRoom() {
    showDialog(
      context: context,
      builder: (context) => _CreateRoomDialog(socket: socket),
    );
  }

  void _joinRoom(String roomId) {
    Navigator.pop(context, {
      'room_id': roomId,
      'is_host': false,
    });
  }

  @override
  void dispose() {
    socket.dispose();
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
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'MULTIPLAYER LOBBY',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    // Connection status
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isConnected ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isConnected ? Icons.wifi : Icons.wifi_off,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isConnected ? 'ONLINE' : 'OFFLINE',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Action buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isConnected ? _createRoom : null,
                        icon: const Icon(Icons.add),
                        label: const Text('CREATE ROOM'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: isConnected ? _refreshRooms : null,
                      icon: const Icon(Icons.refresh),
                      label: const Text('REFRESH'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Room list
              Expanded(
                child: isConnecting
                    ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.blue),
                      SizedBox(height: 20),
                      Text(
                        'Connecting to server...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                )
                    : availableRooms.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey[600]),
                      const SizedBox(height: 20),
                      Text(
                        'No rooms available',
                        style: TextStyle(color: Colors.grey[400], fontSize: 18),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Create a room to start playing!',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: availableRooms.length,
                  itemBuilder: (context, index) {
                    final room = availableRooms[index];
                    return _RoomCard(
                      room: room,
                      onJoin: () => _joinRoom(room['room_id']),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final Map<String, dynamic> room;
  final VoidCallback onJoin;

  const _RoomCard({required this.room, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final availableSpawns = room['available_spawns'] ?? 0;
    final currentPlayers = room['current_players'] ?? 0;
    final maxPlayers = room['max_players'] ?? 4;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[800]!, Colors.blue[900]!],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blue, width: 2),
      ),
      child: Row(
        children: [
          // Room icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.gamepad, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 15),

          // Room info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room['map_name'] ?? 'Unknown Map',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  room['game_mode'] ?? 'Unknown Mode',
                  style: TextStyle(color: Colors.grey[300], fontSize: 14),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(Icons.people, color: Colors.orange, size: 16),
                    const SizedBox(width: 5),
                    Text(
                      '$currentPlayers/$maxPlayers players',
                      style: const TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                    const SizedBox(width: 15),
                    Icon(Icons.location_on, color: Colors.green, size: 16),
                    const SizedBox(width: 5),
                    Text(
                      '$availableSpawns spawns',
                      style: const TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Join button
          ElevatedButton(
            onPressed: availableSpawns > 0 ? onJoin : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('JOIN'),
          ),
        ],
      ),
    );
  }
}

class _CreateRoomDialog extends StatefulWidget {
  final IO.Socket socket;

  const _CreateRoomDialog({required this.socket});

  @override
  State<_CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends State<_CreateRoomDialog> {
  String selectedMap = 'level_1';
  String selectedMode = 'survival';
  int maxPlayers = 4;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text('Create Room', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: selectedMap,
            decoration: const InputDecoration(
              labelText: 'Map',
              labelStyle: TextStyle(color: Colors.white70),
            ),
            dropdownColor: Colors.grey[800],
            style: const TextStyle(color: Colors.white),
            items: ['level_1', 'level_2', 'level_3'].map((map) {
              return DropdownMenuItem(value: map, child: Text(map));
            }).toList(),
            onChanged: (value) => setState(() => selectedMap = value!),
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            value: selectedMode,
            decoration: const InputDecoration(
              labelText: 'Game Mode',
              labelStyle: TextStyle(color: Colors.white70),
            ),
            dropdownColor: Colors.grey[800],
            style: const TextStyle(color: Colors.white),
            items: ['survival', 'campaign', 'bossFight'].map((mode) {
              return DropdownMenuItem(value: mode, child: Text(mode));
            }).toList(),
            onChanged: (value) => setState(() => selectedMode = value!),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              const Text('Max Players:', style: TextStyle(color: Colors.white)),
              const Spacer(),
              DropdownButton<int>(
                value: maxPlayers,
                dropdownColor: Colors.grey[800],
                style: const TextStyle(color: Colors.white),
                items: [2, 3, 4].map((n) {
                  return DropdownMenuItem(value: n, child: Text('$n'));
                }).toList(),
                onChanged: (value) => setState(() => maxPlayers = value!),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.socket.emit('create-room', {
              'map_name': selectedMap,
              'game_mode': selectedMode,
              'max_players': maxPlayers,
            });
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('Create'),
        ),
      ],
    );
  }
}