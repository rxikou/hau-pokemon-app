import 'package:flutter/material.dart';
import '../models/caught_monster.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => LeaderboardScreenState();
}

class LeaderboardScreenState extends State<LeaderboardScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _leaderboardFuture;

  int? _parsePlayerId(Map<String, dynamic> hunter) {
    final raw = hunter['player_id'] ?? hunter['id'] ?? hunter['user_id'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  Future<void> _showHunterCatches({
    required int playerId,
    required String hunterName,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Text('$hunterName\'s Caught Monsters'),
          content: SizedBox(
            width: double.maxFinite,
            child: FutureBuilder<List<CaughtMonster>>(
              future: _apiService.getPlayerInventory(playerId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: CircularProgressIndicator(color: scheme.primary),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Text(
                    'Failed to load catches.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  );
                }

                final catches = snapshot.data ?? const <CaughtMonster>[];
                if (catches.isEmpty) {
                  return const Text(
                    'No catches found for this hunter yet.',
                    textAlign: TextAlign.center,
                  );
                }

                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: SizedBox(
                    width: 360,
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: catches.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final m = catches[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: scheme.primary.withValues(alpha: 30),
                            child: Icon(Icons.catching_pokemon, color: scheme.primary),
                          ),
                          title: Text(m.name),
                          subtitle: Text(m.type),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    // We call this in initState so it only fetches once when the screen loads,
    // rather than refetching every time the screen redraws.
    _leaderboardFuture = _apiService.getLeaderboard();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Top 10 Hunters'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Allows the user to manually refresh the leaderboard
              setState(() {
                _leaderboardFuture = _apiService.getLeaderboard();
              });
            },
          )
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _leaderboardFuture,
        builder: (context, snapshot) {
          // 1. Loading State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: scheme.primary));
          }
          
          // 2. Error State
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 16),
                  Text('Error loading leaderboard:\n${snapshot.error}', textAlign: TextAlign.center),
                ],
              ),
            );
          }

          // 3. Empty State (No catches yet)
          final hunters = snapshot.data ?? [];
          if (hunters.isEmpty) {
            return const Center(
              child: Text(
                'No monsters caught yet!\nBe the first to get on the board.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          // 4. Success State (Build the List)
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: hunters.length,
            itemBuilder: (context, index) {
              final hunter = hunters[index] is Map
                  ? Map<String, dynamic>.from(hunters[index] as Map)
                  : <String, dynamic>{};
              final playerName = (hunter['player_name'] ?? 'Unknown Hunter').toString();
              final playerId = _parsePlayerId(hunter);
              
              // Assign Medal Colors for Top 3
              Color medalColor = Colors.grey[300]!;
              Color textColor = Colors.black87;
              if (index == 0) { medalColor = Colors.amber; } // Gold
              if (index == 1) { medalColor = Colors.blueGrey[300]!; } // Silver
              if (index == 2) { medalColor = const Color(0xFFCD7F32); textColor = Colors.white; } // Bronze

              return Card(
                elevation: index < 3 ? 4 : 1, // Make top 3 pop out more
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  onTap: playerId == null
                      ? null
                      : () => _showHunterCatches(
                            playerId: playerId,
                            hunterName: playerName,
                          ),
                  leading: CircleAvatar(
                    backgroundColor: medalColor,
                    radius: 24,
                    child: Text(
                      '#${index + 1}', 
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)
                    ),
                  ),
                  title: Text(
                    playerName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                  ),
                  subtitle: Text(
                    playerId == null ? 'Details unavailable' : 'Tap to view caught monsters',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${hunter['total_catches'] ?? 0}', 
                        style: TextStyle(color: scheme.primary, fontSize: 22, fontWeight: FontWeight.bold)
                      ),
                      const Text('Catches', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}