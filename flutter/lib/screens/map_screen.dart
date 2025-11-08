import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  GoogleMapController? _mapController;
  final ApiService _apiService = ApiService();

  List<app_models.Point> _points = [];
  Set<Marker> _markers = {};
  Set<Heatmap> _heatmaps = {};
  bool _isLoading = false;
  LatLng _center = const LatLng(12.9716, 77.5946); // Default to Bengaluru
  Timer? _debounceTimer;
  bool _showHeatmap = true;
  double _currentZoom = 13.0;
  static const double _zoomThresholdForThumbnails = 15.0;

  // Custom map style to hide all POIs, landmarks, transit, and other markers
  static const String _mapStyle = '''
    [
      {
        "featureType": "poi",
        "stylers": [{"visibility": "off"}]
      },
      {
        "featureType": "poi.business",
        "stylers": [{"visibility": "off"}]
      },
      {
        "featureType": "poi.park",
        "stylers": [{"visibility": "off"}]
      },
      {
        "featureType": "transit",
        "stylers": [{"visibility": "off"}]
      },
      {
        "featureType": "transit.station",
        "stylers": [{"visibility": "off"}]
      },
      {
        "featureType": "landscape.man_made",
        "elementType": "labels",
        "stylers": [{"visibility": "off"}]
      },
      {
        "featureType": "administrative.land_parcel",
        "elementType": "labels",
        "stylers": [{"visibility": "off"}]
      }
    ]
    ''';

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mapController?.dispose();
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

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_center, 13.0),
      );

      _fetchPoints();
    } catch (e) {
      debugPrint('Error getting location: $e');
      _fetchPoints();
    }
  }

  void _onCameraMove(CameraPosition position) {
    final previousZoom = _currentZoom;
    _currentZoom = position.zoom;

    // Debounce map events to reduce API calls
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _fetchPoints();
    });

    // Update markers immediately if we crossed the zoom threshold
    if ((previousZoom < _zoomThresholdForThumbnails &&
            _currentZoom >= _zoomThresholdForThumbnails) ||
        (previousZoom >= _zoomThresholdForThumbnails &&
            _currentZoom < _zoomThresholdForThumbnails)) {
      _updateMarkers();
    }
  }

  Future<void> _fetchPoints() async {
    if (_isLoading || _mapController == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final bounds = await _mapController!.getVisibleRegion();

      final points = await _apiService.getPoints(
        swLat: bounds.southwest.latitude,
        swLng: bounds.southwest.longitude,
        neLat: bounds.northeast.latitude,
        neLng: bounds.northeast.longitude,
      );

      if (mounted) {
        setState(() {
          _points = points;
          _isLoading = false;
        });

        await _updateMarkers();
        _updateHeatmap();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading points: $e')),
        );
      }
    }
  }

  Future<void> _updateMarkers() async {
    final Set<Marker> markers = {};

    // Only show thumbnail markers when zoomed in close enough
    final bool showThumbnails = _currentZoom >= _zoomThresholdForThumbnails;

    for (final point in _points) {
      Uint8List iconBytes;

      if (showThumbnails) {
        // Create thumbnail pin markers with circular images when zoomed in
        iconBytes = await _createThumbnailMarkerIcon(
          point.imageUrl,
          point.category,
        );
      } else {
        // Use simple colored dot marker when zoomed out
        iconBytes = await _createSimpleDotMarker(point.category);
      }

      markers.add(
        Marker(
          markerId: MarkerId(point.id.toString()),
          position: LatLng(point.location.lat, point.location.lng),
          icon: BitmapDescriptor.bytes(iconBytes),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => ImageModal(point: point),
            );
          },
        ),
      );
    }

    if (mounted) {
      setState(() {
        _markers = markers;
      });
    }
  }

  // Create clean circular thumbnail marker like Google Maps
  Future<Uint8List> _createThumbnailMarkerIcon(
    String imageUrl,
    int category,
  ) async {
    try {
      // Load image from network
      final ByteData data =
          await NetworkAssetBundle(Uri.parse(imageUrl)).load(imageUrl);
      final Uint8List bytes = data.buffer.asUint8List();

      // Decode image
      final ui.Codec codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 96,
        targetHeight: 96,
      );
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image thumbnailImage = frameInfo.image;

      return await _drawCircularThumbnail(thumbnailImage, category);
    } catch (e) {
      debugPrint('Error loading thumbnail for marker: $e');
      // Return fallback circular marker with category color
      return await _createFallbackCircularMarker(category);
    }
  }

  Future<Uint8List> _drawCircularThumbnail(ui.Image image, int category) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Dimensions for clean circular thumbnail
    final double size = 48.0;
    final double radius = size / 2;
    final double borderWidth = 4.0;

    final color = _getCategoryColor(category);

    // Draw shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(radius + 1, radius + 1), radius, shadowPaint);

    // Draw colored border
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(radius, radius), radius, borderPaint);

    // Clip to circle and draw image
    final clipPath = Path()
      ..addOval(Rect.fromCircle(
          center: Offset(radius, radius), radius: radius - borderWidth));
    canvas.clipPath(clipPath);

    // Draw image
    final imageRect = Rect.fromCircle(
        center: Offset(radius, radius), radius: radius - borderWidth);
    paintImage(
      canvas: canvas,
      rect: imageRect,
      image: image,
      fit: BoxFit.cover,
    );

    final picture = recorder.endRecording();
    final finalImage = await picture.toImage(size.toInt(), size.toInt());
    final byteData =
        await finalImage.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  // Simple dot marker for zoomed out view
  Future<Uint8List> _createSimpleDotMarker(int category) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final double size = 24.0;
    final double radius = size / 2;
    final color = _getCategoryColor(category);

    // Draw shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(Offset(radius + 1, radius + 1), radius - 2, shadowPaint);

    // Draw main circle
    final circlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(radius, radius), radius - 2, circlePaint);

    // Draw white border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(radius, radius), radius - 3, borderPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  // Fallback circular marker when image fails to load
  Future<Uint8List> _createFallbackCircularMarker(int category) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final double size = 48.0;
    final double radius = size / 2;
    final color = _getCategoryColor(category);

    // Draw shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(radius + 1, radius + 1), radius, shadowPaint);

    // Draw colored circle
    final circlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(radius, radius), radius, circlePaint);

    // Draw camera icon in center
    final icon = Icons.photo_camera;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: 24,
        fontFamily: icon.fontFamily,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        radius - textPainter.width / 2,
        radius - textPainter.height / 2,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  void _updateHeatmap() {
    if (!mounted) return;

    if (!_showHeatmap || _points.isEmpty) {
      setState(() {
        _heatmaps = {};
      });
      return;
    }

    // Create weighted points for heatmap
    final List<WeightedLatLng> heatmapData = _points.map((point) {
      return WeightedLatLng(
        LatLng(point.location.lat, point.location.lng),
        weight: point.weight,
      );
    }).toList();

    // Create a proper gradient heatmap matching React's gradient:
    // green (clean) -> yellow -> red (high density)
    final heatmap = Heatmap(
      heatmapId: const HeatmapId('density_heatmap'),
      data: heatmapData,
      gradient: const HeatmapGradient(
        <HeatmapGradientColor>[
          HeatmapGradientColor(
              Color.fromARGB(0, 0, 255, 0), 0.0), // Transparent green
          HeatmapGradientColor(
              Color.fromARGB(255, 0, 255, 0), 0.3), // Green (clean)
          HeatmapGradientColor(
              Color.fromARGB(255, 255, 255, 0), 0.6), // Yellow (medium)
          HeatmapGradientColor(
              Color.fromARGB(255, 255, 0, 0), 1.0), // Red (high density)
        ],
      ),
      opacity: 0.8,
      radius: const HeatmapRadius.fromPixels(20), // Match React radius
      dissipating: true,
    );

    if (mounted) {
      setState(() {
        _heatmaps = {heatmap};
      });
    }
  }

  Color _getCategoryColor(int category) {
    switch (category) {
      case 1:
        return const Color(0xFF00FF00); // Green
      case 2:
        return const Color(0xFFFFFF00); // Yellow
      case 3:
        return const Color(0xFFFF8800); // Orange
      case 4:
        return const Color(0xFFFF0000); // Red
      default:
        return Colors.grey;
    }
  }

  String _getCategoryLabel(int category) {
    switch (category) {
      case 1:
        return 'Low';
      case 2:
        return 'Medium';
      case 3:
        return 'High';
      case 4:
        return 'Very High';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              _fetchPoints();
            },
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: 13.0,
            ),
            onCameraMove: _onCameraMove,
            markers: _markers,
            heatmaps: _heatmaps,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            // Hide POI business markers and transit icons
            buildingsEnabled: false,
            trafficEnabled: false,
            style: _mapStyle,
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
          // Glassmorphic legend in top-right corner
          Positioned(
            top: 16,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Density',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 10),
                      ...List.generate(4, (index) {
                        final category = index + 1;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(category),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _getCategoryColor(category)
                                          .withValues(alpha: 0.4),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _getCategoryLabel(category),
                                style: Theme.of(context).textTheme.bodySmall,
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
          ),
          // Current location button
          Positioned(
            bottom: 110,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _getCurrentLocation,
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          Icons.my_location,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
