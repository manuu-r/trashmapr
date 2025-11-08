import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../models/pending_upload.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/camera_service.dart';
import '../services/pending_uploads_service.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  Position? _currentPosition;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final cameraService = Provider.of<CameraService>(context, listen: false);
    cameraService.initializeCamera();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Safely dispose camera service if context is still available
    try {
      final cameraService = Provider.of<CameraService>(context, listen: false);
      cameraService.dispose();
    } catch (e) {
      debugPrint('Error disposing camera service: $e');
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraService = Provider.of<CameraService>(context, listen: false);

    // Only handle paused and resumed states to avoid unnecessary camera restarts
    // during brief transitions (like notification shade opening)
    if (state == AppLifecycleState.paused) {
      // Pause the camera preview when app goes to background
      if (cameraService.cameraController != null &&
          cameraService.cameraController!.value.isInitialized) {
        cameraService.cameraController!.pausePreview();
      }
    } else if (state == AppLifecycleState.resumed) {
      // Resume or reinitialize camera when app comes to foreground
      if (cameraService.cameraController != null &&
          cameraService.cameraController!.value.isInitialized) {
        try {
          cameraService.cameraController!.resumePreview();
        } catch (e) {
          debugPrint('Error resuming camera preview: $e');
          // If resume fails, reinitialize
          cameraService.initializeCamera();
        }
      } else {
        // Camera not initialized, initialize it
        cameraService.initializeCamera();
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
    final cameraService = Provider.of<CameraService>(context, listen: false);
    if (!cameraService.isInitialized) return;

    if (_currentPosition == null) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.gps_not_fixed, color: Colors.white),
              SizedBox(width: 12),
              Text('Waiting for GPS location...'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      await _getCurrentLocation();
      return;
    }

    // Haptic feedback on capture
    HapticFeedback.mediumImpact();
    await cameraService.capturePhoto();
  }

  Future<void> _uploadPhoto() async {
    // Prevent multiple uploads
    if (_isProcessing) return;

    final cameraService = Provider.of<CameraService>(context, listen: false);
    if (cameraService.capturedImage == null || _currentPosition == null) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final pendingService =
        Provider.of<PendingUploadsService>(context, listen: false);
    final token = await authService.getValidToken();

    // Capture ScaffoldMessenger before async operations to avoid context issues
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (token == null) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Please sign in to upload photos')),
        );
      }
      return;
    }

    // Generate unique local ID for this upload
    final localId = DateTime.now().millisecondsSinceEpoch.toString();

    // Create pending upload immediately (shows in UI right away)
    final pendingUpload = PendingUpload(
      localId: localId,
      imageFile: cameraService.capturedImage!,
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
      timestamp: DateTime.now(),
      status: PendingUploadStatus.uploading,
    );

    pendingService.addPendingUpload(pendingUpload);

    // Set processing state and haptic feedback
    HapticFeedback.mediumImpact();
    setState(() {
      _isProcessing = true;
    });

    try {
      // Determine content type from file extension
      String contentType = 'image/jpeg';
      final extension =
          cameraService.capturedImage!.path.toLowerCase().split('.').last;
      if (extension == 'png') {
        contentType = 'image/png';
      }

      debugPrint('Starting upload with signed URL flow...');

      // Step 1: Request signed URL from backend
      final signedUrlData = await _apiService.getSignedUploadUrl(
        lat: _currentPosition!.latitude,
        lng: _currentPosition!.longitude,
        idToken: token,
        contentType: contentType,
      );

      // Step 2: Upload directly to GCS using signed URL with required headers
      await _apiService.uploadToGCS(
        signedUrl: signedUrlData['upload_url'],
        imageFile: cameraService.capturedImage!,
        contentType: contentType,
        requiredHeaders: signedUrlData['required_headers'] != null
            ? Map<String, String>.from(signedUrlData['required_headers'])
            : null,
      );

      // Update status to processing (worker will process in background)
      pendingService.updateUploadStatus(
        localId,
        PendingUploadStatus.processing,
        fileName: signedUrlData['file_name'],
      );

      // Clear captured image
      cameraService.clearCapturedImage();

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }

      // Step 3: Show success message (processing happens in background)
      HapticFeedback.lightImpact();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text('Upload complete! Analyzing image...'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      // Mark as completed after worker finishes (estimated 5-8 seconds)
      Future.delayed(const Duration(seconds: 8), () {
        pendingService.markCompleted(localId);
        authService.refreshUser();
      });

      _getCurrentLocation();
    } catch (e) {
      // Remove the failed upload from pending list
      pendingService.removePendingUpload(localId);

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }

      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring(11);
      }

      // Show snackbar for errors with haptic feedback
      HapticFeedback.mediumImpact();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Upload failed: $errorMessage'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _cancelCapture() {
    final cameraService = Provider.of<CameraService>(context, listen: false);
    cameraService.clearCapturedImage();
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
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
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

    return Consumer<CameraService>(
      builder: (context, cameraService, child) {
        if (cameraService.capturedImage != null) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                Center(
                  child: Image.file(cameraService.capturedImage!,
                      fit: BoxFit.contain),
                ),
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
                          color: Colors.black.withOpacity(0.5),
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
                Positioned(
                  bottom: 32,
                  left: 32,
                  child: GestureDetector(
                    onTap: () {
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
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
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
                                  _currentPosition!.longitude
                                      .toStringAsFixed(6),
                                ),
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                  context,
                                  'Accuracy',
                                  '±${_currentPosition!.accuracy.toStringAsFixed(1)}m',
                                ),
                                SizedBox(
                                    height:
                                        MediaQuery.of(context).padding.bottom),
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
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          children: [
                            Image.file(cameraService.capturedImage!,
                                fit: BoxFit.cover),
                            if (_currentPosition != null)
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
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

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              if (cameraService.isInitialized &&
                  cameraService.cameraController != null)
                SizedBox.expand(
                    child: CameraPreview(cameraService.cameraController!))
              else if (cameraService.initializationError != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          size: 80,
                          color: Colors.white.withOpacity(0.5),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Camera Error',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Failed to initialize camera. Please try again.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => cameraService.initializeCamera(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                const Center(child: CircularProgressIndicator()),
              if (cameraService.isInitialized)
                Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.0,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.3),
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
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
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 16,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: cameraService.isInitialized
                        ? () => cameraService.switchCamera()
                        : null,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.flip_camera_android,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    // Disable tap while camera is processing to avoid exhausting ImageReader buffers
                    onTap: (cameraService.isInitialized &&
                            !cameraService.isProcessing)
                        ? _capturePhoto
                        : null,
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 1500),
                      curve: Curves.easeInOut,
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: 1.0 + (0.05 * (0.5 - (value - 0.5).abs())),
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(
                                      0.3 * (0.5 - (value - 0.5).abs())),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Show the normal capture button when not processing,
                                  // otherwise show a small progress indicator.
                                  if (!cameraService.isProcessing)
                                    Container(
                                      decoration: BoxDecoration(
                                        color: cameraService.isInitialized
                                            ? Colors.white
                                            : Colors.white.withOpacity(0.5),
                                        shape: BoxShape.circle,
                                      ),
                                    )
                                  else
                                    const SizedBox(
                                      width: 36,
                                      height: 36,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        color: Colors.white,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
