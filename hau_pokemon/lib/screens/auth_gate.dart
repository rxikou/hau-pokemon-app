import 'package:flutter/material.dart';

import '../services/player_service.dart';
import '../services/player_session.dart';
import 'admin_dashboard.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _service = PlayerService();

  bool _loading = true;
  int? _playerId;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final id = await _service.getCurrentPlayerId();
    PlayerSession.currentPlayerId = id;

    if (!mounted) return;
    setState(() {
      _playerId = id;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: scheme.primary)),
      );
    }

    if (_playerId == null) {
      return const LoginScreen();
    }

    return AdminDashboard(playerId: _playerId!);
  }
}
