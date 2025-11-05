import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;
  File? _capturedImage;
  Position? _currentPosition;
  final ApiService _apiService = ApiService();
  int _currentCameraIndex = 0;
  bool _isSwitchingCamera = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Properly dispose camera controller to free buffers
    _cameraController?.dispose();
    _cameraController = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      // Pause camera when app is inactive to prevent buffer issues
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      // Resume camera when app comes back
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras!.isEmpty) {
        throw Exception('No cameras available');
      }

      // Start with rear camera by default (index 0)
      // User can switch using the flip camera button
      _cameraController = CameraController(
        _cameras![_currentCameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      // Reduce image stream to prevent buffer overflow
      await _cameraController!.setFocusMode(FocusMode.auto);

      // Lock capture orientation to prevent buffer issues during rotation
      await _cameraController!.lockCaptureOrientation();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Camera error: $e')));
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2 || _isSwitchingCamera) {
      return;
    }

    setState(() {
      _isSwitchingCamera = true;
      _isInitialized = false;
    });

    // Dispose current controller
    await _cameraController?.dispose();

    // Switch to next camera
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras!.length;

    // Initialize new camera
    _cameraController = CameraController(
      _cameras![_currentCameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _cameraController!.initialize();

      // Reduce image stream to prevent buffer overflow
      await _cameraController!.setFocusMode(FocusMode.auto);

      // Lock capture orientation to prevent buffer issues during rotation
      await _cameraController!.lockCaptureOrientation();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isSwitchingCamera = false;
        });
      }
    } catch (e) {
      debugPrint('Error switching camera: $e');
      if (mounted) {
        setState(() {
          _isSwitchingCamera = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera switch error: $e')),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        final newPermission = await Geolocator.requestPermission();
        if (newPermission == LocationPermission.denied ||
            newPermission == LocationPermission.deniedForever) {
          throw Exception('Location permission denied');
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Location error: $e')));
      }
    }
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waiting for GPS location...')),
      );
      await _getCurrentLocation();
      return;
    }

    try {
      final image = await _cameraController!.takePicture();
      setState(() {
        _capturedImage = File(image.path);
      });
    } catch (e) {
      debugPrint('Error capturing photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Capture error: $e')));
      }
    }
  }

  Future<void> _uploadPhoto() async {
    if (_capturedImage == null || _currentPosition == null) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getValidToken();

    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to upload photos')),
        );
      }
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final response = await _apiService.uploadPhoto(
        imageFile: _capturedImage!,
        lat: _currentPosition!.latitude,
        lng: _currentPosition!.longitude,
        idToken: token,
      );

      // Clean up the captured image file after successful upload
      if (_capturedImage != null) {
        _capturedImage!.delete().catchError((e) {
          debugPrint('Error deleting temp file: $e');
          return _capturedImage!; // Return the file on error
        });
      }

      setState(() {
        _isProcessing = false;
        _capturedImage = null;
      });

      if (mounted && response != null) {
        final success = response['success'] ?? false;
        final message = response['message'] ?? 'Upload completed';
        final category = response['category'];
        final weight = response['weight'];

        if (success) {
          // Refresh user points after successful upload
          await authService.refreshUserData();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '$message\n+250 points • Category: $category, Weight: ${weight?.toStringAsFixed(2) ?? 'N/A'}',
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      // Refresh location for next capture
      _getCurrentLocation();
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      if (mounted) {
        // Parse error message if possible
        String errorMessage = e.toString();
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring(11);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _cancelCapture() {
    // Clean up the captured image file
    if (_capturedImage != null) {
      _capturedImage!.delete().catchError((e) {
        debugPrint('Error deleting temp file: $e');
        return _capturedImage!; // Return the file on error
      });
    }
    setState(() {
      _capturedImage = null;
    });
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    if (!authService.isAuthenticated) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.camera_alt,
                  size: 80,
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.5),
                ),
                const SizedBox(height: 24),
                Text(
                  'Sign in Required',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'You need to sign in with Google to capture and upload photos.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    await authService.signIn();
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Sign In'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_capturedImage != null) {
      // Preview captured image - Google Camera style
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Full-screen image preview
            Center(
              child: Image.file(_capturedImage!, fit: BoxFit.contain),
            ),
            // Cancel button (top-left)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isProcessing ? null : _cancelCapture,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
            // Upload button (bottom-right circular FAB)
            Positioned(
              bottom: 32,
              right: 32,
              child: FloatingActionButton.large(
                onPressed: _isProcessing ? null : _uploadPhoto,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: _isProcessing
                    ? const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check, size: 36),
              ),
            ),
            // Thumbnail preview in bottom-left corner
            Positioned(
              bottom: 32,
              left: 32,
              child: GestureDetector(
                onTap: () {
                  // Show location info bottom sheet
                  if (_currentPosition != null) {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (context) => Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24)),
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.location_on,
                                    color:
                                        Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Location Details',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildInfoRow(
                              context,
                              'Latitude',
                              _currentPosition!.latitude.toStringAsFixed(6),
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              context,
                              'Longitude',
                              _currentPosition!.longitude.toStringAsFixed(6),
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              context,
                              'Accuracy',
                              '±${_currentPosition!.accuracy.toStringAsFixed(1)}m',
                            ),
                            SizedBox(
                                height: MediaQuery.of(context).padding.bottom),
                          ],
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        Image.file(_capturedImage!, fit: BoxFit.cover),
                        if (_currentPosition != null)
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.gps_fixed,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Camera view - Google Camera inspired
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_isInitialized && _cameraController != null)
            SizedBox.expand(child: CameraPreview(_cameraController!))
          else
            const Center(child: CircularProgressIndicator()),
          // Subtle vignette effect (darken edges)
          if (_isInitialized)
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.3),
                  ],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
          // Minimal GPS indicator (top-left)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _currentPosition != null
                        ? Icons.gps_fixed
                        : Icons.gps_not_fixed,
                    color: _currentPosition != null
                        ? Colors.greenAccent
                        : Colors.orangeAccent,
                    size: 16,
                  ),
                  if (_currentPosition == null) ...[
                    const SizedBox(width: 6),
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Camera switch button (top-right, subtle)
          if (_cameras != null && _cameras!.length > 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isInitialized && !_isSwitchingCamera
                      ? _switchCamera
                      : null,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: _isSwitchingCamera
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.flip_camera_android,
                            color: Colors.white,
                            size: 24,
                          ),
                  ),
                ),
              ),
            ),
          // Large capture button with outer ring (bottom center)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _isInitialized ? _capturePhoto : null,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 4,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _isInitialized
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
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
