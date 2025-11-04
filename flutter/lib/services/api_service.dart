import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
  Future<Point?> uploadPhoto({
    required File imageFile,
    required double lat,
    required double lng,
    required String idToken,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/upload').replace(
        queryParameters: {'lat': lat.toString(), 'lng': lng.toString()},
      );

      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $idToken';

      // Add the image file
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = json.decode(response.body);
        return Point.fromJson(jsonResponse);
      } else if (response.statusCode == 400) {
        // AI rejected the image (trash classification)
        debugPrint('Image rejected by AI: ${response.body}');
        return null;
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
      final uri = Uri.parse('$baseUrl/my-uploads');

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
  Future<bool> deleteUpload(String pointId, String idToken) async {
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
  Future<bool> reportPoint(String pointId, String idToken) async {
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
