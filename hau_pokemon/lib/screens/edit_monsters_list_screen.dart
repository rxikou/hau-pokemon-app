import 'package:flutter/material.dart';

import '../models/monster.dart';
import '../services/api_service.dart';
import 'edit_monster_screen.dart';
import '../widgets/app_drawer.dart';

class EditMonstersListScreen extends StatefulWidget {
  const EditMonstersListScreen({super.key});

  @override
  State<EditMonstersListScreen> createState() => _EditMonstersListScreenState();
}

class _EditMonstersListScreenState extends State<EditMonstersListScreen> {
  final ApiService _apiService = ApiService();
  List<Monster> _monsters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMonsters();
  }

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

  Future<void> _openEdit(Monster monster) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditMonsterScreen(monster: monster),
      ),
    );

    if (!mounted) return;
    await _fetchMonsters();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Edit Monsters'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchMonsters,
          )
        ],
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
                        leading: CircleAvatar(
                          backgroundColor: scheme.surfaceContainerHighest,
                          child: Transform.rotate(
                            angle: 3.141592653589793,
                            child: Icon(
                              Icons.catching_pokemon,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        title: Text(
                          monster.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(monster.type),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _openEdit(monster),
                        ),
                        onTap: () => _openEdit(monster),
                      ),
                    );
                  },
                ),
    );
  }
}
