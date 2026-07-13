import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_state.dart';

/// Thin wrapper around the TouchSpeak AI Flask REST API.
class ApiService {
  static Future<Map<String, dynamic>> selectIcon({
    required String userId,
    required String iconId,
    required String language,
  }) async {
    final res = await http.post(
      Uri.parse('${AppState.apiBaseUrl}/communication/select'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'icon_id': iconId, 'language': language}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getIcons() async {
    final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/communication/icons'));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getFrequentPhrases(String userId) async {
    final res = await http.get(
      Uri.parse('${AppState.apiBaseUrl}/communication/frequent/$userId'),
    );
    return jsonDecode(res.body) as List<dynamic>;
  }

  static Future<List<dynamic>> getPredictions(String userId) async {
    final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/predict/$userId'));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['predictions'] as List<dynamic>;
  }

  static Future<Map<String, dynamic>> triggerSOS({
    required String userId,
    required double lat,
    required double lng,
  }) async {
    final res = await http.post(
      Uri.parse('${AppState.apiBaseUrl}/emergency/sos'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'latitude': lat, 'longitude': lng}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> createUser({
    required String name,
    required String preferredLanguage,
  }) async {
    final res = await http.post(
      Uri.parse('${AppState.apiBaseUrl}/users'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'preferred_language': preferredLanguage}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
