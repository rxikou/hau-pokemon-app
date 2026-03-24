import 'package:flutter/material.dart';

import '../models/monster.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';

class DeleteMonsterScreen extends StatefulWidget {
  const DeleteMonsterScreen({super.key});

  @override
  State<DeleteMonsterScreen> createState() => _DeleteMonsterScreenState();
}

class _DeleteMonsterScreenState extends State<DeleteMonsterScreen> {
  final ApiService _apiService = ApiService();
  List<Monster> _monsters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMonsters();
  }

  // Fetch the list of monsters when the screen loads
  Future<void> _fetchMonsters() async {
    setState(() => _isLoading = true);
    try {
      final monsters = await _apiService.getMonsters();
      if (!mounted) return;
      setState(() {
        _monsters = monsters;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.toString() : 'Failed to load monsters.')),
      );
    }
  }

  // The Confirmation Dialog (Matches your screenshot)
  Future<void> _confirmDelete(Monster monster) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete Monster',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete ${monster.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: Colors.green)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[800],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    // If the user tapped 'Delete'
    if (confirm == true) {
      _executeDelete(monster);
    }
  }

  // The actual delete logic
  Future<void> _executeDelete(Monster monster) async {
    // Show a loading indicator in the snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleting ${monster.name}...')),
    );

    // Call the API
    bool success = false;
    try {
      success = await _apiService.deleteMonster(monster.id);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      return;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete monster.')),
      );
      return;
    }

    if (!mounted) return;

    if (success) {
      setState(() {
        // Remove the monster from the local UI list instantly
        _monsters.removeWhere((m) => m.id == monster.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${monster.name} deleted successfully!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete monster.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Delete Monsters'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: scheme.primary))
          : _monsters.isEmpty
              ? const Center(
                  child: Text(
                    'No monsters found.',
                    style: TextStyle(color: Colors.grey, fontSize: 18),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _monsters.length,
                  itemBuilder: (context, index) {
                    final monster = _monsters[index];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        // Placeholder for the monster image mentioned in your schema
                        leading: CircleAvatar(
                          backgroundColor: scheme.surfaceContainerHighest,
                          backgroundImage:
                              const AssetImage('assets/placeholder_monster.png'),
                          child: monster.name.isNotEmpty
                              ? Text(
                                  monster.name[0],
                                  style: TextStyle(color: scheme.onSurfaceVariant),
                                )
                              : null,
                        ),
                        title: Text(monster.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(monster.type),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () => _confirmDelete(monster),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
