import 'package:flutter/material.dart';

/// Holds session-wide state: current user id, language, base API URL.
/// In production this would be persisted via shared_preferences after login/onboarding.
class AppState extends ChangeNotifier {
  String? userId; // set once during onboarding / profile creation
  String language = 'en'; // 'en' | 'ta' | 'hi'

  // Point this at your deployed Flask backend, e.g. https://api.touchspeak.app
  static const String apiBaseUrl = 'http://10.0.2.2:5000/api';

  void setUser(String id) {
    userId = id;
    notifyListeners();
  }

  void setLanguage(String lang) {
    language = lang;
    notifyListeners();
  }
}
