import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';

import 'caregiver_dashboard_screen.dart';
import 'caregiver_settings_screen.dart';
import 'emergency_history_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _enterCaregiverDashboard(BuildContext context) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Caregiver Access'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please enter the Caregiver Passcode to access configurations:'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Passcode (Default: 1234)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final input = controller.text.trim();
                // Validate caregiver passcode
                if (input == '1234') {
                  Navigator.pop(context); // Close dialog
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CaregiverDashboardScreen()),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid Passcode! Accessibility denied.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Verify'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Profile & Settings', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        
        Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Preferred Language', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
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
                ),
              ],
            ),
          ),
        ),

        Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: Colors.blue),
                title: const Text('Caregiver Dashboard', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                subtitle: const Text('Manage dynamic board categories, cards, and reordering'),
                trailing: const Icon(Icons.lock_open),
                onTap: () => _enterCaregiverDashboard(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.contact_phone, color: Colors.green),
                title: const Text('Caregiver Settings', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                subtitle: const Text('Manage emergency contacts and FCM details'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CaregiverSettingsScreen()),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.history, color: Colors.red),
                title: const Text('Emergency SOS Logs', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                subtitle: const Text('View history of past emergency dispatches'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EmergencyHistoryScreen()),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        const Text(
          'Accessibility details, high-contrast themes, and other preferences '
          'are synchronized with PUT /api/users/{id} and MongoDB.',
          style: TextStyle(color: Colors.grey, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
