import 'dart:developer' as developer;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

/// FCM Service for handling push notifications
/// Manages Firebase Cloud Messaging token registration and notification handling
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  bool _initialized = false;

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Initialize FCM service
  /// Call this after Firebase.initializeApp() and user authentication
  Future<void> initialize() async {
    if (_initialized) {
      developer.log('FCM already initialized', name: 'FCMService');
      return;
    }

    try {
      // Request notification permissions (iOS)
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        developer.log('User granted notification permission',
            name: 'FCMService');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        developer.log('User granted provisional notification permission',
            name: 'FCMService');
      } else {
        developer.log('User declined notification permission',
            name: 'FCMService');
        return;
      }

      // Initialize local notifications for foreground handling
      await _initializeLocalNotifications();

      // Get FCM token
      _fcmToken = await _messaging.getToken();
      if (_fcmToken != null) {
        developer.log('FCM Token: $_fcmToken', name: 'FCMService');
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        developer.log('FCM Token refreshed: $newToken', name: 'FCMService');
        _fcmToken = newToken;
        // Note: Token refresh should trigger re-registration via auth service
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background message tap
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Handle notification tap when app was terminated
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      _initialized = true;
      developer.log('FCM initialized successfully', name: 'FCMService');
    } catch (e) {
      developer.log('Failed to initialize FCM: $e', name: 'FCMService');
    }
  }

  /// Initialize local notifications plugin for foreground handling
  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleLocalNotificationTap,
    );

    // Create Android notification channel
    const androidChannel = AndroidNotificationChannel(
      'trashmapr_channel',
      'TrashMapr Notifications',
      description: 'Notifications for image processing results',
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Handle foreground messages (when app is open)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    developer.log('Foreground message received: ${message.messageId}',
        name: 'FCMService');

    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null) {
      // Show local notification
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'trashmapr_channel',
            'TrashMapr Notifications',
            channelDescription: 'Notifications for image processing results',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: _encodePayload(message.data),
      );
    }
  }

  /// Handle notification tap (background/terminated)
  void _handleNotificationTap(RemoteMessage message) {
    developer.log('Notification tapped: ${message.data}', name: 'FCMService');
    _processNotificationData(message.data);
  }

  /// Handle local notification tap (foreground)
  void _handleLocalNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      final data = _decodePayload(response.payload!);
      developer.log('Local notification tapped: $data', name: 'FCMService');
      _processNotificationData(data);
    }
  }

  /// Process notification data and navigate accordingly
  void _processNotificationData(Map<String, dynamic> data) {
    final type = data['type'];

    switch (type) {
      case 'image_accepted':
        developer.log('Image accepted notification', name: 'FCMService');
        // TODO: Navigate to my uploads screen or show success dialog
        break;
      case 'image_rejected':
        developer.log('Image rejected notification', name: 'FCMService');
        // TODO: Navigate to camera screen or show retry dialog
        break;
      default:
        developer.log('Unknown notification type: $type', name: 'FCMService');
    }
  }

  /// Encode data payload to JSON string
  String _encodePayload(Map<String, dynamic> data) {
    return data.entries.map((e) => '${e.key}:${e.value}').join('|');
  }

  /// Decode payload string to map
  Map<String, dynamic> _decodePayload(String payload) {
    final map = <String, dynamic>{};
    for (final entry in payload.split('|')) {
      final parts = entry.split(':');
      if (parts.length == 2) {
        map[parts[0]] = parts[1];
      }
    }
    return map;
  }

  /// Register FCM token with backend
  Future<void> registerToken(String idToken) async {
    if (_fcmToken == null) {
      developer.log('No FCM token available to register', name: 'FCMService');
      return;
    }

    await _registerTokenWithBackend(_fcmToken!, idToken);
  }

  /// Internal method to register token with backend
  Future<void> _registerTokenWithBackend(String token, String idToken) async {
    try {
      final apiService = ApiService();
      await apiService.registerFCMToken(token, idToken);
      developer.log('FCM token registered with backend', name: 'FCMService');
    } catch (e) {
      developer.log('Failed to register FCM token: $e', name: 'FCMService');
    }
  }

  /// Unregister FCM token from backend (on logout)
  Future<void> unregisterToken(String idToken) async {
    try {
      final apiService = ApiService();
      await apiService.unregisterFCMToken(idToken);
      developer.log('FCM token unregistered from backend', name: 'FCMService');
    } catch (e) {
      developer.log('Failed to unregister FCM token: $e', name: 'FCMService');
    }
  }

  /// Dispose resources
  void dispose() {
    _initialized = false;
    _fcmToken = null;
  }
}

/// Top-level function for handling background messages
/// Must be a top-level function (not in a class)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  developer.log('Background message received: ${message.messageId}',
      name: 'FCMService');
}
