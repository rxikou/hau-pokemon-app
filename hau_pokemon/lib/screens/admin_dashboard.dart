import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'leaderboard_screen.dart';
import 'about_us_screen.dart';
import 'map_screen.dart'; 
import 'add_monster_screen.dart';
import 'delete_monster_screen.dart';
import 'edit_monsters_list_screen.dart';
import '../widgets/app_drawer.dart';

class AdminDashboard extends StatefulWidget {
  final int playerId; // Passed from login

  const AdminDashboard({super.key, required this.playerId});

  @override
  State<AdminDashboard> createState() => AdminDashboardState();
}

class AdminDashboardState extends State<AdminDashboard> {
  List<Color> _dashboardTileColors(Color seed) {
    // Derive a stable, colorful palette from the theme seed (no global theme change).
    final base = HSLColor.fromColor(seed);
    const hues = <double>[55, 210, 320, 28, 270, 190];
    return hues
        .map(
          // Vibrant-but-pastel with enough depth for white text.
          (h) => base.withHue(h).withSaturation(0.70).withLightness(0.46).toColor(),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tileColors = _dashboardTileColors(scheme.primary);
    final tileForeground = scheme.onSurface;

    return Scaffold(
      drawer: AppDrawer(playerId: widget.playerId),
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome, Hunter',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Choose what you want to do next.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: scheme.outline.withValues(alpha: 26)),
                ),
                child: Text(
                  'Player ID: ${widget.playerId}',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 18),
            
            // Grid Menu
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildMenuCard(
                    context,
                    title: 'Catch Monsters',
                    icon: Icons.catching_pokemon,
                    backgroundColor: tileColors[0],
                    foregroundColor: tileForeground,
                    iconTurns: 0.5,
                    onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => MapScreen(playerId: widget.playerId)));
                    },
                  ),
                  _buildMenuCard(
                    context,
                    title: 'Add Monster',
                    icon: Icons.add_circle_outline,
                    backgroundColor: tileColors[1],
                    foregroundColor: tileForeground,
                    onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddMonsterScreen()));
                    },
                  ),
                  _buildMenuCard(
                    context,
                    title: 'Edit Monsters',
                    icon: Icons.edit_note_rounded,
                    backgroundColor: tileColors[2],
                    foregroundColor: tileForeground,
                    onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EditMonstersListScreen()));
                    },
                  ),
                  _buildMenuCard(
                    context,
                    title: 'Delete Monsters',
                    icon: Icons.delete_forever_rounded,
                    backgroundColor: tileColors[3],
                    foregroundColor: tileForeground,
                    onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DeleteMonsterScreen()));
                    },
                  ),
                  _buildMenuCard(
                    context,
                    title: 'Top Hunters',
                    icon: Icons.emoji_events_rounded,
                    backgroundColor: tileColors[4],
                    foregroundColor: tileForeground,
                    onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen()));
                    },
                  ),
                  _buildMenuCard(
                    context,
                    title: 'About Us',
                    icon: Icons.info_rounded,
                    backgroundColor: tileColors[5],
                    foregroundColor: tileForeground,
                    onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutUsScreen()));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color backgroundColor,
    required Color foregroundColor,
    double iconTurns = 0,
    required VoidCallback onTap,
  }) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.rotate(
                angle: iconTurns * 2 * math.pi,
                child: Icon(icon, size: 34, color: foregroundColor),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800, color: foregroundColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}