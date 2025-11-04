import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService extends ChangeNotifier {
  GoogleSignInAccount? _currentUser;
  String? _idToken;
  bool _isLoading = false;

  GoogleSignInAccount? get currentUser => _currentUser;
  String? get idToken => _idToken;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null && _idToken != null;

  AuthService() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final signIn = GoogleSignIn.instance;
      await signIn.initialize();

      // Listen to authentication events
      signIn.authenticationEvents.listen((event) {
        switch (event) {
          case GoogleSignInAuthenticationEventSignIn():
            _currentUser = event.user;
            _refreshToken();
          case GoogleSignInAuthenticationEventSignOut():
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
    if (_currentUser != null) {
      try {
        final auth = _currentUser!.authentication;
        _idToken = auth.idToken;
        notifyListeners();
      } catch (error) {
        debugPrint('Error refreshing token: $error');
      }
    }
  }

  Future<bool> signIn() async {
    _isLoading = true;
    notifyListeners();

    try {
      await GoogleSignIn.instance.authenticate();
      _isLoading = false;
      notifyListeners();
      return _currentUser != null;
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
    if (_currentUser != null) {
      await _refreshToken();
      return _idToken;
    }
    return null;
  }
}
