import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api_client.dart';
import '../services/photo_service.dart';
import '../theme/app_theme.dart';

/// Reusable circular profile photo picker widget.
/// Used in student registration and student profile screens to ensure DRY code.
class ProfilePhotoWidget extends StatefulWidget {
  const ProfilePhotoWidget({
    super.key,
    this.photoUrl,
    this.photoBytes,
    this.photoDataUri,
    this.radius = 54,
    this.borderColor = const Color(0xFF702632),
    this.borderWidth = 2.5,
    this.isUploading = false,
    this.uploadProgress,
    this.onPhotoSelected,
    this.onPhotoRemoved,
    this.onError,
    this.photoService,
    this.apiClient,
    this.allowEdit = true,
  });

  final String? photoUrl;
  final Uint8List? photoBytes;
  final String? photoDataUri;
  final double radius;
  final Color borderColor;
  final double borderWidth;
  final bool isUploading;
  final double? uploadProgress;
  final void Function(PhotoResult result)? onPhotoSelected;
  final VoidCallback? onPhotoRemoved;
  final void Function(String error)? onError;
  final PhotoService? photoService;
  final ApiClient? apiClient;
  final bool allowEdit;

  @override
  State<ProfilePhotoWidget> createState() => _ProfilePhotoWidgetState();
}

class _ProfilePhotoWidgetState extends State<ProfilePhotoWidget> {
  late final PhotoService _service;

  @override
  void initState() {
    super.initState();
    _service = widget.photoService ?? PhotoService(api: widget.apiClient);
  }

  bool get _hasPhoto {
    return (widget.photoBytes != null && widget.photoBytes!.isNotEmpty) ||
        (widget.photoDataUri != null && widget.photoDataUri!.isNotEmpty) ||
        (widget.photoUrl != null && widget.photoUrl!.isNotEmpty);
  }

  Future<void> _handleTap() async {
    if (!widget.allowEdit || widget.isUploading) return;

    final action = await PhotoService.showPhotoSourceSheet(
      context,
      hasExistingPhoto: _hasPhoto,
    );

    if (action == null || action == PhotoSourceAction.cancel) {
      return;
    }

    if (action == PhotoSourceAction.remove) {
      widget.onPhotoRemoved?.call();
      return;
    }

    PhotoResult result;
    if (action == PhotoSourceAction.camera) {
      result = await _service.takePhoto();
    } else {
      result = await _service.chooseFromGallery();
    }

    if (result.isCancelled) return;

    if (result.error != null) {
      if (mounted) {
        if (widget.onError != null) {
          widget.onError!(result.error!);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error!),
              backgroundColor: AppTheme.errorRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
      return;
    }

    if (result.isSuccess) {
      widget.onPhotoSelected?.call(result);
    }
  }

  Widget _buildImageContent() {
    // 1. Direct memory bytes
    if (widget.photoBytes != null && widget.photoBytes!.isNotEmpty) {
      return Image.memory(
        widget.photoBytes!,
        width: widget.radius * 2,
        height: widget.radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => _buildPlaceholder(),
      );
    }

    // 2. Data URI
    if (widget.photoDataUri != null && widget.photoDataUri!.isNotEmpty) {
      try {
        final dataUri = widget.photoDataUri!;
        if (dataUri.startsWith('data:image')) {
          final commaIdx = dataUri.indexOf(',');
          if (commaIdx != -1) {
            final bytes = base64Decode(dataUri.substring(commaIdx + 1));
            return Image.memory(
              bytes,
              width: widget.radius * 2,
              height: widget.radius * 2,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => _buildPlaceholder(),
            );
          }
        }
      } catch (_) {}
    }

    // 3. Network or local server URL
    if (widget.photoUrl != null && widget.photoUrl!.isNotEmpty) {
      final url = widget.photoUrl!;
      if (url.startsWith('data:image')) {
        try {
          final commaIdx = url.indexOf(',');
          final bytes = base64Decode(url.substring(commaIdx + 1));
          return Image.memory(
            bytes,
            width: widget.radius * 2,
            height: widget.radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stack) => _buildPlaceholder(),
          );
        } catch (_) {}
      }

      // Resolve relative backend URL (e.g. /uploads/students/...)
      String fullUrl = url;
      if (widget.apiClient != null) {
        fullUrl = widget.apiClient!.resolveMediaUrl(url);
      } else if (!url.startsWith('http://') && !url.startsWith('https://')) {
        // Fallback default host
        fullUrl = 'http://localhost:3000$url';
      }

      return Image.network(
        fullUrl,
        width: widget.radius * 2,
        height: widget.radius * 2,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Center(
            child: SizedBox(
              width: widget.radius * 0.6,
              height: widget.radius * 0.6,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (ctx, err, stack) => _buildPlaceholder(),
      );
    }

    // 4. Fallback placeholder
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.radius * 2,
      height: widget.radius * 2,
      color: const Color(0xFFF5EBE6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              size: widget.radius * 0.65,
              color: widget.borderColor.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 2),
            Text(
              'Add Photo',
              style: TextStyle(
                fontSize: (widget.radius * 0.22).clamp(9.0, 12.0),
                fontWeight: FontWeight.w700,
                color: widget.borderColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _hasPhoto;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Main Circular Profile Image
              GestureDetector(
                onTap: _handleTap,
                child: Container(
                  width: widget.radius * 2,
                  height: widget.radius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.borderColor,
                      width: widget.borderWidth,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildImageContent(),
                        // Uploading Progress Overlay
                        if (widget.isUploading)
                          Container(
                            color: Colors.black54,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: widget.radius * 0.6,
                                    height: widget.radius * 0.6,
                                    child: CircularProgressIndicator(
                                      value: widget.uploadProgress,
                                      strokeWidth: 2.5,
                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Uploading...',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Floating Camera Badge Button (bottom-right)
              if (widget.allowEdit && !widget.isUploading)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: GestureDetector(
                    onTap: _handleTap,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: widget.borderColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        hasPhoto ? Icons.edit_rounded : Icons.photo_camera_rounded,
                        size: (widget.radius * 0.35).clamp(14.0, 18.0),
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Retake / Remove Actions when photo is present
          if (widget.allowEdit && hasPhoto && !widget.isUploading) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: _handleTap,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, size: 14, color: widget.borderColor),
                        const SizedBox(width: 4),
                        Text(
                          'Retake / Change',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: widget.borderColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: widget.onPhotoRemoved,
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 14, color: AppTheme.errorRed),
                        SizedBox(width: 4),
                        Text(
                          'Remove',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.errorRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
