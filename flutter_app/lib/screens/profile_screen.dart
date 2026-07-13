import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Profile & Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        const Text('Preferred Language', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'en', label: Text('English')),
            ButtonSegment(value: 'ta', label: Text('தமிழ்')),
            ButtonSegment(value: 'hi', label: Text('हिन्दी')),
          ],
          selected: {appState.language},
          onSelectionChanged: (selection) {
            context.read<AppState>().setLanguage(selection.first);
          },
        ),
        const SizedBox(height: 32),
        const Text(
          'Caregiver details, emergency contacts, and accessibility settings '
          '(font size, icon size, high-contrast theme) are managed here in the '
          'full build — wired to PUT /api/users/{id} and /api/users/{id}/preferences.',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}
