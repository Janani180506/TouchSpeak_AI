import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/app_state.dart';
import 'screens/communication_board_screen.dart';
import 'screens/emotion_screen.dart';
import 'screens/frequent_phrases_screen.dart';
import 'screens/emergency_screen.dart';
import 'screens/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState();
  await appState.init();
  runApp(
    ChangeNotifierProvider(
      create: (_) => appState,
      child: const TouchSpeakApp(),
    ),
  );
}

class TouchSpeakApp extends StatelessWidget {
  const TouchSpeakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return MaterialApp(
          title: 'TouchSpeak AI',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: const Color(0xFF2A6FDB),
            fontFamily: 'Roboto',
            textTheme: const TextTheme(
              bodyLarge: TextStyle(fontSize: 20),
              bodyMedium: TextStyle(fontSize: 18),
            ),
          ),
          home: const HomeShell(),
        );
      },
    );
  }
}

/// Bottom-navigation shell hosting the main screens of the app.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _screens = const [
    CommunicationBoardScreen(),
    EmotionScreen(),
    FrequentPhrasesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _screens[_index]),
      // Emergency SOS is always reachable as a floating button, not buried in a tab.
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red,
        icon: const Icon(Icons.sos, size: 28),
        label: const Text('SOS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const EmergencyScreen()),
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view), label: 'Board'),
          NavigationDestination(icon: Icon(Icons.emoji_emotions), label: 'Emotions'),
          NavigationDestination(icon: Icon(Icons.star), label: 'Frequent'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
