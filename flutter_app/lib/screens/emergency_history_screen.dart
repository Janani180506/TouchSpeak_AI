import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyHistoryScreen extends StatefulWidget {
  const EmergencyHistoryScreen({super.key});

  @override
  State<EmergencyHistoryScreen> createState() => _EmergencyHistoryScreenState();
}

class _EmergencyHistoryScreenState extends State<EmergencyHistoryScreen> {
  List<dynamic> _logs = [];
  bool _loading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final userId = context.read<AppState>().userId;
    if (userId == null) {
      setState(() {
        _errorMsg = 'No user profile loaded.';
        _loading = false;
      });
      return;
    }

    try {
      final logs = await ApiService.getEmergencyLogs(userId);
      setState(() {
        _logs = logs;
        _loading = false;
        _errorMsg = null;
      });
    } catch (e) {
      setState(() {
        _errorMsg = 'Could not fetch history: $e';
        _loading = false;
      });
    }
  }

  Future<void> _launchMaps(String urlStr) async {
    final uri = Uri.tryParse(urlStr);
    if (uri != null) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch map URL: $urlStr')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency History'),
        backgroundColor: Colors.red.shade100,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _loading = true;
                _errorMsg = null;
              });
              _loadHistory();
            },
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMsg != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisSize.mainAxisAlignment = MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(_errorMsg!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _loading = true;
                              _errorMsg = null;
                            });
                            _loadHistory();
                          },
                          child: const Text('Retry'),
                        )
                      ],
                    ),
                  ),
                )
              : _logs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text(
                            'No emergency alerts recorded.',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _logs.length,
                      itemBuilder: (context, i) {
                        final log = _logs[i] as Map<String, dynamic>;
                        final emergencyId = log['_id'] ?? 'N/A';
                        final timestamp = log['timestamp'] ?? 'N/A';
                        final caregiverName = log['caregiver_name'] ?? 'N/A';
                        final mapsUrl = log['google_maps_url'] ?? '';
                        final nStatus = log['notification_status'] ?? 'Failed';
                        final eStatus = log['email_status'] ?? 'Skipped';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.red.shade100, width: 0.5),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'ID: $emergencyId',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'SOS Alert',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 20),
                                Text(
                                  'Date & Time: $timestamp',
                                  style: const TextStyle(fontSize: 15),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Caregiver: $caregiverName',
                                  style: const TextStyle(fontSize: 15),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Text('Notification FCM: ', style: TextStyle(fontSize: 14, color: Colors.grey)),
                                            Icon(
                                              nStatus == 'Success' ? Icons.check_circle : Icons.error,
                                              color: nStatus == 'Success' ? Colors.green : Colors.orange,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              nStatus,
                                              style: TextStyle(
                                                color: nStatus == 'Success' ? Colors.green : Colors.orange,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Text('Email Backup: ', style: TextStyle(fontSize: 14, color: Colors.grey)),
                                            Icon(
                                              eStatus == 'Success' ? Icons.check_circle : Icons.error,
                                              color: eStatus == 'Success' ? Colors.green : Colors.red,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              eStatus,
                                              style: TextStyle(
                                                color: eStatus == 'Success' ? Colors.green : Colors.red,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    if (mapsUrl.isNotEmpty)
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue.shade50,
                                          foregroundColor: Colors.blue.shade800,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: () => _launchMaps(mapsUrl),
                                        icon: const Icon(Icons.map, size: 18),
                                        label: const Text('View Location', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
