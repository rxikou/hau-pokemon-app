import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/player.dart';
import 'player_session.dart';

class PlayerService {
  static const _playersKey = 'players_v1';
  static const _currentPlayerIdKey = 'current_player_id_v1';

  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<List<Player>> getPlayers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_playersKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = json.decode(raw);
    if (decoded is! List) return [];

    return decoded
        .whereType<Map>()
        .map((e) => Player.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<void> _savePlayers(List<Player> players) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = json.encode(players.map((p) => p.toJson()).toList());
    await prefs.setString(_playersKey, raw);
  }

  Future<int> _nextId(List<Player> players) async {
    if (players.isEmpty) return 1;
    final maxId = players.map((p) => p.id).reduce((a, b) => a > b ? a : b);
    return maxId + 1;
  }

  Future<Player> register({required String username, required String password}) async {
    final normalized = username.trim();
    if (normalized.isEmpty) {
      throw Exception('Username is required.');
    }
    if (password.length < 4) {
      throw Exception('Password must be at least 4 characters.');
    }

    final players = await getPlayers();
    final exists = players.any((p) => p.username.toLowerCase() == normalized.toLowerCase());
    if (exists) {
      throw Exception('Username already exists.');
    }

    final player = Player(
      id: await _nextId(players),
      username: normalized,
      passwordHash: hashPassword(password),
    );

    await _savePlayers([...players, player]);
    await setCurrentPlayerId(player.id);

    return player;
  }

  Future<Player> login({required String username, required String password}) async {
    final normalized = username.trim();
    final players = await getPlayers();

    final hash = hashPassword(password);
    final match = players.where((p) => p.username.toLowerCase() == normalized.toLowerCase()).toList();
    if (match.isEmpty) {
      throw Exception('Account not found.');
    }

    final player = match.first;
    if (player.passwordHash != hash) {
      throw Exception('Incorrect password.');
    }

    await setCurrentPlayerId(player.id);
    return player;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentPlayerIdKey);
    PlayerSession.currentPlayerId = null;
  }

  Future<int?> getCurrentPlayerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_currentPlayerIdKey);
  }

  Future<void> setCurrentPlayerId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currentPlayerIdKey, id);
    PlayerSession.currentPlayerId = id;
  }

  Future<Player> createPlayer({required String username, required String password}) async {
    return register(username: username, password: password);
  }

  Future<Player> updatePlayer({
    required int id,
    required String username,
    String? newPassword,
  }) async {
    final normalized = username.trim();
    if (normalized.isEmpty) {
      throw Exception('Username is required.');
    }

    final players = await getPlayers();

    final duplicate = players.any(
      (p) => p.id != id && p.username.toLowerCase() == normalized.toLowerCase(),
    );
    if (duplicate) {
      throw Exception('Username already exists.');
    }

    final idx = players.indexWhere((p) => p.id == id);
    if (idx < 0) {
      throw Exception('Player not found.');
    }

    final existing = players[idx];
    final updated = existing.copyWith(
      username: normalized,
      passwordHash: (newPassword != null && newPassword.isNotEmpty)
          ? hashPassword(newPassword)
          : existing.passwordHash,
    );

    final next = [...players]..[idx] = updated;
    await _savePlayers(next);

    return updated;
  }

  Future<void> deletePlayer(int id) async {
    final players = await getPlayers();
    final next = players.where((p) => p.id != id).toList();
    await _savePlayers(next);

    final current = await getCurrentPlayerId();
    if (current == id) {
      await logout();
    }
  }
}
