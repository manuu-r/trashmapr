import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/auth_service.dart';
import 'services/theme_service.dart';
import 'services/camera_service.dart';
import 'services/pending_uploads_service.dart';
import 'services/fcm_service.dart';
import 'config/app_theme.dart';
import 'screens/auth_screen.dart';
import 'widgets/main_navigator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Warning: .env file not found. Using default values.');
  }

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    debugPrint('Firebase initialized successfully');

    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Warning: Firebase initialization failed: $e');
  }

  runApp(const TrashMaprApp());
}

class TrashMaprApp extends StatelessWidget {
  const TrashMaprApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => CameraService()),
        ChangeNotifierProvider(create: (_) => PendingUploadsService()),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return Consumer<AuthService>(
            builder: (context, authService, child) {
              return MaterialApp(
                title: 'TrashMapr',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.buildLightTheme(),
                darkTheme: AppTheme.buildDarkTheme(),
                themeMode: themeService.themeMode,
                home: authService.isAuthenticated
                    ? const MainNavigator()
                    : const AuthScreen(),
                routes: {
                  '/auth': (context) => const AuthScreen(),
                  '/map': (context) => const MainNavigator(initialIndex: 0),
                },
              );
            },
          );
        },
      ),
    );
  }
}
