import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/point.dart' as app_models;
import '../services/api_service.dart';
import '../widgets/image_modal.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final ApiService _apiService = ApiService();

  List<app_models.Point> _points = [];
  bool _isLoading = false;
  LatLng _center = const LatLng(37.7749, -122.4194); // Default to SF
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _fetchPoints();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _center = LatLng(position.latitude, position.longitude);
      });

      _mapController.move(_center, 13.0);
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  void _onMapEvent(MapEvent event) {
    // Debounce map events to reduce API calls
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _fetchPoints();
    });
  }

  Future<void> _fetchPoints() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final bounds = _mapController.camera.visibleBounds;

      final points = await _apiService.getPoints(
        swLat: bounds.south,
        swLng: bounds.west,
        neLat: bounds.north,
        neLng: bounds.east,
      );

      setState(() {
        _points = points;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading points: $e')));
      }
    }
  }

  Color _getCategoryColor(int category) {
    switch (category) {
      case 1:
        return Colors.blue.withValues(alpha: 0.7);
      case 2:
        return Colors.yellow.withValues(alpha: 0.7);
      case 3:
        return Colors.orange.withValues(alpha: 0.7);
      case 4:
        return Colors.red.withValues(alpha: 0.7);
      default:
        return Colors.grey.withValues(alpha: 0.7);
    }
  }

  String _getCategoryLabel(int category) {
    switch (category) {
      case 1:
        return 'Low Density';
      case 2:
        return 'Medium Density';
      case 3:
        return 'High Density';
      case 4:
        return 'Very High Density';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 13.0,
              onMapEvent: _onMapEvent,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.trashmapr.app',
              ),
              // Heatmap circles based on weight
              CircleLayer(
                circles: _points.map((point) {
                  return CircleMarker(
                    point: LatLng(point.location.lat, point.location.lng),
                    radius: 20 + (point.weight * 30), // Radius based on weight
                    color: _getCategoryColor(point.category),
                    borderColor: _getCategoryColor(
                      point.category,
                    ).withValues(alpha: 0.3),
                    borderStrokeWidth: 2,
                  );
                }).toList(),
              ),
              // Marker layer for clickable pins
              MarkerLayer(
                markers: _points.map((point) {
                  return Marker(
                    point: LatLng(point.location.lat, point.location.lng),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => ImageModal(point: point),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.network(
                            point.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: _getCategoryColor(point.category),
                                child: const Icon(
                                  Icons.photo,
                                  color: Colors.white,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          // Loading indicator
          if (_isLoading)
            const Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Loading points...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Legend
          Positioned(
            bottom: 80,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Density Legend',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(4, (index) {
                      final category = index + 1;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: _getCategoryColor(category),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getCategoryLabel(category),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
          // Current location button
          Positioned(
            bottom: 160,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'location',
              onPressed: _getCurrentLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
