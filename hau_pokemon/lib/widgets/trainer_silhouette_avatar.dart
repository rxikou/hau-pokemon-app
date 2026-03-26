import 'package:flutter/material.dart';

class TrainerSilhouetteAvatar extends StatelessWidget {
  final double size;

  const TrainerSilhouetteAvatar({
    super.key,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: ClipOval(
        child: Image.asset(
          'assets/shawn_ketchum1.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
