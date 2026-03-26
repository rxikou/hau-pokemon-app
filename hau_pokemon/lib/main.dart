import 'package:flutter/material.dart';

import 'services/theme_controller.dart';
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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.instance.mode,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'HAUPokemon',
          themeMode: mode,
          theme: PokedexTheme.light(),
          darkTheme: PokedexTheme.dark(),
          builder: (context, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: isDark
                    ? PokedexTheme.backgroundGradient
                    : PokedexTheme.backgroundGradientLight,
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: home ?? const SplashScreen(),
        );
      },
    );
  }
}
