import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// On-device text-to-speech (fast, works offline). The Flask /api/tts/speak
/// endpoint (Google Cloud TTS) is available as a higher-quality fallback
/// for languages/voices not well supported on-device.
class TtsService {
  static final FlutterTts _tts = FlutterTts();

  static const Map<String, String> _localeMap = {
    'en': 'en-IN',
    'ta': 'ta-IN',
    'hi': 'hi-IN',
  };

  static const Map<String, Map<String, String>> _translations = {
    // English labels mapped to translations
    'food': {
      'en': 'I am hungry, I want food.',
      'ta': 'எனக்கு பசிக்கிறது, சாப்பாடு வேண்டும்.',
      'hi': 'मुझे भूख लगी है, मुझे खाना चाहिए।',
    },
    'water': {
      'en': 'I am thirsty, I need water.',
      'ta': 'எனக்கு தாகமாக இருக்கிறது, தண்ணீர் வேண்டும்.',
      'hi': 'मुझे प्यास लगी है, मुझे पानी चाहिए।',
    },
    'medicine': {
      'en': 'I need my medicine.',
      'ta': 'எனக்கு மருந்து வேண்டும்.',
      'hi': 'मुझे दवा चाहिए।',
    },
    'restroom': {
      'en': 'I need to use the restroom.',
      'ta': 'எனக்கு கழிப்பறைக்கு செல்ல வேண்டும்.',
      'hi': 'मुझे शौचालय जाना है।',
    },
    'pain': {
      'en': 'I am in pain, I need help.',
      'ta': 'எனக்கு வலிக்கிறது, உதவி வேண்டும்.',
      'hi': 'मुझे दर्द हो रहा है, मुझे मदद चाहिए।',
    },
    'help': {
      'en': 'I need help right now.',
      'ta': 'எனக்கு இப்போது உதவி வேண்டும்.',
      'hi': 'मुझे अभी मदद चाहिए।',
    },
    'happy': {
      'en': 'I am feeling happy.',
      'ta': 'நான் மகிழ்ச்சியாக இருக்கிறேன்.',
      'hi': 'मैं खुश हूँ।',
    },
    'sad': {
      'en': 'I am feeling sad.',
      'ta': 'நான் சோகமாக இருக்கிறேன்.',
      'hi': 'मैं दुखी हूँ।',
    },
    'angry': {
      'en': 'I am feeling angry.',
      'ta': 'எனக்கு கோபமாக இருக்கிறது.',
      'hi': 'मुझे गुस्सा आ रहा है।',
    },
    'scared': {
      'en': 'I am feeling scared.',
      'ta': 'எனக்கு பயமாக இருக்கிறது.',
      'hi': 'मुझे डर लग रहा है।',
    },
    'tired': {
      'en': 'I am feeling tired.',
      'ta': 'நான் சோர்வாக இருக்கிறேன்.',
      'hi': 'मैं थका हुआ हूँ।',
    },
    'emergency': {
      'en': 'This is an emergency, I need immediate help.',
      'ta': 'இது அவசரநிலை, உடனடி உதவி தேவை.',
      'hi': 'यह एक आपातकाल है, मुझे तुरंत मदद चाहिए।',
    },

    // English full phrases also mapped directly to support direct fallback lookups
    'i am hungry, i want food.': {
      'en': 'I am hungry, I want food.',
      'ta': 'எனக்கு பசிக்கிறது, சாப்பாடு வேண்டும்.',
      'hi': 'मुझे भूख लगी है, मुझे खाना चाहिए।',
    },
    'i am thirsty, i need water.': {
      'en': 'I am thirsty, I need water.',
      'ta': 'எனக்கு தாகமாக இருக்கிறது, தண்ணீர் வேண்டும்.',
      'hi': 'मुझे प्यास लगी है, मुझे पानी चाहिए।',
    },
    'i need my medicine.': {
      'en': 'I need my medicine.',
      'ta': 'எனக்கு மருந்து வேண்டும்.',
      'hi': 'मुझे दवा चाहिए।',
    },
    'i need to use the restroom.': {
      'en': 'I need to use the restroom.',
      'ta': 'எனக்கு கழிப்பறைக்கு செல்ல வேண்டும்.',
      'hi': 'मुझे शौचालय जाना है।',
    },
    'i am in pain, i need help.': {
      'en': 'I am in pain, I need help.',
      'ta': 'எனக்கு வலிக்கிறது, உதவி வேண்டும்.',
      'hi': 'मुझे दर्द हो रहा है, मुझे मदद चाहिए।',
    },
    'i need help right now.': {
      'en': 'I need help right now.',
      'ta': 'எனக்கு இப்போது உதவி வேண்டும்.',
      'hi': 'मुझे अभी मदद चाहिए।',
    },
    'i am feeling happy.': {
      'en': 'I am feeling happy.',
      'ta': 'நான் மகிழ்ச்சியாக இருக்கிறேன்.',
      'hi': 'मैं खुश हूँ।',
    },
    'i am feeling sad.': {
      'en': 'I am feeling sad.',
      'ta': 'நான் சோகமாக இருக்கிறேன்.',
      'hi': 'मैं दुखी हूँ।',
    },
    'i am feeling angry.': {
      'en': 'I am feeling angry.',
      'ta': 'எனக்கு கோபமாக இருக்கிறது.',
      'hi': 'मुझे गुस्सा आ रहा है।',
    },
    'i am feeling scared.': {
      'en': 'I am feeling scared.',
      'ta': 'எனக்கு பயமாக இருக்கிறது.',
      'hi': 'मुझे डर लग रहा है।',
    },
    'i am feeling tired.': {
      'en': 'I am feeling tired.',
      'ta': 'நான் சோர்வாக இருக்கிறேன்.',
      'hi': 'मैं थका हुआ हूँ।',
    },
    'this is an emergency, i need immediate help.': {
      'en': 'This is an emergency, I need immediate help.',
      'ta': 'இது அவசரநிலை, உடனடி உதவி தேவை.',
      'hi': 'यह एक आपातकाल है, मुझे तुरंत मदद चाहिए।',
    },
    'sending emergency alert.': {
      'en': 'Sending emergency alert.',
      'ta': 'அவசர எச்சரிக்கை அனுப்பப்படுகிறது.',
      'hi': 'आपातकालीन चेतावनी भेजी जा रही है।',
    },
  };

  static Future<bool> speak(String text, String language) async {
    String locale = _localeMap[language] ?? 'en-IN';

    // Step 1: Query device standard available languages to dynamically resolve tag variations
    try {
      final List<dynamic>? availableLangs = await _tts.getLanguages;
      if (availableLangs != null) {
        final searchPrefix = language.toLowerCase();
        for (var lang in availableLangs) {
          if (lang is String) {
            final normalized = lang.replaceAll('_', '-').toLowerCase();
            if (normalized == searchPrefix || normalized.startsWith('$searchPrefix-')) {
              locale = lang; // Use matching system lang (e.g. 'ta_IN' or 'ta')
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("TtsService: Error fetching available languages: $e");
    }

    // Step 2: Validate if resolving locale is supported on the target device
    bool isAvailable = false;
    try {
      isAvailable = await _tts.isLanguageAvailable(locale);
    } catch (e) {
      debugPrint("TtsService: Error during language availability check: $e");
    }

    if (!isAvailable) {
      try {
        final List<dynamic>? availableList = await _tts.getLanguages;
        debugPrint("TtsService WARNING: Locale $locale ($language) is not supported/installed on this device.");
        debugPrint("Available system TTS languages: $availableList");
      } catch (_) {}
      return false; // Return false so calling screen can trigger SnackBar warning
    }

    try {
      await _tts.setLanguage(locale);
      await _tts.setSpeechRate(0.45); // slower, clearer speech for accessibility
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      // Dynamic translation lookup with normalized keys
      final String lookupKey = text.trim().toLowerCase();
      String speakText = text;
      if (_translations.containsKey(lookupKey)) {
        speakText = _translations[lookupKey]![language] ?? text;
      }

      await _tts.speak(speakText);
      return true;
    } catch (e) {
      debugPrint("TtsService ERROR: Failed to synthesize speech for $locale: $e");
      return false;
    }
  }

  static Future<void> stop() async => _tts.stop();
}
