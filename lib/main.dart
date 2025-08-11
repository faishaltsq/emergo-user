import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import "./providers/contacts_provider.dart";
import './screens/home_screen.dart';
import './utils/app_theme.dart';
import './screens/map_screen.dart';
import './screens/contacts_screen.dart';
import './screens/history_screen.dart';
import './screens/settings_screen.dart';
import './screens/emergency_screen.dart';
import './services/notification_service.dart';
import './services/shake_detection_service.dart';
import './services/permission_service.dart';
import 'providers/user_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/register_screen.dart';
import 'providers/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load();

  // Initialize notification service
  await NotificationService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ContactsProvider()),
  ChangeNotifierProvider(create: (_) => UserProvider()),
  ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: MaterialApp(
        title: 'EMERGO',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: const _Bootstrapper(),
        routes: {
          '/auth': (context) => const AuthScreen(),
          '/register': (context) => const RegisterScreen(),
        },
      ),
    );
  }
}

class _Bootstrapper extends StatelessWidget {
  const _Bootstrapper();

  @override
  Widget build(BuildContext context) {
    final userProvider = context.read<UserProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    return FutureBuilder(
      future: Future.wait([
        userProvider.initialize(),
        settingsProvider.initialize(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return const MainScreen();
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Request app-wide permissions on first run
    _requestStartupPermissions();

    // Build screens so HomeScreen can request tab changes
    _screens = [
      HomeScreen(
        onNavigateToTab: (index) {
          if (index >= 0 && index < 5) {
            setState(() {
              _currentIndex = index;
            });
          }
        },
      ),
      const MapScreen(),
      const ContactsScreen(),
      const HistoryScreen(),
      const SettingsScreen(),
    ];

    // Start shake detection when app starts
    _initializeShakeDetection();
  }

  Future<void> _requestStartupPermissions() async {
    final results = await PermissionService.requestAllRequiredPermissions();
    final bool locGranted =
        results[Permission.location] == PermissionStatus.granted;

    if (mounted && !locGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Location permission denied. Some features may not work.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ShakeDetectionService.stopListening();
    super.dispose();
  }

  void _initializeShakeDetection() {
    final settings = context.read<SettingsProvider>();
    if (settings.isInitialized && settings.shakeToSOSEnabled) {
      ShakeDetectionService.startListening(
        onShakeDetected: () {
          _showShakeEmergencyDialog();
        },
      );
    } else {
      ShakeDetectionService.stopListening();
    }
  }

  void _showShakeEmergencyDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Shake Detected!'),
          content: const Text(
              'Emergency gesture detected. Do you want to send an emergency alert?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate to emergency screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EmergencyScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Send Alert'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Contacts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
