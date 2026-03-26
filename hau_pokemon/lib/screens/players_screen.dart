import 'package:flutter/material.dart';

import '../models/player.dart';
import '../services/player_service.dart';
import '../widgets/app_drawer.dart';
import 'player_form_screen.dart';

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  final _service = PlayerService();

  bool _loading = true;
  List<Player> _players = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final players = await _service.getPlayers();
    if (!mounted) return;
    setState(() {
      _players = players;
      _loading = false;
    });
  }

  Future<void> _add() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PlayerFormScreen()),
    );
    await _load();
  }

  Future<void> _edit(Player player) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlayerFormScreen(player: player)),
    );
    await _load();
  }

  Future<void> _delete(Player player) async {
    final scheme = Theme.of(context).colorScheme;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Player'),
          content: Text('Delete account for ${player.username}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: scheme.error),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    await _service.deletePlayer(player.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${player.username} deleted.')),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Players'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        backgroundColor: scheme.primary,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: scheme.primary))
          : _players.isEmpty
              ? Center(
                  child: Text(
                    'No players yet.\nCreate an account from Register or add one here.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _players.length,
                  itemBuilder: (context, index) {
                    final p = _players[index];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: scheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.person_rounded,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          title: Text(
                            p.username,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          subtitle: Text('Player ID: ${p.id}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Edit',
                                onPressed: () => _edit(p),
                                icon: const Icon(Icons.edit_rounded),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: () => _delete(p),
                                icon: Icon(Icons.delete_forever_rounded, color: scheme.error),
                              ),
                            ],
                          ),
                          onTap: () => _edit(p),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
