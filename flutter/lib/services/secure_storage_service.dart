import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

/// Service for securely storing sensitive data like authentication tokens
///
/// Uses platform-specific secure storage:
/// - iOS: Keychain
/// - Android: EncryptedSharedPreferences (AES encryption)
/// - Linux: libsecret
/// - macOS: Keychain
/// - Windows: Windows Credential Manager
/// - Web: Not recommended for production (uses browser storage)
class SecureStorageService {
  static final SecureStorageService _instance =
      SecureStorageService._internal();

  factory SecureStorageService() => _instance;

  SecureStorageService._internal();

  // Storage keys
  static const String _keyIdToken = 'id_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserName = 'user_name';
  static const String _keyUserPicture = 'user_picture';
  static const String _keyBackendValidated = 'backend_validated';
  static const String _keyTokenExpiry = 'token_expiry';

  // Android-specific options for better security
  static const AndroidOptions _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
    resetOnError: true,
  );

  // iOS-specific options
  static const IOSOptions _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
    synchronizable: false,
  );

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: _androidOptions,
    iOptions: _iosOptions,
  );

  /// Save authentication token
  Future<void> saveIdToken(String token) async {
    try {
      await _storage.write(key: _keyIdToken, value: token);
      debugPrint('SecureStorage: ID token saved');
    } catch (e) {
      debugPrint('SecureStorage: Error saving ID token: $e');
      rethrow;
    }
  }

  /// Get authentication token
  Future<String?> getIdToken() async {
    try {
      final token = await _storage.read(key: _keyIdToken);
      debugPrint(
          'SecureStorage: ID token retrieved: ${token != null ? "✓" : "✗"}');
      return token;
    } catch (e) {
      debugPrint('SecureStorage: Error reading ID token: $e');
      return null;
    }
  }

  /// Save refresh token (if your OAuth flow uses refresh tokens)
  Future<void> saveRefreshToken(String token) async {
    try {
      await _storage.write(key: _keyRefreshToken, value: token);
      debugPrint('SecureStorage: Refresh token saved');
    } catch (e) {
      debugPrint('SecureStorage: Error saving refresh token: $e');
      rethrow;
    }
  }

  /// Get refresh token
  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _keyRefreshToken);
    } catch (e) {
      debugPrint('SecureStorage: Error reading refresh token: $e');
      return null;
    }
  }

  /// Save user profile data
  Future<void> saveUserProfile({
    required String id,
    required String email,
    required String name,
    String? picture,
  }) async {
    try {
      await Future.wait([
        _storage.write(key: _keyUserId, value: id),
        _storage.write(key: _keyUserEmail, value: email),
        _storage.write(key: _keyUserName, value: name),
        if (picture != null)
          _storage.write(key: _keyUserPicture, value: picture),
      ]);
      debugPrint('SecureStorage: User profile saved');
    } catch (e) {
      debugPrint('SecureStorage: Error saving user profile: $e');
      rethrow;
    }
  }

  /// Get user profile data
  Future<Map<String, String?>> getUserProfile() async {
    try {
      final results = await Future.wait([
        _storage.read(key: _keyUserId),
        _storage.read(key: _keyUserEmail),
        _storage.read(key: _keyUserName),
        _storage.read(key: _keyUserPicture),
      ]);

      return {
        'id': results[0],
        'email': results[1],
        'name': results[2],
        'picture': results[3],
      };
    } catch (e) {
      debugPrint('SecureStorage: Error reading user profile: $e');
      return {};
    }
  }

  /// Save backend validation status
  Future<void> saveBackendValidated(bool validated) async {
    try {
      await _storage.write(
        key: _keyBackendValidated,
        value: validated.toString(),
      );
      debugPrint('SecureStorage: Backend validation status saved: $validated');
    } catch (e) {
      debugPrint('SecureStorage: Error saving backend validation: $e');
    }
  }

  /// Get backend validation status
  Future<bool> getBackendValidated() async {
    try {
      final value = await _storage.read(key: _keyBackendValidated);
      return value == 'true';
    } catch (e) {
      debugPrint('SecureStorage: Error reading backend validation: $e');
      return false;
    }
  }

  /// Save token expiry time
  Future<void> saveTokenExpiry(DateTime expiry) async {
    try {
      await _storage.write(
        key: _keyTokenExpiry,
        value: expiry.toIso8601String(),
      );
      debugPrint('SecureStorage: Token expiry saved: $expiry');
    } catch (e) {
      debugPrint('SecureStorage: Error saving token expiry: $e');
    }
  }

  /// Get token expiry time
  Future<DateTime?> getTokenExpiry() async {
    try {
      final value = await _storage.read(key: _keyTokenExpiry);
      if (value != null) {
        return DateTime.parse(value);
      }
      return null;
    } catch (e) {
      debugPrint('SecureStorage: Error reading token expiry: $e');
      return null;
    }
  }

  /// Check if stored token is expired
  Future<bool> isTokenExpired() async {
    final expiry = await getTokenExpiry();
    if (expiry == null) return true;
    return DateTime.now().isAfter(expiry);
  }

  /// Clear all authentication data
  Future<void> clearAuthData() async {
    try {
      await Future.wait([
        _storage.delete(key: _keyIdToken),
        _storage.delete(key: _keyRefreshToken),
        _storage.delete(key: _keyUserId),
        _storage.delete(key: _keyUserEmail),
        _storage.delete(key: _keyUserName),
        _storage.delete(key: _keyUserPicture),
        _storage.delete(key: _keyBackendValidated),
        _storage.delete(key: _keyTokenExpiry),
      ]);
      debugPrint('SecureStorage: All auth data cleared');
    } catch (e) {
      debugPrint('SecureStorage: Error clearing auth data: $e');
      rethrow;
    }
  }

  /// Clear ALL stored data (use with caution)
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
      debugPrint('SecureStorage: All data cleared');
    } catch (e) {
      debugPrint('SecureStorage: Error clearing all data: $e');
      rethrow;
    }
  }

  /// Check if user has stored credentials
  Future<bool> hasStoredCredentials() async {
    final token = await getIdToken();
    final backendValidated = await getBackendValidated();
    final isExpired = await isTokenExpired();

    final hasCredentials = token != null && backendValidated && !isExpired;
    debugPrint('SecureStorage: Has valid stored credentials: $hasCredentials');
    return hasCredentials;
  }

  /// Get all stored keys (for debugging)
  Future<Map<String, String>> getAllStoredData() async {
    try {
      final all = await _storage.readAll();
      debugPrint('SecureStorage: Retrieved ${all.length} items');
      return all;
    } catch (e) {
      debugPrint('SecureStorage: Error reading all data: $e');
      return {};
    }
  }
}
