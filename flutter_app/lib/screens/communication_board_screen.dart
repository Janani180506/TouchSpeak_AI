import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/api_service.dart';
import '../services/tts_service.dart';
import '../widgets/icon_tile.dart';

class CommunicationBoardScreen extends StatefulWidget {
  const CommunicationBoardScreen({super.key});

  @override
  State<CommunicationBoardScreen> createState() => _CommunicationBoardScreenState();
}

class _CommunicationBoardScreenState extends State<CommunicationBoardScreen> {
  // Lists fetched from DB
  List<dynamic> _categories = [];
  List<dynamic> _allCards = [];
  List<dynamic> _favorites = [];
  List<dynamic> _predictions = [];

  bool _loading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Helper mapping string to Material Icons
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
    _loadBoardData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBoardData() async {
    final userId = context.read<AppState>().userId;
    if (userId == null) return;

    if (mounted) setState(() => _loading = true);

    try {
      // Concurrently fetch board data
      final results = await Future.wait([
        ApiService.getCategories(),
        ApiService.getCards(),
        ApiService.getFavorites(userId),
        ApiService.getPredictions(userId).catchError((_) => []),
      ]);

      if (mounted) {
        setState(() {
          _categories = results[0];
          _allCards = results[1];
          _favorites = results[2];
          _predictions = results[3];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load communication board: $e')),
        );
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _refreshPredictions() async {
    final userId = context.read<AppState>().userId;
    if (userId == null) return;
    try {
      final preds = await ApiService.getPredictions(userId);
      if (mounted) {
        setState(() => _predictions = preds);
      }
    } catch (_) {}
  }

  Future<void> _handleCardTap(Map<String, dynamic> card) async {
    final appState = context.read<AppState>();
    final userId = appState.userId;

    final translations = card['translations'] ?? {};
    final lang = appState.language;
    
    // Determine target phrase text using language translations
    String phraseText = translations[lang] ?? card['phrase'] ?? card['title'] ?? '';
    if (phraseText.isEmpty) {
      phraseText = card['title'] ?? '';
    }

    // Zero-latency local Text-To-Speech playback
    final speakSuccess = await TtsService.speak(phraseText, lang);

    if (!speakSuccess && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${lang.toUpperCase()} voice package is not supported/installed on this device. Install it in system settings.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // Log selected card to backend for history logging & AI learning (non-blocking)
    if (userId != null) {
      try {
        final cardId = card['_id'].toString();
        await ApiService.selectIcon(
          userId: userId,
          iconId: cardId,
          language: lang,
        );
        _refreshPredictions();
      } catch (_) {}
    }
  }

  Future<void> _toggleFavorite(String cardId, bool currentIsFavorite) async {
    final userId = context.read<AppState>().userId;
    if (userId == null) return;

    try {
      await ApiService.toggleFavorite(
        userId: userId,
        cardId: cardId,
        isFavorite: !currentIsFavorite,
      );
      _loadBoardData(); // Reload all board datasets (favorites badge updates immediately)
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update favorite status: $e')),
        );
      }
    }
  }

  IconData _resolveIcon(String name) {
    return _iconMap[name] ?? Icons.grid_view;
  }

  bool _isCardFavorite(String cardId) {
    return _favorites.any((f) => f['_id'].toString() == cardId);
  }

  // Visual layout for individual cards
  Widget _buildCardTile(Map<String, dynamic> card) {
    final cardId = card['_id'].toString();
    final isFav = _isCardFavorite(cardId);
    
    Widget mediaWidget;
    final imgPath = card['image_path'] ?? '';
    
    if (imgPath.isNotEmpty) {
      if (imgPath.startsWith('http')) {
        mediaWidget = Image.network(imgPath, height: 48, fit: BoxFit.cover);
      } else {
        // Points to backend asset upload route
        final backendBase = AppState.apiBaseUrl.replaceAll('/api', '');
        mediaWidget = Image.network('$backendBase$imgPath', height: 48, fit: BoxFit.cover);
      }
    } else {
      mediaWidget = Icon(_resolveIcon(card['icon'] ?? 'grid_view'), size: 48, color: Colors.white);
    }

    // Theme color
    Color cardColor = const Color(0xFF2A6FDB);
    final categoryId = card['category_id']?.toString();
    if (categoryId != null && _categories.isNotEmpty) {
      final categoryIndex = _categories.indexWhere((c) => c['_id'].toString() == categoryId);
      final colors = [
        const Color(0xFFE07A34), // Orange Needs
        const Color(0xFFF2B705), // Yellow Emotions
        const Color(0xFFD9534F), // Red Emergency
        const Color(0xFF8E7CC3), // Purple
        const Color(0xFF6FBF73), // Green
        const Color(0xFF4F7CAC), // Heavy Blue
      ];
      if (categoryIndex >= 0 && categoryIndex < colors.length) {
        cardColor = colors[categoryIndex];
      }
    }

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _handleCardTap(card),
        onLongPress: () => _toggleFavorite(cardId, isFav),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: mediaWidget,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    card['title'] ?? '',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: () => _toggleFavorite(cardId, isFav),
                child: Icon(
                  isFav ? Icons.star : Icons.star_border,
                  color: isFav ? Colors.yellow : Colors.white70,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search & Header Area
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TouchSpeak',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 28),
                      onPressed: _loadBoardData,
                      tooltip: 'Refresh Communication Board',
                    ),
                  ],
                ),
              ),
              
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search cards e.g. "water"...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim().toLowerCase();
                    });
                  },
                ),
              ),

              // AI Suggestion Strip (if there is history)
              if (_predictions.isNotEmpty) _buildPredictionStrip(),

              // Grid view - Filtered view if searching, tabbed view otherwise
              Expanded(
                child: _searchQuery.isNotEmpty
                    ? _buildFilteredCardsGrid()
                    : _buildTabbedBoardLayout(),
              ),
            ],
          );
  }

  Widget _buildFilteredCardsGrid() {
    final filtered = _allCards.where((card) {
      final title = (card['title'] ?? '').toString().toLowerCase();
      final phrase = (card['phrase'] ?? '').toString().toLowerCase();
      final transEn = (card['translations']?['en'] ?? '').toString().toLowerCase();
      final transTa = (card['translations']?['ta'] ?? '').toString().toLowerCase();
      final transHi = (card['translations']?['hi'] ?? '').toString().toLowerCase();

      return title.contains(_searchQuery) ||
          phrase.contains(_searchQuery) ||
          transEn.contains(_searchQuery) ||
          transTa.contains(_searchQuery) ||
          transHi.contains(_searchQuery);
    }).toList();

    return filtered.isEmpty
        ? const Center(child: Text('No matching cards found.'))
        : GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, i) => _buildCardTile(filtered[i]),
          );
  }

  Widget _buildTabbedBoardLayout() {
    // We will render a tabbed layout:
    // Tab 1: Favorites
    // Tab 2 to N: Dynamic Categories loaded from DB
    final tabs = <Tab>[
      const Tab(icon: Icon(Icons.star, size: 20), text: 'Home'),
    ];

    for (var cat in _categories) {
      tabs.add(Tab(
        icon: Icon(_resolveIcon(cat['icon'] ?? 'grid_view'), size: 20),
        text: cat['name'] ?? '',
      ));
    }

    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: tabs,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildFavoritesTabContent(),
                ..._categories.map((cat) => _buildCategoryTabContent(cat['_id'].toString())),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesTabContent() {
    return _favorites.isEmpty
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'Add cards to your Favorites to access them instantly from this User Home tab.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          )
        : GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
            ),
            itemCount: _favorites.length,
            itemBuilder: (context, i) => _buildCardTile(_favorites[i]),
          );
  }

  Widget _buildCategoryTabContent(String categoryId) {
    final catCards = _allCards.where((c) => c['category_id']?.toString() == categoryId).toList();
    
    return catCards.isEmpty
        ? const Center(child: Text('No cards in this category yet.'))
        : GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
            ),
            itemCount: catCards.length,
            itemBuilder: (context, i) => _buildCardTile(catCards[i]),
          );
  }

  Widget _buildPredictionStrip() {
    final lang = context.read<AppState>().language;
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _predictions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final p = _predictions[i] as Map<String, dynamic>;
          final iconId = p['icon_id'].toString();
          
          // Try to find card translations or default phrase text
          String phraseText = p['phrase_text'] ?? '';
          final matchingCard = _allCards.firstWhere(
            (c) => c['_id'].toString() == iconId,
            orElse: () => null,
          );

          if (matchingCard != null) {
            final trans = matchingCard['translations'] ?? {};
            phraseText = trans[lang] ?? matchingCard['phrase'] ?? matchingCard['title'] ?? phraseText;
          }

          return ActionChip(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            avatar: const Icon(Icons.auto_awesome, size: 16, color: Colors.blue),
            backgroundColor: Colors.blue.shade50,
            label: Text(
              phraseText,
              style: const TextStyle(color: Colors.blue, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              if (matchingCard != null) {
                _handleCardTap(matchingCard);
              } else {
                // Backward compatibility static selection
                TtsService.speak(phraseText, lang);
                final userId = context.read<AppState>().userId;
                if (userId != null) {
                  ApiService.selectIcon(userId: userId, iconId: iconId, language: lang);
                  _refreshPredictions();
                }
              }
            },
          );
        },
      ),
    );
  }
}
