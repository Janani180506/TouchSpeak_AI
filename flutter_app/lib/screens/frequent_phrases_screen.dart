import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/api_service.dart';
import '../services/tts_service.dart';

class FrequentPhrasesScreen extends StatefulWidget {
  const FrequentPhrasesScreen({super.key});

  @override
  State<FrequentPhrasesScreen> createState() => _FrequentPhrasesScreenState();
}

class _FrequentPhrasesScreenState extends State<FrequentPhrasesScreen> {
  List<dynamic> _phrases = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = context.read<AppState>().userId;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final res = await ApiService.getFrequentPhrases(userId);
      setState(() {
        _phrases = res;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_phrases.isEmpty) {
      return const Center(child: Text('No phrases used yet. Start tapping icons!'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _phrases.length,
      itemBuilder: (context, i) {
        final p = _phrases[i] as Map<String, dynamic>;
        return Card(
          child: ListTile(
            leading: Icon(p['is_favorite'] == true ? Icons.star : Icons.chat_bubble_outline),
            title: Text(p['phrase_text'] ?? ''),
            subtitle: Text('Used ${p['use_count']} times'),
            trailing: IconButton(
              icon: const Icon(Icons.volume_up),
              onPressed: () async {
                final lang = context.read<AppState>().language;
                final speakSuccess = await TtsService.speak(
                  p['phrase_text'] ?? '',
                  lang,
                );
                if (!speakSuccess && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${lang.toUpperCase()} voice package is not installed/supported on this device. Please install it in system Text-To-Speech settings.',
                      ),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              },
            ),
          ),
        );
      },
    );
  }
}
