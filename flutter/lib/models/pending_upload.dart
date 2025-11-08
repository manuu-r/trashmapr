import 'dart:io';

/// Represents an upload that is pending or being processed
class PendingUpload {
  final String localId; // Unique ID for this pending upload
  final File imageFile; // Local image file
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final PendingUploadStatus status;
  final String? fileName; // GCS filename if uploaded

  PendingUpload({
    required this.localId,
    required this.imageFile,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.status = PendingUploadStatus.uploading,
    this.fileName,
  });

  PendingUpload copyWith({
    PendingUploadStatus? status,
    String? fileName,
  }) {
    return PendingUpload(
      localId: localId,
      imageFile: imageFile,
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp,
      status: status ?? this.status,
      fileName: fileName ?? this.fileName,
    );
  }
}

enum PendingUploadStatus {
  uploading, // Uploading to GCS
  processing, // Uploaded, waiting for worker to process
  completed, // Worker completed, will be removed from pending list
  failed, // Upload or processing failed
}
