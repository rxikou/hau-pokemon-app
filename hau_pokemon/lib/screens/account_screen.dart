import 'package:flutter/material.dart';

import '../models/player.dart';
import '../services/player_service.dart';
import '../services/player_session.dart';
import '../widgets/app_drawer.dart';
import 'login_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _service = PlayerService();

  Player? _player;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final id = PlayerSession.currentPlayerId ?? await _service.getCurrentPlayerId();
    if (id == null) {
      if (!mounted) return;
      setState(() {
        _player = null;
        _loading = false;
      });
      return;
    }

    final players = await _service.getPlayers();
    Player? player;
    for (final p in players) {
      if (p.id == id) {
        player = p;
        break;
      }
    }

    if (!mounted) return;
    setState(() {
      _player = player;
      _loading = false;
    });
  }

  Future<void> _logout() async {
    await _service.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Account'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: scheme.primary))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: scheme.primary.withValues(alpha: 18),
                              border: Border.all(color: scheme.primary.withValues(alpha: 51)),
                            ),
                            child: Icon(Icons.person, color: scheme.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _player?.username ?? 'Not signed in',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _player == null ? 'Please login or register.' : 'Player ID: ${_player!.id}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _player == null ? null : _logout,
                    style: ElevatedButton.styleFrom(backgroundColor: scheme.error),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Logout'),
                  ),
                ],
              ),
            ),
    );
  }
}
