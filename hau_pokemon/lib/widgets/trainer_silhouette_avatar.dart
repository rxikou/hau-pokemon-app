import 'package:flutter/material.dart';

class TrainerSilhouetteAvatar extends StatelessWidget {
  final double size;
  final Color? backgroundColor;
  final Color? silhouetteColor;
  final Color? borderColor;

  const TrainerSilhouetteAvatar({
    super.key,
    this.size = 56,
    this.backgroundColor,
    this.silhouetteColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = backgroundColor ?? scheme.primaryContainer.withValues(alpha: 140);
    final fg = silhouetteColor ?? const Color(0xFF1B1B1F);
    final stroke = borderColor ?? scheme.primary.withValues(alpha: 51);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            bg.withValues(alpha: 210),
            bg.withValues(alpha: 130),
          ],
        ),
        border: Border.all(color: stroke),
      ),
      child: CustomPaint(
        painter: _TrainerSilhouettePainter(color: fg),
      ),
    );
  }
}

class _TrainerSilhouettePainter extends CustomPainter {
  final Color color;

  const _TrainerSilhouettePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    final w = size.width;
    final h = size.height;

    // Shoulders / torso
    final torsoRect = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.78),
      width: w * 0.62,
      height: h * 0.38,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(torsoRect, Radius.circular(w * 0.14)),
      paint,
    );

    // Neck
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.56),
          width: w * 0.14,
          height: h * 0.12,
        ),
        Radius.circular(w * 0.04),
      ),
      paint,
    );

    // Head
    canvas.drawCircle(Offset(w * 0.5, h * 0.42), w * 0.16, paint);

    // Cap crown
    final crownPath = Path()
      ..moveTo(w * 0.32, h * 0.34)
      ..quadraticBezierTo(w * 0.50, h * 0.20, w * 0.68, h * 0.34)
      ..lineTo(w * 0.66, h * 0.40)
      ..quadraticBezierTo(w * 0.50, h * 0.33, w * 0.34, h * 0.40)
      ..close();
    canvas.drawPath(crownPath, paint);

    // Cap brim
    final brimRect = Rect.fromCenter(
      center: Offset(w * 0.58, h * 0.39),
      width: w * 0.30,
      height: h * 0.08,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(brimRect, Radius.circular(w * 0.04)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _TrainerSilhouettePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
