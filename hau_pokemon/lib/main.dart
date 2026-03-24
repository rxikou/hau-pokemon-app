import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'theme/pokedex_theme.dart';

void main() {
  runApp(const HauPokemonApp());
}

class HauPokemonApp extends StatelessWidget {
  final Widget? home;

  const HauPokemonApp({super.key, this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HAUPokemon',
      theme: PokedexTheme.dark(),
      builder: (context, child) {
        return DecoratedBox(
          decoration: const BoxDecoration(gradient: PokedexTheme.backgroundGradient),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: home ?? const SplashScreen(),
    );
  }
}
