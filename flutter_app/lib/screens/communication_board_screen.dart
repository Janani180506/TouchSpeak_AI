import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/api_service.dart';
import '../services/tts_service.dart';
import '../widgets/icon_tile.dart';

/// The primary screen: a grid of need-based icons. Tapping an icon converts
/// it to speech and logs it for the AI predictor. The top strip shows the
/// AI's live top-3 predicted next phrases so the user can tap even faster.
class CommunicationBoardScreen extends StatefulWidget {
  const CommunicationBoardScreen({super.key});

  @override
  State<CommunicationBoardScreen> createState() => _CommunicationBoardScreenState();
}

class _CommunicationBoardScreenState extends State<CommunicationBoardScreen> {
  List<dynamic> _predictions = [];
  bool _loadingPredictions = false;

  static const _needsIcons = [
    {'id': 'food', 'label': 'Food', 'icon': Icons.restaurant, 'color': Color(0xFFE07A34)},
    {'id': 'water', 'label': 'Water', 'icon': Icons.water_drop, 'color': Color(0xFF2A9DD9)},
    {'id': 'medicine', 'label': 'Medicine', 'icon': Icons.medication, 'color': Color(0xFF6FBF73)},
    {'id': 'restroom', 'label': 'Restroom', 'icon': Icons.wc, 'color': Color(0xFF8E7CC3)},
    {'id': 'pain', 'label': 'Pain', 'icon': Icons.healing, 'color': Color(0xFFD9534F)},
    {'id': 'help', 'label': 'Help', 'icon': Icons.pan_tool, 'color': Color(0xFFE0B03A)},
  ];

  @override
  void initState() {
    super.initState();
    _refreshPredictions();
  }

  Future<void> _refreshPredictions() async {
    final userId = context.read<AppState>().userId;
    if (userId == null) return;
    setState(() => _loadingPredictions = true);
    try {
      final preds = await ApiService.getPredictions(userId);
      setState(() => _predictions = preds);
    } catch (_) {
      // Network/backend not reachable - fail silently, board still usable offline.
    } finally {
      setState(() => _loadingPredictions = false);
    }
  }

  Future<void> _handleIconTap(String iconId, String label, String fallbackPhrase) async {
    final appState = context.read<AppState>();
    final userId = appState.userId;

    // Speak immediately (offline, on-device) for zero-latency feedback.
    final speakSuccess = await TtsService.speak(fallbackPhrase, appState.language);

    if (!speakSuccess && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${appState.language.toUpperCase()} voice package is not installed/supported on this device. Please install it in system Text-To-Speech settings.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }

    // Log to backend for history + AI learning (best-effort, non-blocking UX).
    if (userId != null) {
      try {
        await ApiService.selectIcon(
          userId: userId,
          iconId: iconId,
          language: appState.language,
        );
        _refreshPredictions();
      } catch (_) {
        // Offline - the tap still worked locally; sync can be retried later.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('TouchSpeak', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        ),
        if (_predictions.isNotEmpty) _buildPredictionStrip(),
        Expanded(
          child: GridView.count(
            padding: const EdgeInsets.all(16),
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: _needsIcons.map((item) {
              return IconTile(
                icon: item['icon'] as IconData,
                label: item['label'] as String,
                color: item['color'] as Color,
                onTap: () => _handleIconTap(
                  item['id'] as String,
                  item['label'] as String,
                  '${item['label']}', // local fallback text; backend returns localized phrase
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionStrip() {
    return Container(
      height: 80,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _predictions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final p = _predictions[i] as Map<String, dynamic>;
          return ActionChip(
            avatar: const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
            backgroundColor: Theme.of(context).colorScheme.primary,
            label: Text(
              p['phrase_text'] ?? p['icon_id'],
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            onPressed: () => _handleIconTap(p['icon_id'], p['icon_id'], p['phrase_text'] ?? ''),
          );
        },
      ),
    );
  }
}
