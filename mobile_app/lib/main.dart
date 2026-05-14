import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/analytics_screen.dart';
import 'screens/co_pilot_screen.dart';
import 'screens/guardian_screen.dart';
import 'screens/mood_route_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const AdamsMobileApp());
}

class AdamsMobileApp extends StatelessWidget {
  const AdamsMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ADAMS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF007C89),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF101418),
        useMaterial3: true,
      ),
      home: const AdamsShell(),
    );
  }
}

class AdamsShell extends StatefulWidget {
  const AdamsShell({super.key});

  @override
  State<AdamsShell> createState() => _AdamsShellState();
}

class _AdamsShellState extends State<AdamsShell> {
  int selectedIndex = 0;

  static const screens = [
    CoPilotScreen(),
    GuardianScreen(),
    MoodRouteScreen(),
    AnalyticsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: selectedIndex,
          children: screens,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.mic_none),
            selectedIcon: Icon(Icons.mic),
            label: 'Co-Pilot',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield),
            label: 'Guardian',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: 'Route',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Analytics',
          ),
        ],
      ),
    );
  }
}
