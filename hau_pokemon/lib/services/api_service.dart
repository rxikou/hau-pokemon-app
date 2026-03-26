import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/caught_monster.dart';
import '../utils/constants.dart';
import '../models/monster.dart';

class ApiService {

  static const Duration _timeout = Duration(seconds: 12);

  static String _stripTrailingSlashes(String value) => value.replaceAll(RegExp(r'/+$'), '');

  static String _stripLeadingSlashes(String value) => value.replaceAll(RegExp(r'^/+'), '');

  static List<String> _candidateBaseUrls() {
    final base = _stripTrailingSlashes(AppConstants.backendApiUrl);
    final bases = <String>[base];

    // If /api is reverse-proxied to a different upstream (e.g. Python), PHP files
    // might actually live at the server root. Try both to avoid hard coupling.
    if (base.toLowerCase().endsWith('/api')) {
      bases.add(base.substring(0, base.length - 4));
    }

    // De-dupe while preserving order.
    final seen = <String>{};
    return bases.where((b) => seen.add(b)).toList();
  }

  static Uri _endpointWithBase(String baseUrl, String path) {
    final b = _stripTrailingSlashes(baseUrl);
    final p = _stripLeadingSlashes(path);
    return Uri.parse('$b/$p');
  }

  static bool _isMissingRouteStatus(int statusCode) =>
      statusCode == 404 || statusCode == 405;

  static dynamic _tryDecodeJson(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    try {
      return json.decode(trimmed);
    } catch (_) {
      return null;
    }
  }

  static bool _isExplicitSuccess(dynamic decoded) {
    if (decoded is Map) {
      final value = decoded['success'] ?? decoded['ok'] ?? decoded['status'];
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final v = value.toLowerCase().trim();
        if (v == 'true' || v == 'ok' || v == 'success' || v == '1') return true;
        if (v == 'false' || v == 'error' || v == '0') return false;
      }
    }
    return true;
  }

  static String? _extractMessage(dynamic decoded) {
    if (decoded is Map) {
      final msg = decoded['message'] ?? decoded['error'] ?? decoded['detail'];
      if (msg != null) return msg.toString();
    }
    return null;
  }

  static List<Monster> _parseMonsters(dynamic decoded) {
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Monster.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    if (decoded is Map) {
      // Common wrapper: { "monsters": [ ... ] }
      final topLevelMonsters = decoded['monsters'];
      if (topLevelMonsters is List) {
        return topLevelMonsters
            .whereType<Map>()
            .map((e) => Monster.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      final data = decoded['data'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Monster.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      // Common wrapper: { "data": { "monsters": [ ... ] } }
      if (data is Map) {
        final nested = data['monsters'] ?? data['results'] ?? data['items'];
        if (nested is List) {
          return nested
              .whereType<Map>()
              .map((e) => Monster.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }

      // Some endpoints return a single monster object under `data`.
      if (data is Map) {
        return [Monster.fromJson(Map<String, dynamic>.from(data))];
      }

      // Some endpoints return a single monster object at the top level.
      // Heuristic: if it looks like a monster record, treat it as one.
      if (decoded.containsKey('monster_id') || decoded.containsKey('id')) {
        return [Monster.fromJson(Map<String, dynamic>.from(decoded))];
      }
    }

    throw const ApiException('Invalid monsters response format.');
  }
  
  // 1. Fetch all monsters for the map or management dashboard
  Future<List<Monster>> getMonsters() async {
    ApiException? lastError;
    ApiException? bestNonRouteError;
    final tried = <String>[];
    final attempts = <String>[];
    final candidates = <String>[
      'get_monsters.php',
      'get_monster.php',
      // optional REST fallback
      'monsters',
    ];

    for (final baseUrl in _candidateBaseUrls()) {
      for (final path in candidates) {
        final url = _endpointWithBase(baseUrl, path);
        tried.add(url.toString());
      try {
        final response = await http.get(url).timeout(_timeout);
        if (response.statusCode == 200) {
          final decoded = _tryDecodeJson(response.body);

          if (decoded == null) {
              attempts.add('${url.toString()} -> 200 (non-JSON)');
            throw ApiException(
              'Server returned non-JSON response.',
              url: url.toString(),
              statusCode: response.statusCode,
              body: response.body,
            );
          }

          if (decoded is Map && (decoded['success'] == false)) {
              attempts.add('${url.toString()} -> 200 (success:false)');
            throw ApiException(
              _extractMessage(decoded) ?? 'Server reported an error.',
              url: url.toString(),
              statusCode: response.statusCode,
              body: response.body,
            );
          }

            attempts.add('${url.toString()} -> 200 (ok)');
          try {
            return _parseMonsters(decoded);
          } on ApiException catch (e) {
            throw ApiException(
              e.message,
              url: url.toString(),
              statusCode: response.statusCode,
              body: response.body,
            );
          } catch (e) {
            throw ApiException(
              'Failed to parse monsters response: $e',
              url: url.toString(),
              statusCode: response.statusCode,
              body: response.body,
            );
          }
        }

        if (_isMissingRouteStatus(response.statusCode)) {
            attempts.add('${url.toString()} -> ${response.statusCode}');
          lastError = ApiException(
            'Endpoint not found.',
            url: url.toString(),
            statusCode: response.statusCode,
            body: response.body,
          );
          continue;
        }

          attempts.add('${url.toString()} -> ${response.statusCode}');
        final decoded = _tryDecodeJson(response.body);
        throw ApiException(
          _extractMessage(decoded) ?? 'Failed to load monsters.',
          url: url.toString(),
          statusCode: response.statusCode,
          body: response.body,
        );
      } on TimeoutException {
          attempts.add('${url.toString()} -> timeout');
        lastError = ApiException('Connection timeout. Is Tailscale ON?', url: url.toString());
          bestNonRouteError ??= lastError;
      } on SocketException {
          attempts.add('${url.toString()} -> socket error');
        lastError = ApiException('Connection error. Is Tailscale ON?', url: url.toString());
          bestNonRouteError ??= lastError;
      } on ApiException catch (e) {
          attempts.add('${url.toString()} -> ApiException: ${e.message}');
        lastError = e;

          // Prefer a non-route/parsing/backend error over a later 404/405.
          // This prevents "endpoint not found" from hiding the real issue.
          if (!_isMissingRouteStatus(e.statusCode ?? 0)) {
            bestNonRouteError ??= e;
          }
      } catch (e) {
        developer.log('API Error (getMonsters): $e', name: 'ApiService');
          attempts.add('${url.toString()} -> unexpected error');
          lastError = ApiException('API error while loading monsters: $e', url: url.toString());
          bestNonRouteError ??= lastError;
      }
      }
    }

    if (bestNonRouteError != null) {
      final details = attempts.isNotEmpty ? attempts.join(' | ') : tried.join(' | ');
      throw ApiException('${bestNonRouteError.message} Attempts: $details');
    }

    if (lastError != null && _isMissingRouteStatus(lastError.statusCode ?? 0)) {
      final details = attempts.isNotEmpty ? attempts.join(' | ') : tried.join(' | ');
      throw ApiException('Monsters endpoint not found. Attempts: $details');
    }

    throw lastError ?? const ApiException('Failed to load monsters.');
  }

  Future<bool> createMonster(Monster monster) async {
    final candidates = <String>['add_monster.php', 'monster', 'monsters'];
    final tried = <String>[];
    ApiException? lastError;

    final formBody = <String, String>{
      'monster_name': monster.name,
      'monster_type': monster.type,
      'spawn_latitude': monster.lat.toString(),
      'spawn_longitude': monster.lng.toString(),
      'spawn_radius_meters': monster.radius.toString(),
      if (monster.imageUrl != null) 'picture_url': monster.imageUrl!,
    };

    for (final baseUrl in _candidateBaseUrls()) {
      for (final path in candidates) {
        final url = _endpointWithBase(baseUrl, path);
        tried.add(url.toString());
        final isPhp = path.toLowerCase().endsWith('.php');
      try {
        final response = await http
            .post(
              url,
              headers: isPhp
                  ? const {'Content-Type': 'application/x-www-form-urlencoded'}
                  : const {'Content-Type': 'application/json'},
              body: isPhp ? formBody : json.encode(monster.toJson()),
            )
            .timeout(_timeout);

        if (response.statusCode == 200 || response.statusCode == 201) {
          final decoded = _tryDecodeJson(response.body);
          if (!_isExplicitSuccess(decoded)) {
            throw ApiException(
              _extractMessage(decoded) ?? 'Failed to save monster.',
              url: url.toString(),
              statusCode: response.statusCode,
              body: response.body,
            );
          }
          return true;
        }

        if (_isMissingRouteStatus(response.statusCode)) {
          lastError = ApiException(
            'Endpoint not found.',
            url: url.toString(),
            statusCode: response.statusCode,
            body: response.body,
          );
          continue;
        }

        final decoded = _tryDecodeJson(response.body);
        throw ApiException(
          _extractMessage(decoded) ?? 'Failed to save monster.',
          url: url.toString(),
          statusCode: response.statusCode,
          body: response.body,
        );
      } on TimeoutException {
        lastError = ApiException('Connection timeout. Is Tailscale ON?', url: url.toString());
      } on SocketException {
        lastError = ApiException('Connection error. Is Tailscale ON?', url: url.toString());
      } on ApiException catch (e) {
        lastError = e;
      } catch (e) {
        developer.log('API Error (createMonster): $e', name: 'ApiService');
        lastError = ApiException('API error while saving monster.', url: url.toString());
      }
      }
    }

    if (lastError != null && _isMissingRouteStatus(lastError.statusCode ?? 0)) {
      throw ApiException('Create endpoint not found. Tried: ${tried.join(' | ')}');
    }

    throw lastError ?? const ApiException('Failed to save monster.');
  }

  Future<bool> updateMonster(Monster monster) async {
    final id = monster.id;
    if (id == null) {
      throw const ApiException('Missing monster id.');
    }

    final candidates = <String>['update_monster.php', 'monster/$id', 'monsters/$id'];
    final tried = <String>[];
    ApiException? lastError;

    final formBody = <String, String>{
      'monster_id': id.toString(),
      'monster_name': monster.name,
      'monster_type': monster.type,
      'spawn_latitude': monster.lat.toString(),
      'spawn_longitude': monster.lng.toString(),
      'spawn_radius_meters': monster.radius.toString(),
      if (monster.imageUrl != null) 'picture_url': monster.imageUrl!,
    };

    for (final baseUrl in _candidateBaseUrls()) {
      for (final path in candidates) {
        final url = _endpointWithBase(baseUrl, path);
        tried.add(url.toString());
        final isPhp = path.toLowerCase().endsWith('.php');
      try {
        final response = await http
            .post(
              url,
              headers: isPhp
                  ? const {'Content-Type': 'application/x-www-form-urlencoded'}
                  : const {'Content-Type': 'application/json'},
              body: isPhp ? formBody : json.encode(monster.toJson()),
            )
            .timeout(_timeout);

        if (response.statusCode == 200) {
          final decoded = _tryDecodeJson(response.body);
          if (!_isExplicitSuccess(decoded)) {
            throw ApiException(
              _extractMessage(decoded) ?? 'Failed to update monster.',
              url: url.toString(),
              statusCode: response.statusCode,
              body: response.body,
            );
          }
          return true;
        }

        if (_isMissingRouteStatus(response.statusCode)) {
          lastError = ApiException(
            'Endpoint not found.',
            url: url.toString(),
            statusCode: response.statusCode,
            body: response.body,
          );
          continue;
        }

        final decoded = _tryDecodeJson(response.body);
        throw ApiException(
          _extractMessage(decoded) ?? 'Failed to update monster.',
          url: url.toString(),
          statusCode: response.statusCode,
          body: response.body,
        );
      } on TimeoutException {
        lastError = ApiException('Connection timeout. Is Tailscale ON?', url: url.toString());
      } on SocketException {
        lastError = ApiException('Connection error. Is Tailscale ON?', url: url.toString());
      } on ApiException catch (e) {
        lastError = e;
      } catch (e) {
        developer.log('API Error (updateMonster): $e', name: 'ApiService');
        lastError = ApiException('API error while updating monster.', url: url.toString());
      }
      }
    }

    if (lastError != null && _isMissingRouteStatus(lastError.statusCode ?? 0)) {
      throw ApiException('Update endpoint not found. Tried: ${tried.join(' | ')}');
    }

    throw lastError ?? const ApiException('Failed to update monster.');
  }

  Future<bool> deleteMonster(int? id) async {
    if (id == null) {
      throw const ApiException('Missing monster id.');
    }

    final candidates = <String>['delete_monster.php', 'monster/$id', 'monsters/$id'];
    final tried = <String>[];
    ApiException? lastError;

    final formBody = <String, String>{
      'monster_id': id.toString(),
    };

    for (final baseUrl in _candidateBaseUrls()) {
      for (final path in candidates) {
        final url = _endpointWithBase(baseUrl, path);
        tried.add(url.toString());
        final isPhp = path.toLowerCase().endsWith('.php');
      try {
        final response = isPhp
            ? await http
                .post(
                  url,
                  headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
                  body: formBody,
                )
                .timeout(_timeout)
            : await http.delete(url).timeout(_timeout);

        if (response.statusCode == 200 || response.statusCode == 204) {
          final decoded = _tryDecodeJson(response.body);
          if (!_isExplicitSuccess(decoded)) {
            throw ApiException(
              _extractMessage(decoded) ?? 'Failed to delete monster.',
              url: url.toString(),
              statusCode: response.statusCode,
              body: response.body,
            );
          }
          return true;
        }

        if (_isMissingRouteStatus(response.statusCode)) {
          lastError = ApiException(
            'Endpoint not found.',
            url: url.toString(),
            statusCode: response.statusCode,
            body: response.body,
          );
          continue;
        }

        final decoded = _tryDecodeJson(response.body);
        throw ApiException(
          _extractMessage(decoded) ?? 'Failed to delete monster.',
          url: url.toString(),
          statusCode: response.statusCode,
          body: response.body,
        );
      } on TimeoutException {
        lastError = ApiException('Connection timeout. Is Tailscale ON?', url: url.toString());
      } on SocketException {
        lastError = ApiException('Connection error. Is Tailscale ON?', url: url.toString());
      } on ApiException catch (e) {
        lastError = e;
      } catch (e) {
        developer.log('API Error (deleteMonster): $e', name: 'ApiService');
        lastError = ApiException('API error while deleting monster.', url: url.toString());
      }
      }
    }

    if (lastError != null && _isMissingRouteStatus(lastError.statusCode ?? 0)) {
      throw ApiException('Delete endpoint not found. Tried: ${tried.join(' | ')}');
    }

    throw lastError ?? const ApiException('Failed to delete monster.');
  }

  // 2. Catch a monster and persist to monster_catchestbl via PHP API
  Future<Map<String, dynamic>> catchMonster(
    int playerId,
    double lat,
    double lng, {
    int? monsterId,
    int? locationId,
  }) async {
    final candidates = <String>['catch_monster.php', 'catch', 'catch.php'];
    final tried = <String>[];
    String? lastConnectivityError;

    // Use form-encoded body because PHP endpoints read from $_POST.
    final formBody = <String, String>{
      'player_id': playerId.toString(),
      'latitude': lat.toString(),
      'longitude': lng.toString(),
      'lat': lat.toString(),
      'lng': lng.toString(),
      if (monsterId != null) 'monster_id': monsterId.toString(),
      if (locationId != null) 'location_id': locationId.toString(),
    };

    for (final baseUrl in _candidateBaseUrls()) {
      for (final path in candidates) {
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
                body: formBody,
              )
              .timeout(_timeout);

          if (response.statusCode == 200) {
            final decoded = _tryDecodeJson(response.body);
            if (decoded is Map) {
              return Map<String, dynamic>.from(decoded);
            }
            return {
              'success': false,
              'message': 'Server returned non-JSON response. URL: ${url.toString()}',
            };
          }

          if (_isMissingRouteStatus(response.statusCode)) {
            continue;
          }

          final decoded = _tryDecodeJson(response.body);
          final msg = _extractMessage(decoded) ??
              'Server error. Status: ${response.statusCode}. URL: ${url.toString()}';
          return {'success': false, 'message': msg};
        } on TimeoutException {
          lastConnectivityError = 'Connection timeout. Is Tailscale ON?';
          // try next candidate
          continue;
        } on SocketException {
          lastConnectivityError = 'Connection error. Is Tailscale ON?';
          // try next candidate
          continue;
        } catch (e) {
          developer.log('API Error (catchMonster): $e', name: 'ApiService');
          return {
            'success': false,
            'message': 'API error while catching monster: $e',
          };
        }
      }
    }

    return {
      'success': false,
      'message': '${lastConnectivityError ?? 'Catch endpoint not reachable.'} Tried: ${tried.join(' | ')}',
    };
  }

  // 3. Fetch caught monsters for a specific player
  Future<List<CaughtMonster>> getPlayerInventory(int playerId) async {
    final candidates = <String>['player_inventory.php', 'player_inventory'];
    final tried = <String>[];
    ApiException? lastError;

    final formBody = <String, String>{
      'player_id': playerId.toString(),
    };

    for (final baseUrl in _candidateBaseUrls()) {
      for (final path in candidates) {
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
                body: formBody,
              )
              .timeout(_timeout);

          if (response.statusCode == 200) {
            final decoded = _tryDecodeJson(response.body);

            if (decoded == null) {
              throw ApiException(
                'Server returned non-JSON response.',
                url: url.toString(),
                statusCode: response.statusCode,
                body: response.body,
              );
            }

            if (decoded is Map && decoded['success'] == false) {
              throw ApiException(
                _extractMessage(decoded) ?? 'Failed to load inventory.',
                url: url.toString(),
                statusCode: response.statusCode,
                body: response.body,
              );
            }

            dynamic listLike;
            if (decoded is Map) {
              listLike = decoded['data'] ?? decoded['inventory'] ?? decoded['items'];
            } else {
              listLike = decoded;
            }

            if (listLike is List) {
              return listLike
                  .whereType<Map>()
                  .map((e) => CaughtMonster.fromJson(Map<String, dynamic>.from(e)))
                  .toList();
            }

            throw ApiException(
              'Invalid inventory response format.',
              url: url.toString(),
              statusCode: response.statusCode,
              body: response.body,
            );
          }

          if (_isMissingRouteStatus(response.statusCode)) {
            lastError = ApiException(
              'Endpoint not found.',
              url: url.toString(),
              statusCode: response.statusCode,
              body: response.body,
            );
            continue;
          }

          final decoded = _tryDecodeJson(response.body);
          throw ApiException(
            _extractMessage(decoded) ?? 'Failed to load inventory.',
            url: url.toString(),
            statusCode: response.statusCode,
            body: response.body,
          );
        } on TimeoutException {
          lastError = ApiException('Connection timeout. Is Tailscale ON?', url: url.toString());
        } on SocketException {
          lastError = ApiException('Connection error. Is Tailscale ON?', url: url.toString());
        } on ApiException catch (e) {
          lastError = e;
        } catch (e) {
          developer.log('API Error (getPlayerInventory): $e', name: 'ApiService');
          lastError = ApiException('API error while loading inventory.', url: url.toString());
        }
      }
    }

    if (lastError != null && _isMissingRouteStatus(lastError.statusCode ?? 0)) {
      throw ApiException('Inventory endpoint not found. Tried: ${tried.join(' | ')}');
    }

    throw lastError ?? const ApiException('Failed to load inventory.');
  }

  // 4. Fetch Top 10 Leaderboard
  Future<List<dynamic>> getLeaderboard() async {
    final candidates = <String>['leaderboard.php', 'leaderboard'];
    ApiException? lastError;

    for (final baseUrl in _candidateBaseUrls()) {
      for (final path in candidates) {
        final url = _endpointWithBase(baseUrl, path);
        try {
          final response = await http.get(url).timeout(_timeout);

          if (response.statusCode == 200) {
            final decoded = _tryDecodeJson(response.body);
            if (decoded == null) {
              throw ApiException(
                'Server returned non-JSON response.',
                url: url.toString(),
                statusCode: response.statusCode,
                body: response.body,
              );
            }

            if (decoded is Map && decoded['success'] == false) {
              throw ApiException(
                _extractMessage(decoded) ?? 'Failed to load leaderboard.',
                url: url.toString(),
                statusCode: response.statusCode,
                body: response.body,
              );
            }

            dynamic listLike;
            if (decoded is Map) {
              listLike = decoded['data'] ?? decoded['leaderboard'] ?? decoded['items'];
            } else {
              listLike = decoded;
            }

            if (listLike is List) {
              return listLike;
            }

            throw ApiException(
              'Invalid leaderboard response format.',
              url: url.toString(),
              statusCode: response.statusCode,
              body: response.body,
            );
          }

          if (_isMissingRouteStatus(response.statusCode)) {
            lastError = ApiException(
              'Endpoint not found.',
              url: url.toString(),
              statusCode: response.statusCode,
              body: response.body,
            );
            continue;
          }

          final decoded = _tryDecodeJson(response.body);
          throw ApiException(
            _extractMessage(decoded) ?? 'Failed to load leaderboard.',
            url: url.toString(),
            statusCode: response.statusCode,
            body: response.body,
          );
        } on TimeoutException {
          lastError = ApiException('Connection timeout. Is Tailscale ON?', url: url.toString());
        } on SocketException {
          lastError = ApiException('Connection error. Is Tailscale ON?', url: url.toString());
        } on ApiException catch (e) {
          lastError = e;
        } catch (e) {
          developer.log('API Error (getLeaderboard): $e', name: 'ApiService');
          lastError = ApiException('API error while loading leaderboard.', url: url.toString());
        }
      }
    }

    throw lastError ?? const ApiException('Failed to load leaderboard.');
  }
}

class ApiException implements Exception {
  final String message;
  final String? url;
  final int? statusCode;
  final String? body;

  const ApiException(this.message, {this.url, this.statusCode, this.body});

  @override
  String toString() {
    final parts = <String>[message];
    if (statusCode != null) parts.add('Status: $statusCode');
    if (url != null) parts.add('URL: $url');

    final rawBody = body;
    if (rawBody != null) {
      final trimmed = rawBody.trim();
      if (trimmed.isNotEmpty) {
        final normalized = trimmed.replaceAll(RegExp(r'\s+'), ' ');
        final snippet = normalized.length <= 200
            ? normalized
            : '${normalized.substring(0, 200)}...';
        parts.add('Body: $snippet');
      }
    }

    return parts.join(' | ');
  }
}