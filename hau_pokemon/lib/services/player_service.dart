import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/player.dart';
import '../utils/constants.dart';
import 'player_session.dart';

class PlayerService {
  static const _playersKey = 'players_v1';
  static const _currentPlayerIdKey = 'current_player_id_v1';
  static const Duration _timeout = Duration(seconds: 12);

  static String _stripTrailingSlashes(String value) => value.replaceAll(RegExp(r'/+$'), '');

  static String _stripLeadingSlashes(String value) => value.replaceAll(RegExp(r'^/+'), '');

  static List<String> _candidateBaseUrls() {
    final base = _stripTrailingSlashes(AppConstants.backendApiUrl);
    final bases = <String>[base];
    if (base.toLowerCase().endsWith('/api')) {
      bases.add(base.substring(0, base.length - 4));
    }
    final seen = <String>{};
    return bases.where((b) => seen.add(b)).toList();
  }

  static Uri _endpointWithBase(String baseUrl, String path) {
    final b = _stripTrailingSlashes(baseUrl);
    final p = _stripLeadingSlashes(path);
    return Uri.parse('$b/$p');
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _extractMessage(dynamic decoded) {
    if (decoded is Map) {
      final msg = decoded['message'] ?? decoded['error'] ?? decoded['detail'];
      if (msg != null) return msg.toString();
    }
    return null;
  }

  bool _isConnectivityFallbackMessage(String message) {
    return message.contains('endpoint not found') ||
        message.contains('connection error') ||
        message.contains('connection timeout') ||
        message.contains('tried:');
  }

  Future<Map<String, dynamic>> _postFormToCandidates({
    required List<String> paths,
    required Map<String, String> body,
  }) async {
    String? connectivityError;
    final tried = <String>[];

    for (final baseUrl in _candidateBaseUrls()) {
      for (final path in paths) {
        final url = _endpointWithBase(baseUrl, path);
        tried.add(url.toString());
        try {
          final response = await http
              .post(
                url,
                headers: const {
                  'Content-Type': 'application/x-www-form-urlencoded',
                  'Accept': 'application/json',
                },
                body: body,
              )
              .timeout(_timeout);

          dynamic decoded;
          try {
            decoded = json.decode(response.body);
          } catch (_) {
            decoded = null;
          }

          if (response.statusCode == 200) {
            if (decoded is Map) {
              return Map<String, dynamic>.from(decoded);
            }
            throw Exception('Server returned invalid response format.');
          }

          if (response.statusCode == 404 || response.statusCode == 405) {
            continue;
          }

          throw Exception(
            _extractMessage(decoded) ?? 'Server error. Status: ${response.statusCode}',
          );
        } on SocketException {
          connectivityError = 'Connection error. Is Tailscale ON?';
          continue;
        } on TimeoutException {
          connectivityError = 'Connection timeout. Is Tailscale ON?';
          continue;
        } on http.ClientException {
          connectivityError = 'Connection error. Is Tailscale ON?';
          continue;
        }
      }
    }

    throw Exception(
      '${connectivityError ?? 'Auth endpoint not found.'} Tried: ${tried.join(' | ')}',
    );
  }

  Future<void> _upsertLocalPlayer(Player player) async {
    final players = await getPlayers();
    // Keep a single local record per user identity to avoid stale duplicates
    // causing fallback login to compare against old password hashes.
    final next = players
        .where((p) => p.id != player.id && p.username.toLowerCase() != player.username.toLowerCase())
        .toList();
    final index = next.indexWhere((p) => p.id == player.id);
    if (index >= 0) {
      next[index] = player;
    } else {
      next.add(player);
    }
    await _savePlayers(next);

    if (PlayerSession.currentPlayerId == player.id) {
      PlayerSession.currentPlayerName = player.displayName;
    }
  }

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

  Future<Player> register({
    required String username,
    required String password,
    String? name,
  }) async {
    final normalized = username.trim();
    final normalizedName = (name ?? username).trim();
    if (normalized.isEmpty) {
      throw Exception('Username is required.');
    }
    if (normalizedName.isEmpty) {
      throw Exception('Name is required.');
    }
    if (password.length < 4) {
      throw Exception('Password must be at least 4 characters.');
    }

    try {
      final data = await _postFormToCandidates(
        paths: const ['register_player.php', 'register_player'],
        body: {
          'player_name': normalizedName,
          'username': normalized,
          'password': password,
        },
      );

      if (data['success'] == false) {
        throw Exception(_extractMessage(data) ?? 'Registration failed.');
      }

      final player = Player(
        id: _parseInt(data['player_id']),
        name: (data['player_name'] ?? normalizedName).toString(),
        username: (data['username'] ?? normalized).toString(),
        passwordHash: hashPassword(password),
      );

      if (player.id <= 0) {
        throw Exception('Registration succeeded but player_id is missing.');
      }

      await _upsertLocalPlayer(player);
      await setCurrentPlayerId(player.id);
      return player;
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '').toLowerCase();
      final canFallback = _isConnectivityFallbackMessage(message);

      if (!canFallback) rethrow;
    }

    final players = await getPlayers();
    final exists = players.any((p) => p.username.toLowerCase() == normalized.toLowerCase());
    if (exists) {
      throw Exception('Username already exists.');
    }

    final player = Player(
      id: await _nextId(players),
      name: normalizedName,
      username: normalized,
      passwordHash: hashPassword(password),
    );

    await _savePlayers([...players, player]);
    await setCurrentPlayerId(player.id);

    return player;
  }

  Future<Player> login({required String username, required String password}) async {
    final normalized = username.trim();
    if (normalized.isEmpty || password.isEmpty) {
      throw Exception('Username and password are required.');
    }

    try {
      final data = await _postFormToCandidates(
        paths: const ['login_player.php', 'login_player'],
        body: {
          'username': normalized,
          'password': password,
        },
      );

      if (data['success'] == false) {
        throw Exception(_extractMessage(data) ?? 'Login failed.');
      }

      final id = _parseInt(data['player_id']);
      if (id <= 0) {
        throw Exception('Login succeeded but player_id is missing.');
      }

      final displayName =
          (data['username'] ?? data['player_name'] ?? normalized).toString().trim();

      final player = Player(
        id: id,
        name: (data['player_name'] ?? data['name'] ?? displayName).toString(),
        username: (data['username'] ?? normalized).toString(),
        // Cache hash locally so fallback login still works when API is unreachable.
        passwordHash: hashPassword(password),
      );

      await _upsertLocalPlayer(player);
      await setCurrentPlayerId(player.id);
      return player;
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '').toLowerCase();
      final canFallback = _isConnectivityFallbackMessage(message);

      if (!canFallback) rethrow;
    }

    final players = await getPlayers();

    final hash = hashPassword(password);
    final match = players.where((p) => p.username.toLowerCase() == normalized.toLowerCase()).toList();
    if (match.isEmpty) {
      throw Exception('Account not found.');
    }

    final player = match.firstWhere(
      (p) => p.passwordHash == hash,
      orElse: () => match.first,
    );
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
    PlayerSession.currentPlayerName = null;
  }

  Future<int?> getCurrentPlayerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_currentPlayerIdKey);
  }

  Future<void> setCurrentPlayerId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currentPlayerIdKey, id);
    PlayerSession.currentPlayerId = id;

    final players = await getPlayers();
    final current = players.where((p) => p.id == id).cast<Player?>().firstWhere(
          (p) => p != null,
          orElse: () => null,
        );
    PlayerSession.currentPlayerName = current?.displayName;
  }

  Future<Player> createPlayer({
    required String username,
    required String password,
    String? name,
  }) async {
    return register(username: username, password: password, name: name);
  }

  Future<Player> updatePlayer({
    required int id,
    String? name,
    required String username,
    String? newPassword,
  }) async {
    final normalized = username.trim();
    final normalizedName = (name ?? username).trim();
    if (normalized.isEmpty) {
      throw Exception('Username is required.');
    }
    if (normalizedName.isEmpty) {
      throw Exception('Name is required.');
    }

    final players = await getPlayers();
    final existing = players.where((p) => p.id == id).cast<Player?>().firstWhere(
          (p) => p != null,
          orElse: () => null,
        );

    try {
      final body = <String, String>{
        'player_id': id.toString(),
        'player_name': normalizedName,
        'username': normalized,
      };
      if (newPassword != null && newPassword.isNotEmpty) {
        body['password'] = newPassword;
      }

      final data = await _postFormToCandidates(
        paths: const ['update_player.php', 'update_player'],
        body: body,
      );

      if (data['success'] == false) {
        throw Exception(_extractMessage(data) ?? 'Failed to update account.');
      }

      final updated = Player(
        id: _parseInt(data['player_id']) == 0 ? id : _parseInt(data['player_id']),
        name: (data['player_name'] ?? normalizedName).toString(),
        username: (data['username'] ?? normalized).toString(),
        passwordHash: (newPassword != null && newPassword.isNotEmpty)
            ? hashPassword(newPassword)
            : (existing?.passwordHash ?? ''),
      );

      await _upsertLocalPlayer(updated);
      return updated;
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '').toLowerCase();
      final canFallback = _isConnectivityFallbackMessage(message);
      if (!canFallback) rethrow;
    }

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

    final existingLocal = players[idx];
    final updated = existingLocal.copyWith(
      name: normalizedName,
      username: normalized,
      passwordHash: (newPassword != null && newPassword.isNotEmpty)
          ? hashPassword(newPassword)
          : existingLocal.passwordHash,
    );

    final next = [...players]..[idx] = updated;
    await _savePlayers(next);

    if (PlayerSession.currentPlayerId == updated.id) {
      PlayerSession.currentPlayerName = updated.displayName;
    }

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
