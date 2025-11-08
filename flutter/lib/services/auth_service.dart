import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import '../models/user.dart';
import 'secure_storage_service.dart';
import 'fcm_service.dart';

class AuthService extends ChangeNotifier {
  GoogleSignInAccount? _googleUser;
  User? _currentUser;
  String? _idToken;
  bool _isLoading = false;
  String? _authError;
  final String _baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:8000';
  final SecureStorageService _secureStorage = SecureStorageService();

  // Constants
  static const String _serverClientId =
      '372775247083-01af5rmum5eget5cd6goucrvrvh1v8vh.apps.googleusercontent.com';
  static const Duration _tokenExpiry = Duration(hours: 1);
  static const Duration _apiTimeout = Duration(seconds: 10);

  User? get currentUser => _currentUser;
  String? get idToken => _idToken;
  bool get isLoading => _isLoading;
  String? get authError => _authError;
  bool get isAuthenticated => _currentUser != null && _idToken != null;

  AuthService() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
      await _restoreSession();
    } catch (error) {
      debugPrint('AuthService: Error initializing: $error');
    }
  }

  /// Build API URL for user endpoint
  String get _userEndpoint => '$_baseUrl/users/me';

  /// Build authorization headers
  Map<String, String> get _authHeaders => {'Authorization': 'Bearer $_idToken'};

  /// Fetch user from backend
  Future<User?> _fetchUserFromBackend() async {
    if (_idToken == null) return null;

    try {
      final response = await http
          .get(Uri.parse(_userEndpoint), headers: _authHeaders)
          .timeout(_apiTimeout);

      if (response.statusCode == 200) {
        return User.fromJson(json.decode(response.body));
      }

      debugPrint('AuthService: Backend returned ${response.statusCode}');
      return null;
    } catch (error) {
      debugPrint('AuthService: Error fetching user: $error');
      return null;
    }
  }

  /// Restore session from secure storage
  Future<void> _restoreSession() async {
    try {
      debugPrint('AuthService: Attempting to restore session...');

      if (!await _secureStorage.hasStoredCredentials()) {
        debugPrint('AuthService: No stored credentials');
        return;
      }

      final storedToken = await _secureStorage.getIdToken();
      final storedProfile = await _secureStorage.getUserProfile();

      if (storedToken == null || storedProfile['email'] == null) {
        debugPrint('AuthService: Incomplete data');
        await _secureStorage.clearAuthData();
        return;
      }

      _idToken = storedToken;
      _currentUser = _buildUserFromStorage(storedProfile);

      debugPrint('AuthService: Session restored');
      notifyListeners();

      // Validate in background
      _validateStoredToken();
    } catch (error) {
      debugPrint('AuthService: Error restoring session: $error');
      await _secureStorage.clearAuthData();
    }
  }

  /// Build User from storage profile
  User _buildUserFromStorage(Map<String, String?> profile) {
    return User(
      id: int.tryParse(profile['id'] ?? '0') ?? 0,
      email: profile['email']!,
      displayName: profile['name'],
      photoUrl: profile['picture'],
      totalPoints: 0,
      totalUploads: 0,
      createdAt: DateTime.now(),
    );
  }

  /// Validate stored token in background
  Future<void> _validateStoredToken() async {
    final user = await _fetchUserFromBackend();

    if (user == null) {
      debugPrint('AuthService: Token invalid, clearing session');
      await _logout();
      notifyListeners();
    }
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error and loading state
  void _setError(String error) {
    _authError = error;
    _isLoading = false;
    notifyListeners();
  }

  /// Main sign-in flow: GAuth -> token -> fetch/create user -> if failed logout, else login
  Future<bool> signIn() async {
    _setLoading(true);
    _authError = null;

    try {
      // Step 1: Google Authentication
      debugPrint('AuthService: Starting Google Sign-In...');
      _googleUser = await GoogleSignIn.instance.authenticate();

      if (_googleUser == null) {
        _setError('Google Sign-In cancelled');
        return false;
      }

      // Step 2: Get token
      debugPrint('AuthService: Getting token...');
      _idToken = _googleUser!.authentication.idToken;

      if (_idToken == null) {
        _setError('Failed to get token');
        await _logout();
        return false;
      }

      // Step 3: Fetch/create user from backend
      debugPrint('AuthService: Validating with backend...');
      _currentUser = await _fetchUserFromBackend();

      // Step 4: If failed - logout
      if (_currentUser == null) {
        _setError('Authentication failed');
        debugPrint('AuthService: Backend validation failed');
        await _logout();
        return false;
      }

      // Step 5: Success - login
      _authError = null;
      await _saveToSecureStorage();

      // Step 6: Register FCM token for push notifications
      await _registerFCMToken();

      debugPrint('AuthService: Sign-in successful');
      _setLoading(false);
      return true;
    } catch (error) {
      debugPrint('AuthService: Sign-in error: $error');
      _setError(error.toString().contains('timeout')
          ? 'Cannot connect to server'
          : 'Sign-in failed');
      await _logout();
      return false;
    }
  }

  /// Save to secure storage
  Future<void> _saveToSecureStorage() async {
    if (_idToken == null || _currentUser == null) return;

    try {
      await Future.wait([
        _secureStorage.saveIdToken(_idToken!),
        _secureStorage.saveUserProfile(
          id: _currentUser!.id.toString(),
          email: _currentUser!.email,
          name: _currentUser!.displayName ?? '',
          picture: _currentUser!.photoUrl,
        ),
        _secureStorage.saveBackendValidated(true),
        _secureStorage.saveTokenExpiry(DateTime.now().add(_tokenExpiry)),
      ]);
      debugPrint('AuthService: Data saved to secure storage');
    } catch (error) {
      debugPrint('AuthService: Error saving to storage: $error');
    }
  }

  /// Register FCM token with backend
  Future<void> _registerFCMToken() async {
    debugPrint('AuthService: _registerFCMToken called');

    if (_idToken == null) {
      debugPrint('AuthService: No idToken available for FCM registration');
      return;
    }

    try {
      debugPrint('AuthService: Initializing FCM service...');
      final fcmService = FCMService();

      // Initialize FCM if not already initialized
      await fcmService.initialize();
      debugPrint('AuthService: FCM service initialized');

      // Wait a moment for token to be obtained
      await Future.delayed(const Duration(milliseconds: 500));

      // Register token with backend if we have one
      if (fcmService.fcmToken != null) {
        debugPrint('AuthService: FCM token found, registering with backend...');
        debugPrint(
            'AuthService: Token: ${fcmService.fcmToken?.substring(0, 20)}...');
        await fcmService.registerToken(_idToken!);
        debugPrint('AuthService: FCM token registered successfully');
      } else {
        debugPrint('AuthService: No FCM token available yet');
      }
    } catch (error, stackTrace) {
      debugPrint('AuthService: Error registering FCM token: $error');
      debugPrint('AuthService: Stack trace: $stackTrace');
      // Don't fail login if FCM registration fails
    }
  }

  /// Unregister FCM token from backend
  Future<void> _unregisterFCMToken() async {
    if (_idToken == null) return;

    try {
      final fcmService = FCMService();
      await fcmService.unregisterToken(_idToken!);
      debugPrint('AuthService: FCM token unregistered');
    } catch (error) {
      debugPrint('AuthService: Error unregistering FCM token: $error');
      // Don't fail logout if FCM unregistration fails
    }
  }

  /// Logout - clear everything
  Future<void> _logout() async {
    try {
      // Unregister FCM token before logout
      await _unregisterFCMToken();

      await GoogleSignIn.instance.disconnect();
      await _secureStorage.clearAuthData();
    } catch (error) {
      debugPrint('AuthService: Error during logout: $error');
    }

    _googleUser = null;
    _currentUser = null;
    _idToken = null;
    _authError = null;
  }

  /// Refresh user data from backend (e.g., after points update)
  Future<void> refreshUser() async {
    if (_idToken == null) return;

    try {
      debugPrint('AuthService: Refreshing user data...');
      final updatedUser = await _fetchUserFromBackend();

      if (updatedUser != null) {
        _currentUser = updatedUser;
        await _saveToSecureStorage();
        notifyListeners();
        debugPrint(
            'AuthService: User data refreshed - Points: ${updatedUser.totalPoints}');
      }
    } catch (error) {
      debugPrint('AuthService: Error refreshing user: $error');
    }
  }

  /// Public sign-out
  Future<void> signOut() async {
    _setLoading(true);
    await _logout();
    _setLoading(false);
    debugPrint('AuthService: User signed out');
  }

  /// Get valid token for API calls
  Future<String?> getValidToken() async {
    if (await _secureStorage.isTokenExpired() && _googleUser != null) {
      debugPrint('AuthService: Refreshing expired token...');
      _idToken = _googleUser!.authentication.idToken;
      await Future.wait([
        _secureStorage.saveIdToken(_idToken!),
        _secureStorage.saveTokenExpiry(DateTime.now().add(_tokenExpiry)),
      ]);
    }
    return _idToken;
  }

  /// Refresh user data (e.g., after upload)
  Future<void> refreshUserData() async {
    if (_idToken == null) return;

    final user = await _fetchUserFromBackend();

    if (user != null) {
      _currentUser = user;
      await _saveToSecureStorage();
      notifyListeners();
    }
  }
}
