import 'package:flutter/material.dart';

import '../screens/account_screen.dart';
import '../screens/about_us_screen.dart';
import '../screens/add_monster_screen.dart';
import '../screens/admin_dashboard.dart';
import '../screens/delete_monster_screen.dart';
import '../screens/edit_monsters_list_screen.dart';
import '../screens/leaderboard_screen.dart';
import '../screens/map_screen.dart';
import '../screens/players_screen.dart';
import '../screens/server_control_screen.dart';
import '../services/player_session.dart';

class AppDrawer extends StatelessWidget {
  final int? playerId;

  const AppDrawer({super.key, this.playerId});

  void _go(BuildContext context, Widget page) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  int? _resolvedPlayerId() {
    return playerId ?? PlayerSession.currentPlayerId;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = <_DrawerEntry>[
      _DrawerEntry(
        icon: Icons.dashboard_rounded,
        label: 'Dashboard',
        onTap: () {
          final id = _resolvedPlayerId();
          if (id == null) return;
          _go(context, AdminDashboard(playerId: id));
        },
      ),
      _DrawerEntry(
        icon: Icons.person_rounded,
        label: 'Account',
        onTap: () => _go(context, const AccountScreen()),
      ),
      _DrawerEntry(
        icon: Icons.group_rounded,
        label: 'Players',
        onTap: () => _go(context, const PlayersScreen()),
      ),
      _DrawerEntry(
        icon: Icons.cloud_rounded,
        label: 'Paris EC2 Server',
        onTap: () => _go(context, const ServerControlScreen()),
      ),
      _DrawerEntry(
        icon: Icons.radar,
        label: 'Catch Monsters',
        onTap: () {
          final id = _resolvedPlayerId();
          if (id == null) return;
          _go(context, MapScreen(playerId: id));
        },
      ),
      _DrawerEntry(
        icon: Icons.add_circle_outline,
        label: 'Add Monster',
        onTap: () => _go(context, const AddMonsterScreen()),
      ),
      _DrawerEntry(
        icon: Icons.edit_rounded,
        label: 'Edit Monsters',
        onTap: () => _go(context, const EditMonstersListScreen()),
      ),
      _DrawerEntry(
        icon: Icons.delete_forever_rounded,
        label: 'Delete Monsters',
        onTap: () => _go(context, const DeleteMonsterScreen()),
      ),
      _DrawerEntry(
        icon: Icons.leaderboard_rounded,
        label: 'Top Hunters',
        onTap: () => _go(context, const LeaderboardScreen()),
      ),
      _DrawerEntry(
        icon: Icons.info_outline_rounded,
        label: 'About Us',
        onTap: () => _go(context, const AboutUsScreen()),
      ),
    ];

    return Drawer(
      backgroundColor: scheme.surface,
      child: SafeArea(
        child: _SidebarPanel(entries: entries),
      ),
    );
  }
}

class _DrawerEntry {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerEntry({required this.icon, required this.label, required this.onTap});
}

class _SidebarPanel extends StatelessWidget {
  final List<_DrawerEntry> entries;

  const _SidebarPanel({required this.entries});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final outline = scheme.outline.withValues(alpha: 26);
    final background = scheme.surfaceContainerHighest;

    final primary = entries.isEmpty ? null : entries.first;
    final rest = entries.length <= 1 ? const <_DrawerEntry>[] : entries.sublist(1);

    return Container(
      decoration: BoxDecoration(
        color: background,
        border: Border(
          right: BorderSide(color: outline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'HAUPokemon',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  tooltip: 'Account',
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AccountScreen()),
                    );
                  },
                  icon: Icon(Icons.settings_rounded, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (primary != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: _PrimaryDrawerButton(
                icon: Icons.auto_awesome_rounded,
                label: primary.label,
                onTap: primary.onTap,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            child: Text(
              'Menu',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              itemCount: rest.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final e = rest[index];
                return _SidebarItem(icon: e.icon, label: e.label, onTap: e.onTap);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryDrawerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PrimaryDrawerButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 26),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: scheme.onSurface),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SidebarItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
