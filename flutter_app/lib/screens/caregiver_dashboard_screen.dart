import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../services/app_state.dart';
import '../widgets/icon_tile.dart';
import 'caregiver_settings_screen.dart';

class CaregiverDashboardScreen extends StatefulWidget {
  const CaregiverDashboardScreen({super.key});

  @override
  State<CaregiverDashboardScreen> createState() => _CaregiverDashboardScreenState();
}

class _CaregiverDashboardScreenState extends State<CaregiverDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = false;

  // Data lists
  List<dynamic> _categories = [];
  List<dynamic> _cards = [];
  List<dynamic> _history = [];
  String? _selectedCategoryForCards;

  // Icon mapping helper for display
  static final Map<String, IconData> _iconMap = {
    'restaurant': Icons.restaurant,
    'water_drop': Icons.water_drop,
    'medication': Icons.medication,
    'wc': Icons.wc,
    'healing': Icons.healing,
    'pan_tool': Icons.pan_tool,
    'sentiment_very_satisfied': Icons.sentiment_very_satisfied,
    'sentiment_dissatisfied': Icons.sentiment_dissatisfied,
    'sentiment_very_dissatisfied': Icons.sentiment_very_dissatisfied,
    'sentiment_neutral': Icons.sentiment_neutral,
    'bedtime': Icons.bedtime,
    'emergency': Icons.emergency,
    'family_restroom': Icons.family_restroom,
    'school': Icons.school,
    'home': Icons.home,
    'directions_bus': Icons.directions_bus,
    'favorite': Icons.favorite,
    'grid_view': Icons.grid_view,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      _refreshTab(_tabController.index);
    });
    _initialLoad();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initialLoad() async {
    setState(() => _loading = true);
    await _loadCategories();
    if (_categories.isNotEmpty) {
      _selectedCategoryForCards = _categories.first['_id'];
      await _loadCards();
    }
    setState(() => _loading = false);
  }

  Future<void> _refreshTab(int index) async {
    setState(() => _loading = true);
    try {
      if (index == 0) {
        await _loadCategories();
      } else if (index == 1) {
        await _loadCategories();
        if (_selectedCategoryForCards == null && _categories.isNotEmpty) {
          _selectedCategoryForCards = _categories.first['_id'];
        }
        await _loadCards();
      } else if (index == 2) {
        await _loadHistory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadCategories() async {
    final cats = await ApiService.getCategories();
    setState(() {
      _categories = cats;
    });
  }

  Future<void> _loadCards() async {
    if (_selectedCategoryForCards == null) return;
    final cards = await ApiService.getCards(categoryId: _selectedCategoryForCards);
    setState(() {
      _cards = cards;
    });
  }

  Future<void> _loadHistory() async {
    final userId = context.read<AppState>().userId;
    if (userId == null) return;
    final hist = await ApiService.getHistory(userId);
    setState(() {
      _history = hist;
    });
  }

  IconData _getIcon(String name) {
    return _iconMap[name] ?? Icons.grid_view;
  }

  // =====================================================================
  // CATEGORY OPERATIONS
  // =====================================================================

  void _showCategoryDialog({Map<String, dynamic>? category}) {
    final isEdit = category != null;
    final nameController = TextEditingController(text: category != null ? category['name'] : '');
    String selectedIcon = category != null ? category['icon'] : 'grid_view';
    final orderController = TextEditingController(text: category != null ? category['display_order'].toString() : '1');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Category' : 'Add Category'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Category Name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: orderController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Display Order', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Choose Icon: '),
                        const SizedBox(width: 10),
                        Icon(_getIcon(selectedIcon), size: 32, color: Theme.of(context).primaryColor),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      width: double.maxFinite,
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                        itemCount: _iconMap.length,
                        itemBuilder: (context, i) {
                          final key = _iconMap.keys.elementAt(i);
                          final isSelected = key == selectedIcon;
                          return InkWell(
                            onTap: () => setDialogState(() => selectedIcon = key),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(_iconMap[key], size: 24, color: isSelected ? Theme.of(context).primaryColor : Colors.grey),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final displayOrder = int.tryParse(orderController.text) ?? 1;

                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Category name cannot be empty')),
                      );
                      return;
                    }

                    try {
                      final data = {
                        'name': name,
                        'icon': selectedIcon,
                        'display_order': displayOrder,
                      };

                      if (isEdit) {
                        await ApiService.updateCategory(category['_id'], data);
                      } else {
                        await ApiService.createCategory(data);
                      }

                      if (mounted) {
                        Navigator.pop(context);
                        _refreshTab(0);
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteCategory(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: const Text(
          'Are you sure you want to delete this category? Warning: This will delete all cards containing this category too!',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await ApiService.deleteCategory(id);
                if (mounted) {
                  Navigator.pop(context);
                  _refreshTab(0);
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // CARD OPERATIONS & IMAGE UPLOADS
  // =====================================================================

  void _showCardDialog({Map<String, dynamic>? card}) {
    final isEdit = card != null;
    final titleController = TextEditingController(text: isEdit ? card['title'] : '');
    final phraseController = TextEditingController(text: isEdit ? card['phrase'] : '');
    final orderController = TextEditingController(text: isEdit ? card['display_order'].toString() : '1');

    final enController = TextEditingController(text: isEdit ? (card['translations']?['en'] ?? '') : '');
    final taController = TextEditingController(text: isEdit ? (card['translations']?['ta'] ?? '') : '');
    final hiController = TextEditingController(text: isEdit ? (card['translations']?['hi'] ?? '') : '');

    final imageUrlController = TextEditingController(text: isEdit ? (card['image_path'] ?? '') : '');
    final voiceController = TextEditingController(text: isEdit ? (card['voice_recording_path'] ?? '') : '');

    String selectedCardIcon = isEdit ? (card['icon'] ?? 'grid_view') : 'grid_view';
    String? cardCategory = isEdit ? card['category_id'] : _selectedCategoryForCards;

    bool uploadingImage = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Card' : 'Add Card'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Card Title *', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phraseController,
                      decoration: const InputDecoration(labelText: 'Card Phrase (Fallback English) *', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: cardCategory,
                      decoration: const InputDecoration(labelText: 'Category *', border: OutlineInputBorder()),
                      items: _categories.map((cat) {
                        return DropdownMenuItem<String>(
                          value: cat['_id'].toString(),
                          child: Text(cat['name']),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() => cardCategory = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: enController,
                      decoration: const InputDecoration(labelText: 'English Translation', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: taController,
                      decoration: const InputDecoration(labelText: 'Tamil Translation', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: hiController,
                      decoration: const InputDecoration(labelText: 'Hindi Translation', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: orderController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Display Order', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      color: Colors.grey.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Image Upload or Path', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: imageUrlController,
                              decoration: const InputDecoration(
                                labelText: 'Local Image File Path / URL / Relative Path',
                                border: OutlineInputBorder(),
                                helperText: 'e.g. /static/uploads/... or C:\\image.png',
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (uploadingImage)
                              const Center(child: CircularProgressIndicator())
                            else
                              ElevatedButton.icon(
                                icon: const Icon(Icons.upload),
                                label: const Text('Read & Upload Image File'),
                                onPressed: () async {
                                  final localPath = imageUrlController.text.trim();
                                  if (localPath.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Please enter a local file path first')),
                                    );
                                    return;
                                  }
                                  
                                  setDialogState(() => uploadingImage = true);
                                  try {
                                    // Treat as URL or read local file
                                    List<int> bytes;
                                    String filename;

                                    if (localPath.startsWith('http://') || localPath.startsWith('https://')) {
                                      final urlRes = await http.get(Uri.parse(localPath));
                                      bytes = urlRes.bodyBytes;
                                      filename = localPath.split('/').last.split('?').first;
                                    } else {
                                      final file = File(localPath);
                                      if (!await file.exists()) {
                                        throw Exception('File does not exist on disk. Check path.');
                                      }
                                      bytes = await file.readAsBytes();
                                      filename = localPath.split(Platform.isWindows ? '\\' : '/').last;
                                    }

                                    final uploadRes = await ApiService.uploadImage(bytes, filename);
                                    final relativeUrl = uploadRes['url'] as String;

                                    setDialogState(() {
                                      imageUrlController.text = relativeUrl;
                                    });

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Image uploaded successfully.')),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Upload failed: $e')),
                                    );
                                  } finally {
                                    setDialogState(() => uploadingImage = false);
                                  }
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: voiceController,
                      decoration: const InputDecoration(labelText: 'Custom Voice Audio File Path', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Material Icon (Optional): '),
                        Icon(_getIcon(selectedCardIcon), size: 28, color: Theme.of(context).primaryColor),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      width: double.maxFinite,
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          mainAxisSpacing: 2,
                          crossAxisSpacing: 2,
                        ),
                        itemCount: _iconMap.length,
                        itemBuilder: (context, i) {
                          final key = _iconMap.keys.elementAt(i);
                          final isSelected = key == selectedCardIcon;
                          return InkWell(
                            onTap: () => setDialogState(() => selectedCardIcon = key),
                            child: Icon(_iconMap[key], color: isSelected ? Theme.of(context).primaryColor : Colors.grey),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final phrase = phraseController.text.trim();
                    final displayOrder = int.tryParse(orderController.text) ?? 1;

                    if (title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Card title is required')));
                      return;
                    }
                    if (phrase.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Card phrase is required')));
                      return;
                    }
                    if (cardCategory == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category selection is required')));
                      return;
                    }

                    // Build translations
                    final translations = {
                      'en': enController.text.trim().isNotEmpty ? enController.text.trim() : phrase,
                      'ta': taController.text.trim(),
                      'hi': hiController.text.trim(),
                    };

                    try {
                      final cardData = {
                        'title': title,
                        'phrase': phrase,
                        'category_id': cardCategory,
                        'icon': selectedCardIcon,
                        'image_path': imageUrlController.text.trim(),
                        'voice_recording_path': voiceController.text.trim(),
                        'display_order': displayOrder,
                        'translations': translations,
                      };

                      if (isEdit) {
                        await ApiService.updateCard(card['_id'], cardData);
                      } else {
                        await ApiService.createCard(cardData);
                      }

                      if (mounted) {
                        Navigator.pop(context);
                        _refreshTab(1);
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteCard(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Communication Card'),
        content: const Text('Are you sure you want to delete this communication card?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await ApiService.deleteCard(id);
                if (mounted) {
                  Navigator.pop(context);
                  _refreshTab(1);
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // RENDER INTERFACES
  // =====================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caregiver Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        bottom: TabController(
          length: 4,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(icon: Icon(Icons.category), text: 'Categories'),
              Tab(icon: Icon(Icons.grid_on), text: 'Cards'),
              Tab(icon: Icon(Icons.history_edu), text: 'History'),
              Tab(icon: Icon(Icons.admin_panel_settings), text: 'Caregiver Info'),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCategoriesTab(),
                _buildCardsTab(),
                _buildHistoryTab(),
                _buildCaregiverInfoTab(),
              ],
            ),
    );
  }

  Widget _buildCategoriesTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New Category'),
        onPressed: () => _showCategoryDialog(),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final cat = _categories[i];
          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Icon(_getIcon(cat['icon']), color: Colors.white),
              ),
              title: Text(
                cat['name'],
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: Text('Order: ${cat['display_order']}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _showCategoryDialog(category: cat),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteCategory(cat['_id']),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCardsTab() {
    return Column(
      children: [
        // Dropdown to choose Category
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: DropdownButtonFormField<String>(
            value: _selectedCategoryForCards,
            decoration: const InputDecoration(
              labelText: 'Select Category to Manage & Reorder',
              border: OutlineInputBorder(),
            ),
            items: _categories.map((cat) {
              return DropdownMenuItem<String>(
                value: cat['_id'].toString(),
                child: Text(cat['name']),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedCategoryForCards = val;
              });
              _loadCards();
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Drag and drop the cards using the drag handle on the right to reorder them on the user communication board.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Add Card'),
              onPressed: () => _showCardDialog(),
            ),
            body: _cards.isEmpty
                ? const Center(child: Text('No communication cards in this category.'))
                : ReorderableListView.builder(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80, top: 8),
                    itemCount: _cards.length,
                    onReorder: (oldIndex, newIndex) async {
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      setState(() {
                        final item = _cards.removeAt(oldIndex);
                        _cards.insert(newIndex, item);
                      });
                      try {
                        final orderedIds = _cards.map((c) => c['_id'].toString()).toList();
                        await ApiService.reorderCards(orderedIds);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to save reorder: $e')),
                          );
                        }
                      }
                    },
                    itemBuilder: (context, i) {
                      final card = _cards[i];
                      Widget leadingImg;
                      final imgPath = card['image_path'] ?? '';
                      if (imgPath.isNotEmpty) {
                        if (imgPath.startsWith('http')) {
                          leadingImg = Image.network(imgPath, width: 40, height: 40, fit: BoxFit.cover);
                        } else {
                          // Relative path or absolute URL pointing to Backend
                          final backendUrl = AppState.apiBaseUrl.replaceAll('/api', '');
                          leadingImg = Image.network('$backendUrl$imgPath', width: 40, height: 40, fit: BoxFit.cover);
                        }
                      } else {
                        leadingImg = Icon(_getIcon(card['icon'] ?? 'grid_view'));
                      }

                      return Card(
                        key: ValueKey(card['_id']),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: leadingImg,
                          ),
                          title: Text(card['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(card['phrase']),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _showCardDialog(card: card),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteCard(card['_id']),
                              ),
                              const Icon(Icons.drag_handle, color: Colors.grey),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (context, i) {
        final log = _history[i];
        final ts = DateTime.tryParse(log['timestamp'] ?? '')?.toLocal();
        final tsStr = ts != null
            ? '${ts.day}/${ts.month} ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}'
            : '';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.shade100,
              child: const Icon(Icons.message, color: Colors.orange),
            ),
            title: Text(log['phrase_text'] ?? ''),
            subtitle: Text('Language: ${(log['language'] ?? 'en').toString().toUpperCase()}'),
            trailing: Text(tsStr, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        );
      },
    );
  }

  Widget _buildCaregiverInfoTab() {
    // A clean wrapper interface pointing caregiver settings editing
    final appState = context.read<AppState>();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.admin_panel_settings, size: 80, color: Colors.blue),
          const SizedBox(height: 16),
          const Text(
            'Caregiver Profile Settings',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              'Manage your email logs, phone details, and push notifications config used when a user launches the SOS alert.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CaregiverSettingsScreen()),
              );
            },
            child: const Text('Edit Notification Details'),
          )
        ],
      ),
    );
  }
}
