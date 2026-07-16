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

  static Future<Map<String, dynamic>> getUser(String userId) async {
    final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/users/$userId'));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateUser({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    final res = await http.put(
      Uri.parse('${AppState.apiBaseUrl}/users/$userId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getEmergencyLogs(String userId) async {
    final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/emergency/logs/$userId'));
    return jsonDecode(res.body) as List<dynamic>;
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

  // --- Caregiver and Dynamic Board APIs ---

  static Future<List<dynamic>> getCategories() async {
    final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/communication/categories'));
    if (res.statusCode != 200) {
      throw Exception(jsonDecode(res.body)['error'] ?? 'Failed to load categories');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> createCategory(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('${AppState.apiBaseUrl}/communication/categories'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (res.statusCode != 201) {
      throw Exception(jsonDecode(res.body)['error'] ?? 'Failed to create category');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateCategory(String id, Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('${AppState.apiBaseUrl}/communication/categories/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (res.statusCode != 200) {
      throw Exception(jsonDecode(res.body)['error'] ?? 'Failed to update category');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> deleteCategory(String id) async {
    final res = await http.delete(Uri.parse('${AppState.apiBaseUrl}/communication/categories/$id'));
    if (res.statusCode != 200) {
      throw Exception(jsonDecode(res.body)['error'] ?? 'Failed to delete category');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getCards({String? categoryId, String? q}) async {
    String url = '${AppState.apiBaseUrl}/communication/cards';
    final params = <String>[];
    if (categoryId != null) params.add('category_id=$categoryId');
    if (q != null && q.isNotEmpty) params.add('q=${Uri.encodeComponent(q)}');
    if (params.isNotEmpty) {
      url += '?${params.join('&')}';
    }
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw Exception(jsonDecode(res.body)['error'] ?? 'Failed to load cards');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> createCard(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('${AppState.apiBaseUrl}/communication/cards'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (res.statusCode != 201) {
      throw Exception(jsonDecode(res.body)['error'] ?? 'Failed to create card');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateCard(String id, Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('${AppState.apiBaseUrl}/communication/cards/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (res.statusCode != 200) {
      throw Exception(jsonDecode(res.body)['error'] ?? 'Failed to update card');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> deleteCard(String id) async {
    final res = await http.delete(Uri.parse('${AppState.apiBaseUrl}/communication/cards/$id'));
    if (res.statusCode != 200) {
      throw Exception(jsonDecode(res.body)['error'] ?? 'Failed to delete card');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> reorderCards(List<String> cardIds) async {
    final res = await http.post(
      Uri.parse('${AppState.apiBaseUrl}/communication/cards/reorder'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'card_ids': cardIds}),
    );
    if (res.statusCode != 200) {
      throw Exception(jsonDecode(res.body)['error'] ?? 'Failed to reorder cards');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getFavorites(String userId) async {
    final res = await http.get(Uri.parse('${AppState.apiBaseUrl}/communication/favorites/$userId'));
    if (res.statusCode != 200) {
      throw Exception(jsonDecode(res.body)['error'] ?? 'Failed to load favorites');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> toggleFavorite({
    required String userId,
    required String cardId,
    required bool isFavorite,
  }) async {
    final res = await http.post(
      Uri.parse('${AppState.apiBaseUrl}/communication/favorites/$userId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'card_id': cardId, 'is_favorite': isFavorite}),
    );
    if (res.statusCode != 200) {
      throw Exception(jsonDecode(res.body)['error'] ?? 'Failed to set favorite');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> uploadImage(List<int> bytes, String filename) async {
    final uri = Uri.parse('${AppState.apiBaseUrl}/communication/upload-image');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: filename,
      ),
    );
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to upload image');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

