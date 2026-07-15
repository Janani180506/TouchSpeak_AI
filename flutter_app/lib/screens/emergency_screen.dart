import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
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
  bool _inCountdown = false;
  int _countdownSeconds = 5;
  Timer? _timer;
  String? _errorMsg;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied.');
    }
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 8),
    );
  }

  Future<void> _startSOSFlow() async {
    // 1. Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency SOS', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to notify your caregiver?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Send SOS', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 2. Start Countdown
    setState(() {
      _inCountdown = true;
      _countdownSeconds = 5;
      _errorMsg = null;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds == 1) {
        timer.cancel();
        setState(() {
          _inCountdown = false;
          _timer = null;
        });
        _dispatchSOS();
      } else {
        setState(() {
          _countdownSeconds--;
        });
      }
    });
  }

  void _cancelCountdown() {
    _timer?.cancel();
    setState(() {
      _inCountdown = false;
      _timer = null;
    });
  }

  Future<void> _dispatchSOS() async {
    final appState = context.read<AppState>();
    setState(() {
      _sending = true;
      _errorMsg = null;
    });

    // Notify user locally that we are sending
    await TtsService.speak('Sending emergency alert.', appState.language);

    try {
      final pos = await _getCurrentLocation();
      
      if (appState.userId == null) {
        throw Exception('No user profile registered. Please save caregiver details first.');
      }

      final result = await ApiService.triggerSOS(
        userId: appState.userId!,
        lat: pos.latitude,
        lng: pos.longitude,
      );

      // Play emergency voice message post-dispatch in selected language
      await TtsService.speak('Emergency! I need immediate assistance.', appState.language);

      if (mounted) {
        _showSuccessDialog(result);
      }
    } catch (e) {
      String friendlyError = 'Could not send alert. Please check connection and try again.';
      if (e is LocationServiceDisabledException) {
        friendlyError = 'GPS is currently disabled. Please enable GPS in your device settings.';
      } else if (e.toString().contains('denied')) {
        friendlyError = 'Location permission was denied. Please allow location access in settings.';
      } else if (e.toString().contains('permanently')) {
        friendlyError = 'Location permission is permanently denied. Please enable it in device settings.';
      } else if (e.toString().contains('registered')) {
        friendlyError = e.toString().replaceAll('Exception: ', '');
      } else {
        friendlyError = 'Location coordinates are currently unavailable. Please check your system settings or try again.';
      }
      
      setState(() => _errorMsg = friendlyError);
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _showSuccessDialog(Map<String, dynamic> data) {
    final String emergencyId = data['log_id'] ?? 'N/A';
    final String timestamp = data['timestamp'] ?? 'N/A';
    final String caregiverName = data['caregiver_name'] ?? 'N/A';
    final String mapsUrl = data['google_maps_url'] ?? '';
    final String notificationStatus = data['notification_status'] ?? 'Failed';
    final String emailStatus = data['email_status'] ?? 'Not Sent';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 30),
            SizedBox(width: 10),
            Expanded(child: Text('Emergency Alert Sent Successfully', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Emergency ID:\n$emergencyId', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Text('Date & Time:\n$timestamp'),
              const SizedBox(height: 12),
              Text('Caregiver:\n$caregiverName'),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Notification FCM: '),
                  Text(
                    notificationStatus,
                    style: TextStyle(
                      color: notificationStatus == 'Success' ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Text('Email Backup: '),
                  Text(
                    emailStatus,
                    style: TextStyle(
                      color: emailStatus == 'Success' ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          if (mapsUrl.isNotEmpty)
            ElevatedButton.icon(
              icon: const Icon(Icons.map, color: Colors.white),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              label: const Text('View on Google Maps', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                final uri = Uri.tryParse(mapsUrl);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Dismiss', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency SOS'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _inCountdown
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'DISPATCHING ALERT IN',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    const SizedBox(height: 24),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 140,
                          height: 140,
                          child: CircularProgressIndicator(
                            value: _countdownSeconds / 5.0,
                            strokeWidth: 10,
                            backgroundColor: Colors.grey.shade200,
                            color: Colors.red,
                          ),
                        ),
                        Text(
                          '$_countdownSeconds',
                          style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(200, 60),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _cancelCountdown,
                      child: const Text('CANCEL DISPATCH', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sos, size: 120, color: Colors.red),
                    const SizedBox(height: 24),
                    const Text(
                      'Pressing this button will share your live location with your caregiver.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 40),
                    _sending
                        ? const Column(
                            children: [
                              CircularProgressIndicator(color: Colors.red),
                              SizedBox(height: 16),
                              Text('Locating and notifying caregiver...', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ],
                          )
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              minimumSize: const Size(260, 80),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 6,
                            ),
                            onPressed: _startSOSFlow,
                            child: const Text('SEND SOS ALERT', style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                    if (_errorMsg != null) ...[
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: BorderSide(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMsg!,
                                style: const TextStyle(color: Colors.red, fontSize: 15, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
