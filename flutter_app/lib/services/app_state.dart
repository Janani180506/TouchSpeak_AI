import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Holds session-wide state: current user id, language, base API URL.
class AppState extends ChangeNotifier {
  String? userId; // set once during onboarding / profile creation
  String language = 'en'; // 'en' | 'ta' | 'hi'

  // Point this at your deployed Flask backend, e.g. http://localhost:5000/api
  static const String apiBaseUrl = 'http://10.0.2.2:5000/api';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('user_id');
    language = prefs.getString('language') ?? 'en';
    notifyListeners();

    if (userId == null) {
      await ensureProfileInitialized();
    }
  }

  Future<void> ensureProfileInitialized() async {
    try {
      final res = await ApiService.createUser(
        name: 'TouchSpeak User',
        preferredLanguage: language,
      );
      final id = res['_id'];
      if (id != null) {
        await setUser(id);
      }
    } catch (e) {
      debugPrint('AppState: Failed to initialize default user profile on backend: $e');
    }
  }

  Future<void> setUser(String id) async {
    userId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', id);
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', lang);
    notifyListeners();
  }
}

