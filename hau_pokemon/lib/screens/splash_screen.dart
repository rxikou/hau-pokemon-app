import 'package:flutter/material.dart';

import '../services/player_service.dart';
import '../services/player_session.dart';
import 'admin_dashboard.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  static const _splashDuration = Duration(seconds: 3);

  final _service = PlayerService();

  late final AnimationController _controller;
  late final Future<void> _startupFuture;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _startupFuture = _startup();
  }

  Future<void> _startup() async {
    final restoreFuture = _service.getCurrentPlayerId();
    await Future<void>.delayed(_splashDuration);

    final id = await restoreFuture;
    PlayerSession.currentPlayerId = id;

    if (!mounted) return;

    final next = (id == null) ? const LoginScreen() : AdminDashboard(playerId: id);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => next));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Touch _startupFuture so it starts even if build is re-run.
    // ignore: unused_local_variable
    final _ = _startupFuture;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RotationTransition(
              turns: _controller,
              child: Icon(
                Icons.catching_pokemon,
                size: 92,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Loading…',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
