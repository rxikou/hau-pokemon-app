import 'package:flutter/material.dart';

import '../models/caught_monster.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';

class InventoryScreen extends StatefulWidget {
  final int playerId;

  const InventoryScreen({super.key, required this.playerId});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<CaughtMonster>> _inventoryFuture;

  @override
  void initState() {
    super.initState();
    _inventoryFuture = _apiService.getPlayerInventory(widget.playerId);
  }

  Future<void> _refresh() async {
    final future = _apiService.getPlayerInventory(widget.playerId);
    setState(() {
      _inventoryFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: AppDrawer(playerId: widget.playerId),
      appBar: AppBar(
        title: const Text('My Inventory'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<CaughtMonster>>(
        future: _inventoryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: scheme.primary));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error loading inventory:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final items = snapshot.data ?? const <CaughtMonster>[];
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No catches yet.\nGo to Catch Monsters and start hunting!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              final image = item.imageUrl?.trim();
              final hasNetworkImage = image != null && image.isNotEmpty;

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: scheme.surfaceContainerHighest,
                    backgroundImage: hasNetworkImage ? NetworkImage(image) : null,
                    child: hasNetworkImage
                        ? null
                        : Text(
                            item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                  ),
                  title: Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Type: ${item.type} • Catch ID: ${item.catchId}'),
                  trailing: Text(
                    '#${item.monsterId}',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
