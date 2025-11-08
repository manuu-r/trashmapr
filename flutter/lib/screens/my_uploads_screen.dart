import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/point.dart';
import '../models/pending_upload.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/pending_uploads_service.dart';
import '../widgets/image_modal.dart';

class MyUploadsScreen extends StatefulWidget {
  const MyUploadsScreen({super.key});

  @override
  State<MyUploadsScreen> createState() => _MyUploadsScreenState();
}

class _MyUploadsScreenState extends State<MyUploadsScreen> {
  final ApiService _apiService = ApiService();
  List<Point>? _uploads;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUploads();
  }

  Future<void> _loadUploads() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final pendingService =
        Provider.of<PendingUploadsService>(context, listen: false);

    if (!authService.isAuthenticated) {
      setState(() {
        _error = 'Not authenticated';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await authService.getValidToken();
      if (token == null) {
        throw Exception('Failed to get authentication token');
      }

      final uploads = await _apiService.getMyUploads(token);

      setState(() {
        _uploads = uploads;
        _isLoading = false;
      });

      // Refresh user data to update points
      await authService.refreshUser();

      // Clear completed pending uploads after successful refresh
      pendingService.clearCompleted();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteUpload(Point point) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getValidToken();

    if (token == null) return;

    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Upload'),
        content: const Text('Are you sure you want to delete this upload?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final success = await _apiService.deleteUpload(point.id, token);

      if (success) {
        if (mounted) {
          setState(() {
            _uploads?.removeWhere((upload) => upload.id == point.id);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Upload deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );

          // Refresh user data to update points
          await authService.refreshUserData();
        }
      } else {
        throw Exception('Delete failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  Color _getCategoryColor(int category) {
    switch (category) {
      case 1:
        return Colors.blue;
      case 2:
        return Colors.yellow.shade700;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildPendingUploadCard(PendingUpload upload) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            upload.imageFile,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 60,
                height: 60,
                color: Colors.grey.shade300,
                child: const Icon(Icons.broken_image),
              );
            },
          ),
        ),
        title: Row(
          children: [
            if (upload.status == PendingUploadStatus.uploading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (upload.status == PendingUploadStatus.processing)
              const Icon(Icons.psychology, color: Colors.purple, size: 20)
            else if (upload.status == PendingUploadStatus.failed)
              const Icon(Icons.error, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Text(
              upload.status == PendingUploadStatus.uploading
                  ? 'Uploading...'
                  : upload.status == PendingUploadStatus.processing
                      ? 'Analyzing...'
                      : upload.status == PendingUploadStatus.failed
                          ? 'Failed'
                          : 'Processing...',
              style: TextStyle(
                color: upload.status == PendingUploadStatus.failed
                    ? Colors.red
                    : Colors.purple,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${upload.latitude.toStringAsFixed(4)}, ${upload.longitude.toStringAsFixed(4)}\nJust now',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: upload.status == PendingUploadStatus.failed
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () {
                  Provider.of<PendingUploadsService>(context, listen: false)
                      .removePendingUpload(upload.localId);
                },
              )
            : null,
      ),
    );
  }

  Widget _buildCompletedUploadCard(Point point) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            point.imageUrl,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 60,
                height: 60,
                color: Colors.grey.shade300,
                child: const Icon(Icons.broken_image),
              );
            },
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getCategoryColor(point.category),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _getCategoryLabel(point.category),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Weight: ${point.weight.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        subtitle: Text(
          '${point.location.lat.toStringAsFixed(4)}, ${point.location.lng.toStringAsFixed(4)}\n${point.timestamp}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _deleteUpload(point),
        ),
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => ImageModal(point: point),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final pendingService = Provider.of<PendingUploadsService>(context);

    if (!authService.isAuthenticated) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_upload,
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
                  'Sign in with Google to view your uploads.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    await authService.signIn();
                    if (authService.isAuthenticated) {
                      _loadUploads();
                    }
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

    final hasPendingUploads = pendingService.pendingUploads.isNotEmpty;
    final hasCompletedUploads = _uploads != null && _uploads!.isNotEmpty;
    final hasAnyContent = hasPendingUploads || hasCompletedUploads;

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (pendingService.hasProcessingUploads)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Processing...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadUploads),
        ],
      ),
      body: _isLoading && !hasAnyContent
          ? const Center(child: CircularProgressIndicator())
          : _error != null && !hasAnyContent
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text('Error: $_error', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadUploads,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : !hasAnyContent
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              size: 80,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.3),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'No Uploads Yet',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Use the Capture tab to take and upload photos.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadUploads,
                      child: ListView.builder(
                        itemCount: pendingService.pendingUploads.length +
                            (_uploads?.length ?? 0),
                        itemBuilder: (context, index) {
                          // Show pending uploads first
                          if (index < pendingService.pendingUploads.length) {
                            return _buildPendingUploadCard(
                                pendingService.pendingUploads[index]);
                          }

                          // Then show completed uploads
                          final completedIndex =
                              index - pendingService.pendingUploads.length;
                          return _buildCompletedUploadCard(
                              _uploads![completedIndex]);
                        },
                      ),
                    ),
    );
  }
}
