import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../services/app_state.dart';
import '../services/api_service.dart';
import '../services/tts_service.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  bool _sending = false;
  String? _resultMessage;

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }
    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _sendSOS() async {
    final appState = context.read<AppState>();
    setState(() {
      _sending = true;
      _resultMessage = null;
    });

    final speakSuccess = await TtsService.speak('Sending emergency alert.', appState.language);

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

    try {
      final pos = await _getCurrentLocation();
      if (appState.userId == null) {
        throw Exception('No user profile set up yet.');
      }
      final result = await ApiService.triggerSOS(
        userId: appState.userId!,
        lat: pos.latitude,
        lng: pos.longitude,
      );
      setState(() {
        _resultMessage = result['caregiver_notified'] == true
            ? 'Caregiver notified successfully.'
            : 'Alert logged. Caregiver notification could not be delivered - '
                'call them directly if possible.';
      });
    } catch (e) {
      setState(() => _resultMessage = 'Could not send alert: $e');
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency SOS'), backgroundColor: Colors.red),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sos, size: 100, color: Colors.red),
              const SizedBox(height: 24),
              const Text(
                'Pressing this button will share your live location with your caregiver.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 32),
              _sending
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        minimumSize: const Size(220, 70),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _sendSOS,
                      child: const Text('SEND ALERT', style: TextStyle(fontSize: 22, color: Colors.white)),
                    ),
              if (_resultMessage != null) ...[
                const SizedBox(height: 24),
                Text(_resultMessage!, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
