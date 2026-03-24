import 'package:flutter/material.dart';

import '../models/player.dart';
import '../services/player_service.dart';

class PlayerFormScreen extends StatefulWidget {
  final Player? player;

  const PlayerFormScreen({super.key, this.player});

  @override
  State<PlayerFormScreen> createState() => _PlayerFormScreenState();
}

class _PlayerFormScreenState extends State<PlayerFormScreen> {
  final _service = PlayerService();

  late final TextEditingController _usernameController;
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _obscure = true;

  bool get _isEdit => widget.player != null;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.player?.username ?? '');
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_loading) return;

    setState(() => _loading = true);
    try {
      if (_isEdit) {
        await _service.updatePlayer(
          id: widget.player!.id,
          username: _usernameController.text,
          newPassword: _passwordController.text.trim().isEmpty ? null : _passwordController.text,
        );
      } else {
        await _service.createPlayer(
          username: _usernameController.text,
          password: _passwordController.text,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Player' : 'Add Player')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _usernameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscure,
                        onSubmitted: (_) => _save(),
                        decoration: InputDecoration(
                          labelText: _isEdit ? 'New password (optional)' : 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _obscure ? 'Show password' : 'Hide password',
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _save,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEdit ? 'Save changes' : 'Create player'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _loading ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(foregroundColor: scheme.onSurface),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
