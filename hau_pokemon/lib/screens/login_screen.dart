import 'package:flutter/material.dart';

import '../services/player_service.dart';
import 'admin_dashboard.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _service = PlayerService();
  late final AnimationController _spinController;
  late final Animation<double> _spinTurns;

  bool _isLoading = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    _spinTurns = CurvedAnimation(parent: _spinController, curve: Curves.linear);
  }

  @override
  void dispose() {
    _spinController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      final player = await _service.login(
        username: _usernameController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => AdminDashboard(playerId: player.id)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  SizedBox(
                    height: 220,
                    child: Center(
                      child: RotationTransition(
                        turns: _spinTurns,
                        child: const _PokeballLogo(size: 170),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Welcome back',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in to continue hunting',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscure,
                    onSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: _obscure ? 'Show password' : 'Hide password',
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Login'),
                  ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const RegisterScreen()),
                              );
                            },
                      child: const Text('Create an account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PokeballLogo extends StatelessWidget {
  final double size;

  const _PokeballLogo({
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        clipBehavior: Clip.hardEdge,
        child: CustomPaint(
          painter: _PokeballPainter(),
        ),
      ),
    );
  }
}

class _PokeballPainter extends CustomPainter {
  const _PokeballPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const outlineColor = Colors.black;
    const topColor = Color(0xFFE53935);

    final strokeWidth = size.width * 0.06;
    final inset = (strokeWidth / 2) + 1;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - inset;
    final ballRect = Rect.fromCircle(center: center, radius: radius);
    final ballPath = Path()..addOval(ballRect);

    final borderPaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..isAntiAlias = false
      ..strokeWidth = strokeWidth;

    final redPaint = Paint()
      ..color = topColor
      ..isAntiAlias = false;
    final whitePaint = Paint()
      ..color = Colors.white
      ..isAntiAlias = false;

    canvas.save();
    canvas.clipPath(ballPath);
    canvas.drawCircle(center, radius, whitePaint);
    canvas.drawRect(
      Rect.fromLTWH(ballRect.left, ballRect.top, ballRect.width, ballRect.height / 2),
      redPaint,
    );

    final bandPaint = Paint()
      ..color = outlineColor
      ..isAntiAlias = false
      ..style = PaintingStyle.fill;

    final bandHeight = size.height * 0.12;
    final bandRect = Rect.fromCenter(
      center: center,
      width: radius * 2,
      height: bandHeight,
    );
    canvas.drawRect(bandRect, bandPaint);

    final coreOuterPaint = Paint()
      ..color = outlineColor
      ..isAntiAlias = false;
    final coreInnerPaint = Paint()
      ..color = Colors.white
      ..isAntiAlias = false;

    canvas.drawCircle(center, size.width * 0.16, coreOuterPaint);
    canvas.drawCircle(center, size.width * 0.09, coreInnerPaint);
    canvas.restore();

    canvas.drawCircle(center, radius - borderPaint.strokeWidth / 2, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _PokeballPainter oldDelegate) {
    return false;
  }
}
