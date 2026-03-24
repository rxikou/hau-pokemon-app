import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class EC2Service {
  EC2Service({String? statusUrl, String? toggleUrl})
      : _statusUrl = statusUrl ?? AppConstants.lambdaStatusUrl,
        _toggleUrl = toggleUrl ?? AppConstants.lambdaToggleUrl;

  final String _statusUrl;
  final String _toggleUrl;

  Uri get _statusUri => Uri.parse(_statusUrl);
  Uri get _toggleUri => Uri.parse(_toggleUrl);

  String _summarizeBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.length <= 160) return trimmed;
    return '${trimmed.substring(0, 160)}…';
  }

  String _httpError(http.Response response, {Uri? uri}) {
    // API Gateway often returns JSON like {"message":"Missing Authentication Token"}
    // when the invoke URL/path/stage is wrong.
    final body = response.body;
    try {
      final decoded = json.decode(body);
      if (decoded is Map && decoded['message'] is String) {
        final where = uri == null ? '' : ' (${uri.toString()})';
        return 'HTTP ${response.statusCode}: ${decoded['message']}$where';
      }
      if (decoded is Map && decoded['error'] is String) {
        final where = uri == null ? '' : ' (${uri.toString()})';
        return 'HTTP ${response.statusCode}: ${decoded['error']}$where';
      }
    } catch (_) {
      // non-JSON body
    }
    final summary = _summarizeBody(body);
    final where = uri == null ? '' : ' (${uri.toString()})';
    return summary.isEmpty
        ? 'HTTP ${response.statusCode}$where'
        : 'HTTP ${response.statusCode}: $summary$where';
  }

  // 1. Check current server status
  Future<String> checkStatus() async {
    try {
      // Prefer GET for status, but many HTTP APIs only define a POST route.
      // If GET fails (404/405/etc), fall back to a safe POST with empty JSON.
      http.Response response;
      try {
        response = await http.get(_statusUri).timeout(const Duration(seconds: 12));
      } catch (_) {
        // Will retry via POST below.
        response = http.Response('', 0);
      }

      if (response.statusCode != 200) {
        response = await http
            .post(
              _statusUri,
              headers: {"Content-Type": "application/json"},
              body: json.encode({}),
            )
            .timeout(const Duration(seconds: 12));
      }

      if (response.statusCode == 200) {
        final raw = response.body.trim();
        if (raw.isEmpty) return 'Unknown';

        // Common: {"status":"running"}
        try {
          final data = json.decode(raw);
          if (data is Map && data['status'] != null) {
            return '${data['status']}'.trim();
          }
          if (data is Map && data['state'] != null) {
            return '${data['state']}'.trim();
          }
        } catch (_) {
          // Some lambdas just return plain text like "running".
        }
        return raw;
      }
      return _httpError(response, uri: _statusUri);
    } on TimeoutException {
      return 'Network error: request timed out (${_statusUri.toString()})';
    } catch (e) {
      return 'Network error: $e (${_statusUri.toString()})';
    }
  }

  // 2. Send Start/Stop Commands
  Future<String> toggleServer(String action) async {
    try {
      final response = await http
          .post(
            _toggleUri,
            headers: {"Content-Type": "application/json"},
            body: json.encode({'action': action}),
          )
          .timeout(const Duration(seconds: 12));
      
      if (response.statusCode == 200) {
        // Prefer any returned message if present.
        final body = response.body.trim();
        if (body.isNotEmpty) {
          try {
            final decoded = json.decode(body);
            if (decoded is Map && decoded['message'] is String) {
              return '${decoded['message']}';
            }
          } catch (_) {
            // non-JSON body
          }
        }
        return "Command '$action' sent successfully. Wait a minute for EC2 to apply.";
      }
      return _httpError(response, uri: _toggleUri);
    } on TimeoutException {
      return 'Network error: request timed out (${_toggleUri.toString()})';
    } catch (e) {
      return 'Network error: $e (${_toggleUri.toString()})';
    }
  }
}