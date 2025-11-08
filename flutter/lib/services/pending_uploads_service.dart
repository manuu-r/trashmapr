import 'package:flutter/foundation.dart';
import '../models/pending_upload.dart';

/// Service to manage pending/processing uploads
/// Shows uploads immediately while they're being processed in the background
class PendingUploadsService extends ChangeNotifier {
  final List<PendingUpload> _pendingUploads = [];

  List<PendingUpload> get pendingUploads => List.unmodifiable(_pendingUploads);

  /// Add a new pending upload (called when upload to GCS starts)
  void addPendingUpload(PendingUpload upload) {
    _pendingUploads.insert(0, upload); // Add to top of list
    notifyListeners();
  }

  /// Update upload status (e.g., from uploading to processing)
  void updateUploadStatus(String localId, PendingUploadStatus status,
      {String? fileName}) {
    final index = _pendingUploads.indexWhere((u) => u.localId == localId);
    if (index != -1) {
      _pendingUploads[index] = _pendingUploads[index].copyWith(
        status: status,
        fileName: fileName,
      );
      notifyListeners();
    }
  }

  /// Remove a pending upload (called when processing completes or fails permanently)
  void removePendingUpload(String localId) {
    _pendingUploads.removeWhere((u) => u.localId == localId);
    notifyListeners();
  }

  /// Mark upload as completed (will be removed on next refresh)
  void markCompleted(String localId) {
    updateUploadStatus(localId, PendingUploadStatus.completed);
  }

  /// Clear all completed uploads (called after successful API refresh)
  void clearCompleted() {
    _pendingUploads
        .removeWhere((u) => u.status == PendingUploadStatus.completed);
    notifyListeners();
  }

  /// Get pending upload by local ID
  PendingUpload? getPendingUpload(String localId) {
    try {
      return _pendingUploads.firstWhere((u) => u.localId == localId);
    } catch (e) {
      return null;
    }
  }

  /// Check if there are any uploads currently processing
  bool get hasProcessingUploads {
    return _pendingUploads.any((u) =>
        u.status == PendingUploadStatus.uploading ||
        u.status == PendingUploadStatus.processing);
  }
}
