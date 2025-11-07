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
}
