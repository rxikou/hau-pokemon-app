import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../models/monster.dart';

class ApiService {

  List<Monster> _mockMonsters() {
    return const [
      Monster(
        id: 1,
        name: "Uly",
        type: "Shark",
        lat: 15.1823162,
        lng: 120.5763874,
        radius: 100.0,
      ),
      Monster(
        id: 2,
        name: "Inferno",
        type: "Dragon",
        lat: 15.183000,
        lng: 120.577000,
        radius: 150.0,
      ),
      Monster(
        id: 3,
        name: "Rockbite",
        type: "Golem",
        lat: 15.181000,
        lng: 120.575000,
        radius: 80.0,
      ),
    ];
  }
  
  // 1. Fetch all monsters for the map or management dashboard
  Future<List<Monster>> getMonsters() async {
    try {
      final response = await http.get(Uri.parse('${AppConstants.backendApiUrl}/monsters'));
      
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body);
        return jsonResponse.map((data) => Monster.fromJson(data)).toList();
      } else {
        return _mockMonsters();
      }
    } catch (e) {
      developer.log('API Error (getMonsters): $e', name: 'ApiService');
      return _mockMonsters();
    }
  }

  // 4. MOCK DELETE MONSTER
  Future<bool> deleteMonster(int? id) async {
    if (id == null) return false;
    developer.log('MOCK API: Sending DELETE request for monster ID: $id', name: 'ApiService');
    await Future.delayed(const Duration(seconds: 1)); // Simulate network
    return true; // Simulate a successful deletion
  }

  // 2. The Catch Logic (Sends GPS to Python backend)
  Future<Map<String, dynamic>> catchMonster(int playerId, double lat, double lng) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.backendApiUrl}/catch'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          'player_id': playerId,
          'latitude': lat,
          'longitude': lng,
        }),
      );

      if (response.statusCode == 200) {
        // Expected response from Python: {"success": True, "message": "...", "monster_name": "Shark"}
        return json.decode(response.body); 
      }
      return {"success": false, "message": "Server error. Status: ${response.statusCode}"};
    } catch (e) {
      developer.log('API Error (catchMonster): $e', name: 'ApiService');
      // This is the error that triggers if Tailscale is disconnected
      return {"success": false, "message": "Connection timeout. Is Tailscale ON?"}; 
    }
  }

  // 3. Fetch Top 10 Leaderboard
  Future<List<dynamic>> getLeaderboard() async {
    try {
      final response = await http.get(Uri.parse('${AppConstants.backendApiUrl}/leaderboard'));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load leaderboard.');
      }
    } catch (e) {
      developer.log('API Error (getLeaderboard): $e', name: 'ApiService');
      return [];
    }
  }
}