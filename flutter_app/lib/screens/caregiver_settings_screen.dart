import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/api_service.dart';

class CaregiverSettingsScreen extends StatefulWidget {
  const CaregiverSettingsScreen({super.key});

  @override
  State<CaregiverSettingsScreen> createState() => _CaregiverSettingsScreenState();
}

class _CaregiverSettingsScreenState extends State<CaregiverSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;
  List<dynamic> _caregivers = [];

  // Form View State
  bool _isFormView = false;
  String? _editingCaregiverId;

  final _nameController = TextEditingController();
  final _relationshipController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _photoController = TextEditingController();
  final _fcmController = TextEditingController();
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadCaregiversData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _relationshipController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _photoController.dispose();
    _fcmController.dispose();
    super.dispose();
  }

  Future<void> _loadCaregiversData() async {
    final userId = context.read<AppState>().userId;
    if (userId == null) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    try {
      final list = await ApiService.getCaregivers(userId);
      if (mounted) {
        setState(() {
          _caregivers = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load caregivers: $e')),
        );
        setState(() => _loading = false);
      }
    }
  }

  void _openForm({Map<String, dynamic>? cg}) {
    if (cg != null) {
      _editingCaregiverId = cg['_id'];
      _nameController.text = cg['name']?.toString() ?? '';
      _relationshipController.text = cg['relationship']?.toString() ?? '';
      _phoneController.text = cg['phone']?.toString() ?? '';
      _emailController.text = cg['email']?.toString() ?? '';
      _photoController.text = cg['profile_photo']?.toString() ?? '';
      _fcmController.text = cg['fcm_token']?.toString() ?? '';
      _notificationsEnabled = cg['notifications_enabled'] != false;
    } else {
      _editingCaregiverId = null;
      _nameController.clear();
      _relationshipController.clear();
      _phoneController.clear();
      _emailController.clear();
      _photoController.clear();
      _fcmController.clear();
      _notificationsEnabled = true;
    }
    setState(() {
      _isFormView = true;
    });
  }

  void _closeForm() {
    setState(() {
      _isFormView = false;
      _editingCaregiverId = null;
    });
  }

  Future<void> _saveCaregiver() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = context.read<AppState>().userId;
    if (userId == null) return;

    setState(() => _saving = true);

    final caregiverData = {
      'name': _nameController.text.trim(),
      'relationship': _relationshipController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'profile_photo': _photoController.text.trim(),
      'fcm_token': _fcmController.text.trim(),
      'notifications_enabled': _notificationsEnabled,
    };

    try {
      if (_editingCaregiverId != null) {
        await ApiService.updateCaregiver(userId, _editingCaregiverId!, caregiverData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Caregiver updated successfully.')),
          );
        }
      } else {
        await ApiService.addCaregiver(userId, caregiverData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Caregiver added successfully.')),
          );
        }
      }
      _closeForm();
      _loadCaregiversData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save caregiver: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteCaregiver(String cgId) async {
    final userId = context.read<AppState>().userId;
    if (userId == null) return;

    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Caregiver', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this caregiver?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          )
        ],
      )
    );

    if (delete != true) return;

    setState(() => _loading = true);
    try {
      await ApiService.deleteCaregiver(userId, cgId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Caregiver deleted successfully.')),
        );
      }
      _loadCaregiversData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete caregiver: $e')),
        );
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _toggleNotifications(Map<String, dynamic> cg, bool val) async {
    final userId = context.read<AppState>().userId;
    if (userId == null) return;

    try {
      final updatedData = {
        'name': cg['name'],
        'relationship': cg['relationship'] ?? 'Caregiver',
        'phone': cg['phone'],
        'email': cg['email'],
        'profile_photo': cg['profile_photo'] ?? '',
        'fcm_token': cg['fcm_token'] ?? '',
        'notifications_enabled': val,
      };
      await ApiService.updateCaregiver(userId, cg['_id'], updatedData);
      _loadCaregiversData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle notifications: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isFormView) {
      return _buildFormView();
    }
    return _buildListView();
  }

  Widget _buildListView() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caregivers Management'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Caregiver'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _caregivers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline, size: 70, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No caregivers registered yet.',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add caregivers to receive notifications.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => _openForm(),
                        child: const Text('Add Caregiver'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _caregivers.length,
                  itemBuilder: (context, idx) {
                    final cg = _caregivers[idx];
                    final String name = cg['name'] ?? 'Unknown Name';
                    final String rel = cg['relationship'] ?? 'Caregiver';
                    final String phone = cg['phone'] ?? '';
                    final String email = cg['email'] ?? '';
                    final String photo = cg['profile_photo'] ?? '';
                    final bool enabled = cg['notifications_enabled'] != false;

                    Widget avatar = CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                      child: const Icon(Icons.person),
                    );
                    if (photo.startsWith('http') || photo.startsWith('https')) {
                      avatar = CircleAvatar(
                        backgroundImage: NetworkImage(photo),
                      );
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                        child: ExpansionTile(
                          leading: avatar,
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                          subtitle: Text('$rel • $phone'),
                          trailing: Switch(
                            value: enabled,
                            onChanged: (val) => _toggleNotifications(cg, val),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 12.0, top: 4.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Divider(),
                                  if (email.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text('Email: $email', style: const TextStyle(fontSize: 15)),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    'FCM Token: ${cg['fcm_token'] != null && cg['fcm_token'].toString().isNotEmpty ? "Registered" : "None"}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: cg['fcm_token'] != null && cg['fcm_token'].toString().isNotEmpty ? Colors.green : Colors.orange,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        label: const Text('Edit'),
                                        onPressed: () => _openForm(cg: cg),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton.icon(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        label: const Text('Delete'),
                                        onPressed: () => _deleteCaregiver(cg['_id']),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildFormView() {
    final String title = _editingCaregiverId != null ? 'Edit Caregiver' : 'Add Caregiver';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _closeForm,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Caregiver Contact details',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add names, phone, email, and FCM tokens to dispatch emergency notification updates when triggering SOS.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Caregiver Name *',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _relationshipController,
                decoration: const InputDecoration(
                  labelText: 'Relationship * (e.g. Spouse, Father, Doctor)',
                  prefixIcon: Icon(Icons.family_restroom),
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter relationship' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter phone' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address *',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter email';
                  if (!val.contains('@') || !val.contains('.')) return 'Please enter a valid email address';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _photoController,
                decoration: const InputDecoration(
                  labelText: 'Profile Photo URL (Optional)',
                  prefixIcon: Icon(Icons.image),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fcmController,
                decoration: const InputDecoration(
                  labelText: 'Firebase FCM Device Token (Optional)',
                  prefixIcon: Icon(Icons.token_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Notifications Enabled', style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: const Text('Receive push alerts and backup emails'),
                value: _notificationsEnabled,
                onChanged: (val) {
                  setState(() {
                    _notificationsEnabled = val;
                  });
                },
              ),
              const SizedBox(height: 32),
              _saving
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 54),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _closeForm,
                            child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 54),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _saveCaregiver,
                            child: const Text('Save Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
