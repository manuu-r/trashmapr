import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import '../models/user.dart';

class AuthService extends ChangeNotifier {
  GoogleSignInAccount? _googleUser;
  User? _currentUser;
  String? _idToken;
  bool _isLoading = false;
  final String _baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:8000';

  User? get currentUser => _currentUser;
  String? get idToken => _idToken;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _googleUser != null && _idToken != null;

  AuthService() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final signIn = GoogleSignIn.instance;
      await signIn.initialize(
        serverClientId:
            '372775247083-01af5rmum5eget5cd6goucrvrvh1v8vh.apps.googleusercontent.com',
      );

      // Listen to authentication events
      signIn.authenticationEvents.listen((event) {
        switch (event) {
          case GoogleSignInAuthenticationEventSignIn():
            _googleUser = event.user;
            _refreshToken();
            _fetchUserData();
          case GoogleSignInAuthenticationEventSignOut():
            _googleUser = null;
            _currentUser = null;
            _idToken = null;
            notifyListeners();
        }
      });

      // Attempt lightweight authentication (silent sign-in)
      signIn.attemptLightweightAuthentication();
    } catch (error) {
      debugPrint('Error initializing Google Sign-In: $error');
    }
  }

  Future<void> _refreshToken() async {
    if (_googleUser != null) {
      try {
        final auth = _googleUser!.authentication;
        _idToken = auth.idToken;
        notifyListeners();
      } catch (error) {
        debugPrint('Error refreshing token: $error');
      }
    }
  }

  Future<void> _fetchUserData() async {
    if (_idToken == null) return;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/me'),
        headers: {
          'Authorization': 'Bearer $_idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _currentUser = User.fromJson(data);
        notifyListeners();
      } else {
        debugPrint('Failed to fetch user data: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint('Error fetching user data: $error');
    }
  }

  // Public method to refresh user data (e.g., after upload)
  Future<void> refreshUserData() async {
    await _fetchUserData();
  }

  Future<bool> signIn() async {
    _isLoading = true;
    notifyListeners();

    try {
      await GoogleSignIn.instance.authenticate();
      _isLoading = false;
      notifyListeners();
      return _googleUser != null;
    } catch (error) {
      debugPrint('Error signing in: $error');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await GoogleSignIn.instance.disconnect();
    } catch (error) {
      debugPrint('Error signing out: $error');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Ensure token is fresh (for API calls)
  Future<String?> getValidToken() async {
    if (_googleUser != null) {
      await _refreshToken();
      return _idToken;
    }
    return null;
  }
}
