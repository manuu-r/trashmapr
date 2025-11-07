import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraService with ChangeNotifier {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  int _currentCameraIndex = 0;
  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _isProcessing = false;
  File? _capturedImage;
  String? _initializationError;

  CameraController? get cameraController => _cameraController;
  bool get isInitialized => _isInitialized;
  File? get capturedImage => _capturedImage;
  bool get isProcessing => _isProcessing;
  String? get initializationError => _initializationError;

  Future<void> initializeCamera() async {
    if (_isInitializing) return;
    _isInitializing = true;

    try {
      _cameras = await availableCameras();
      if (_cameras!.isEmpty) {
        throw Exception('No cameras available');
      }

      // If controller exists and is initialized, verify it's still valid
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        try {
          // Try to access the camera to verify it's still valid
          await _cameraController!.setFocusMode(FocusMode.auto);
          _isInitialized = true;
          notifyListeners();
          _isInitializing = false;
          return;
        } catch (e) {
          // Camera controller is stale, dispose and reinitialize
          debugPrint('Existing camera controller is invalid, disposing: $e');
          try {
            await _cameraController!.dispose();
          } catch (_) {}
          _cameraController = null;
        }
      }

      // Dispose old controller if it exists
      if (_cameraController != null) {
        try {
          await _cameraController!.dispose();
        } catch (_) {}
        _cameraController = null;
      }

      _cameraController = CameraController(
        _cameras![_currentCameraIndex],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      await _cameraController!.setFocusMode(FocusMode.auto);
      await _cameraController!.lockCaptureOrientation();
      await _cameraController!.setFlashMode(FlashMode.auto);

      _isInitialized = true;
      _initializationError = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      _isInitialized = false;
      _cameraController = null;
      _initializationError = e.toString();
      notifyListeners();

      // Retry once after a delay
      await Future.delayed(const Duration(milliseconds: 500));
      if (!_isInitialized) {
        try {
          _cameras = await availableCameras();
          if (_cameras!.isNotEmpty) {
            _cameraController = CameraController(
              _cameras![_currentCameraIndex],
              ResolutionPreset.medium,
              enableAudio: false,
              imageFormatGroup: ImageFormatGroup.jpeg,
            );

            await _cameraController!.initialize();
            await _cameraController!.setFocusMode(FocusMode.auto);
            await _cameraController!.lockCaptureOrientation();
            await _cameraController!.setFlashMode(FlashMode.auto);

            _isInitialized = true;
            _initializationError = null;
            notifyListeners();
          }
        } catch (retryError) {
          debugPrint('Camera initialization retry failed: $retryError');
          _isInitialized = false;
          _cameraController = null;
          _initializationError = retryError.toString();
          notifyListeners();
        }
      }
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    _isInitialized = false;
    _initializationError = null;
    notifyListeners();

    try {
      // stop any image stream
      if (_cameraController != null) {
        try {
          await _cameraController!.stopImageStream();
        } catch (_) {}
        await _cameraController!.dispose();
      }
    } catch (e) {
      debugPrint('Error disposing controller during switch: $e');
    }

    _cameraController = null;

    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras!.length;

    await initializeCamera();
  }

  Future<void> capturePhoto() async {
    // Guard: must have initialized controller
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    // Prevent multiple concurrent captures which can exhaust ImageReader buffers.
    if (_isProcessing || _cameraController!.value.isTakingPicture) {
      debugPrint(
          'capturePhoto skipped: already taking a picture or processing.');
      return;
    }

    // If an image stream is active, stop it before taking a still picture to free ImageReader buffers.
    // stopImageStream may throw or be a no-op if there is no active stream; catch and ignore errors.
    try {
      if (_cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
        // Small delay after stopping the image stream gives the native ImageReader time
        // to release buffers on some devices. Tuned conservatively.
        await Future.delayed(const Duration(milliseconds: 150));
      }
    } catch (e) {
      debugPrint('stopImageStream ignored error: $e');
    }

    // Mark processing state to block further captures from UI
    _isProcessing = true;
    notifyListeners();

    // Retry/timing logic: some devices may throw buffer-related errors when takePicture is
    // invoked too quickly after stopping streams or during high load. Attempt a few times
    // with small delays before giving up.
    const int maxAttempts = 3;
    bool captured = false;

    try {
      for (int attempt = 1; attempt <= maxAttempts && !captured; attempt++) {
        try {
          final image = await _cameraController!.takePicture();
          _capturedImage = File(image.path);
          notifyListeners();
          captured = true;
        } catch (e) {
          debugPrint('takePicture attempt $attempt failed: $e');
          if (attempt < maxAttempts) {
            // Backoff a bit before retrying
            final backoffMs = 150 * attempt;
            await Future.delayed(Duration(milliseconds: backoffMs));
          } else {
            debugPrint('takePicture failed after $maxAttempts attempts.');
          }
        }
      }
    } catch (e) {
      debugPrint('Unexpected error during capturePhoto retries: $e');
    } finally {
      // Ensure processing flag is cleared even if an error occurs to avoid deadlocks.
      _isProcessing = false;
      notifyListeners();
    }
  }

  void clearCapturedImage() {
    if (_capturedImage != null) {
      _capturedImage!.delete().catchError((e) {
        debugPrint('Error deleting temp file: $e');
        return _capturedImage!;
      });
      _capturedImage = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    try {
      if (_cameraController != null) {
        try {
          if (_cameraController!.value.isStreamingImages) {
            _cameraController!.stopImageStream();
          }
        } catch (_) {}
        _cameraController!.dispose();
      }
    } catch (e) {
      debugPrint('Error disposing camera controller: $e');
    }

    _cameraController = null;
    _isInitialized = false;
    _isProcessing = false;
    _isInitializing = false;
    super.dispose();
  }
}
