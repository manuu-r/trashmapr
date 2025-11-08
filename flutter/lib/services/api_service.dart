import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/point.dart';

class ApiService {
  final String baseUrl;

  ApiService() : baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:8000';

  // Public endpoint: Get points in bounds
  Future<List<Point>> getPoints({
    required double swLat,
    required double swLng,
    required double neLat,
    required double neLng,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/points').replace(
        queryParameters: {
          'lat1': swLat.toString(),
          'lng1': swLng.toString(),
          'lat2': neLat.toString(),
          'lng2': neLng.toString(),
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => Point.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load points: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching points: $e');
      rethrow;
    }
  }

  // Protected endpoint: Get signed URL for direct GCS upload
  Future<Map<String, dynamic>> getSignedUploadUrl({
    required double lat,
    required double lng,
    required String idToken,
    String contentType = 'image/jpeg',
  }) async {
    try {
      debugPrint(
          'Requesting signed URL for: lat=$lat, lng=$lng, contentType=$contentType');

      final uri = Uri.parse('$baseUrl/upload/signed-url').replace(
        queryParameters: {
          'lat': lat.toString(),
          'lng': lng.toString(),
          'content_type': contentType,
        },
      );

      final response = await http.post(
        uri,
        headers: {'Authorization': 'Bearer $idToken'},
      );

      debugPrint('Signed URL response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        debugPrint(
            'Got signed URL (expires in ${jsonResponse['expires_in']}s)');
        return jsonResponse;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please sign in again.');
      } else {
        throw Exception(
          'Failed to get signed URL: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error getting signed URL: $e');
      rethrow;
    }
  }

  // Direct GCS upload using signed URL
  Future<void> uploadToGCS({
    required String signedUrl,
    required File imageFile,
    required String contentType,
    Map<String, String>? requiredHeaders,
  }) async {
    try {
      debugPrint('Uploading to GCS with signed URL...');

      final bytes = await imageFile.readAsBytes();
      debugPrint('Image size: ${bytes.length} bytes');

      // Build headers - include metadata headers from backend
      final headers = {
        'Content-Type': contentType,
        'Content-Length': bytes.length.toString(),
        ...?requiredHeaders, // Spread required metadata headers
      };

      debugPrint('Upload headers: $headers');

      final response = await http.put(
        Uri.parse(signedUrl),
        headers: headers,
        body: bytes,
      );

      debugPrint('GCS upload response: ${response.statusCode}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          'Failed to upload to GCS: ${response.statusCode} - ${response.body}',
        );
      }

      debugPrint('Upload to GCS successful!');
    } catch (e) {
      debugPrint('Error uploading to GCS: $e');
      rethrow;
    }
  }

  // Protected endpoint: Upload photo with GPS
  Future<Map<String, dynamic>?> uploadPhoto({
    required File imageFile,
    required double lat,
    required double lng,
    required String idToken,
  }) async {
    try {
      debugPrint('Uploading photo to: $baseUrl/upload?lat=$lat&lng=$lng');

      final uri = Uri.parse('$baseUrl/upload').replace(
        queryParameters: {'lat': lat.toString(), 'lng': lng.toString()},
      );

      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $idToken';

      // Determine MIME type from file extension
      String? mimeType;
      final extension = imageFile.path.toLowerCase().split('.').last;
      if (extension == 'jpg' || extension == 'jpeg') {
        mimeType = 'image/jpeg';
      } else if (extension == 'png') {
        mimeType = 'image/png';
      } else if (extension == 'heic') {
        mimeType = 'image/heic';
      } else {
        mimeType = 'image/jpeg'; // Default to JPEG
      }

      debugPrint('Detected MIME type: $mimeType for file: ${imageFile.path}');

      // Add the image file with correct MIME type
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          contentType: MediaType.parse(mimeType),
        ),
      );

      debugPrint('Sending upload request...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('Upload response: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = json.decode(response.body);
        // Return the upload response with success, message, point_id, category, weight
        return jsonResponse;
      } else if (response.statusCode == 400) {
        // AI rejected the image (trash classification) or bad request
        final errorBody = response.body;
        debugPrint('Upload rejected (400): $errorBody');
        try {
          final errorJson = json.decode(errorBody);
          throw Exception(errorJson['detail'] ?? 'Upload rejected');
        } catch (e) {
          throw Exception('Upload rejected: $errorBody');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please sign in again.');
      } else {
        throw Exception(
          'Upload failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error uploading photo: $e');
      rethrow;
    }
  }

  // Protected endpoint: Get user's uploads
  Future<List<Point>> getMyUploads(String idToken) async {
    try {
      final uri = Uri.parse('$baseUrl/points/my-uploads');

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $idToken'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => Point.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load uploads: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching uploads: $e');
      rethrow;
    }
  }

  // Protected endpoint: Delete upload (stub for now)
  Future<bool> deleteUpload(int pointId, String idToken) async {
    try {
      final uri = Uri.parse('$baseUrl/upload/$pointId');

      final response = await http.delete(
        uri,
        headers: {'Authorization': 'Bearer $idToken'},
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Error deleting upload: $e');
      return false;
    }
  }

  // Protected endpoint: Report a point (stub for future implementation)
  Future<bool> reportPoint(int pointId, String idToken) async {
    try {
      final uri = Uri.parse('$baseUrl/report/$pointId');

      final response = await http.post(
        uri,
        headers: {'Authorization': 'Bearer $idToken'},
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error reporting point: $e');
      return false;
    }
  }

  // Protected endpoint: Register FCM token for push notifications
  Future<void> registerFCMToken(String fcmToken, String idToken) async {
    try {
      debugPrint('Registering FCM token with backend');

      final uri = Uri.parse('$baseUrl/notifications/register-token');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({'fcm_token': fcmToken}),
      );

      if (response.statusCode == 200) {
        debugPrint('FCM token registered successfully');
      } else {
        throw Exception(
          'Failed to register FCM token: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error registering FCM token: $e');
      rethrow;
    }
  }

  // Protected endpoint: Unregister FCM token (on logout)
  Future<void> unregisterFCMToken(String idToken) async {
    try {
      debugPrint('Unregistering FCM token from backend');

      final uri = Uri.parse('$baseUrl/notifications/unregister-token');

      final response = await http.delete(
        uri,
        headers: {'Authorization': 'Bearer $idToken'},
      );

      if (response.statusCode == 200) {
        debugPrint('FCM token unregistered successfully');
      } else {
        throw Exception(
          'Failed to unregister FCM token: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error unregistering FCM token: $e');
      rethrow;
    }
  }
}
