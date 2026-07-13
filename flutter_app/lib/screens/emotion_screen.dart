import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/api_service.dart';
import '../services/tts_service.dart';
import '../widgets/icon_tile.dart';

class EmotionScreen extends StatelessWidget {
  const EmotionScreen({super.key});

  static const _emotions = [
    {'id': 'happy', 'label': 'Happy', 'icon': Icons.sentiment_very_satisfied, 'color': Color(0xFFF2B705)},
    {'id': 'sad', 'label': 'Sad', 'icon': Icons.sentiment_dissatisfied, 'color': Color(0xFF4F7CAC)},
    {'id': 'angry', 'label': 'Angry', 'icon': Icons.sentiment_very_dissatisfied, 'color': Color(0xFFD9534F)},
    {'id': 'scared', 'label': 'Scared', 'icon': Icons.sentiment_neutral, 'color': Color(0xFF8E7CC3)},
    {'id': 'tired', 'label': 'Tired', 'icon': Icons.bedtime, 'color': Color(0xFF6C757D)},
  ];

  Future<void> _handleTap(BuildContext context, String iconId, String label) async {
    final appState = context.read<AppState>();
    final speakSuccess = await TtsService.speak(label, appState.language);
    
    if (!speakSuccess && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${appState.language.toUpperCase()} voice package is not installed/supported on this device. Please install it in system Text-To-Speech settings.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
    if (appState.userId != null) {
      try {
        await ApiService.selectIcon(
          userId: appState.userId!,
          iconId: iconId,
          language: appState.language,
        );
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('How are you feeling?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: GridView.count(
            padding: const EdgeInsets.all(16),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: _emotions.map((e) {
              return IconTile(
                icon: e['icon'] as IconData,
                label: e['label'] as String,
                color: e['color'] as Color,
                onTap: () => _handleTap(context, e['id'] as String, e['label'] as String),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
