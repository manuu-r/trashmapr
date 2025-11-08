import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../services/fcm_service.dart';
import '../screens/map_screen.dart';
import '../screens/capture_screen.dart';
import '../screens/uploads_screen.dart';
import 'profile_modal.dart';

class MainNavigator extends StatefulWidget {
  final int initialIndex;

  const MainNavigator({super.key, this.initialIndex = 0});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _initializeFCM();
  }

  /// Initialize FCM service for push notifications
  Future<void> _initializeFCM() async {
    try {
      final fcmService = FCMService();
      await fcmService.initialize();
      debugPrint('MainNavigator: FCM initialized');
    } catch (e) {
      debugPrint('MainNavigator: FCM initialization error: $e');
    }
  }

  final List<Widget> _screens = const [
    MapScreen(),
    CaptureScreen(),
    UploadsScreen(),
  ];

  void _showProfileModal(BuildContext context, AuthService authService) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (context) => ProfileModal(authService: authService),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final themeService = Provider.of<ThemeService>(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        actions: [
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.rotate(
                angle: value * 3.14159, // 180 degrees on theme change
                child: child,
              );
            },
            child: IconButton(
              icon: Icon(
                themeService.themeMode == ThemeMode.dark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
              ),
              onPressed: () {
                themeService.toggleTheme();
              },
              tooltip: 'Toggle theme',
            ),
          ),
          if (authService.isAuthenticated)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: InkWell(
                onTap: () => _showProfileModal(context, authService),
                borderRadius: BorderRadius.circular(20),
                child: authService.currentUser?.photoUrl != null
                    ? CircleAvatar(
                        radius: 18,
                        backgroundImage: NetworkImage(
                          authService.currentUser!.photoUrl!,
                        ),
                      )
                    : const CircleAvatar(
                        radius: 18,
                        child: Icon(Icons.person, size: 22),
                      ),
              ),
            )
          else
            TextButton.icon(
              onPressed: () async {
                await authService.signIn();
              },
              icon: const Icon(Icons.login),
              label: const Text('Sign In'),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.02),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        child: IndexedStack(
          key: ValueKey<int>(_currentIndex),
          index: _currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              tween: Tween(begin: 1.0, end: _currentIndex == 0 ? 1.0 : 1.0),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: const Icon(Icons.map_outlined),
            ),
            selectedIcon: const Icon(Icons.map_rounded),
            label: 'Map',
          ),
          NavigationDestination(
            icon: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              tween: Tween(begin: 1.0, end: _currentIndex == 1 ? 1.0 : 1.0),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: const Icon(Icons.camera_alt_outlined),
            ),
            selectedIcon: const Icon(Icons.camera_alt_rounded),
            label: 'Capture',
          ),
          NavigationDestination(
            icon: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              tween: Tween(begin: 1.0, end: _currentIndex == 2 ? 1.0 : 1.0),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: const Icon(Icons.cloud_upload_outlined),
            ),
            selectedIcon: const Icon(Icons.cloud_upload_rounded),
            label: 'My Uploads',
          ),
        ],
      ),
    );
  }
}
