import 'package:flutter/material.dart';

import '../widgets/app_drawer.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final members = <({String name, String role})>[
      (name: 'Seane Karl S. Garcia', role: 'Mobile App Lead Developer'),
      (name: 'Adrian John C. Alfonso', role: 'Cloud Architect'),
      (name: 'Laurenzo S. Centeno', role: 'Documentation'),
      (name: 'John Michael Y. Supan', role: 'QA Lead'),
    ];

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('About Us'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [
                    scheme.primaryContainer,
                    scheme.surfaceContainerHighest,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  const _PokeballBadge(size: 72),
                  const SizedBox(height: 12),
                  Text(
                    'HAUPokemon Engine',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cloud-connected location-based monster hunting platform',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Project Team',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 12),
                    for (final member in members)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: scheme.surfaceContainerHighest.withValues(alpha: 128),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.person_pin_circle_rounded, color: scheme.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      member.name,
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      member.role,
                                      style: TextStyle(color: scheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PokeballBadge extends StatelessWidget {
  final double size;

  const _PokeballBadge({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        clipBehavior: Clip.hardEdge,
        child: CustomPaint(
          painter: _PokeballBadgePainter(),
        ),
      ),
    );
  }
}

class _PokeballBadgePainter extends CustomPainter {
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
      ..strokeWidth = strokeWidth;

    final redPaint = Paint()..color = topColor;
    final whitePaint = Paint()..color = Colors.white;

    canvas.save();
    canvas.clipPath(ballPath);
    canvas.drawCircle(center, radius, whitePaint);
    canvas.drawRect(
      Rect.fromLTWH(ballRect.left, ballRect.top, ballRect.width, ballRect.height / 2),
      redPaint,
    );

    final bandHeight = size.height * 0.12;
    final bandRect = Rect.fromCenter(
      center: center,
      width: radius * 2,
      height: bandHeight,
    );
    canvas.drawRect(bandRect, Paint()..color = outlineColor);

    canvas.drawCircle(center, size.width * 0.16, Paint()..color = outlineColor);
    canvas.drawCircle(center, size.width * 0.09, Paint()..color = Colors.white);
    canvas.restore();

    canvas.drawCircle(center, radius - borderPaint.strokeWidth / 2, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _PokeballBadgePainter oldDelegate) => false;
}