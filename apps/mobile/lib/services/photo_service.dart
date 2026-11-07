import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../api_client.dart';
import '../theme/app_theme.dart';

/// Enum representing the user selection from the photo source sheet
enum PhotoSourceAction {
  camera,
  gallery,
  remove,
  cancel,
}

/// Result returned by photo selection or capture
class PhotoResult {
  final Uint8List? bytes;
  final String? dataUri;
  final String? mimeType;
  final String? fileName;
  final int? sizeBytes;
  final String? error;
  final bool isCancelled;

  const PhotoResult({
    this.bytes,
    this.dataUri,
    this.mimeType,
    this.fileName,
    this.sizeBytes,
    this.error,
    this.isCancelled = false,
  });

  bool get isSuccess => bytes != null && bytes!.isNotEmpty && error == null;

  factory PhotoResult.cancelled() => const PhotoResult(isCancelled: true);

  factory PhotoResult.error(String message) => PhotoResult(error: message);

  factory PhotoResult.removed() => const PhotoResult();
}

/// Centralized reusable cross-platform photo service for Android, iOS, and Web.
class PhotoService {
  final ImagePicker _picker;
  final ApiClient? api;

  static const int maxFileSizeBytes = 5 * 1024 * 1024; // 5 MB limit

  PhotoService({ImagePicker? picker, this.api})
      : _picker = picker ?? ImagePicker();

  /// Captures a photograph using the device / browser camera.
  Future<PhotoResult> takePhoto({
    double maxWidth = 1600,
    double maxHeight = 1600,
    int imageQuality = 85,
  }) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );

      if (file == null) {
        return PhotoResult.cancelled();
      }

      return await _processPickedFile(file);
    } on PlatformException catch (e) {
      return PhotoResult.error(_formatPlatformError(e, isCamera: true));
    } catch (e) {
      if (kIsWeb && e.toString().toLowerCase().contains('secure')) {
        return PhotoResult.error(
          'Browser camera access requires HTTPS or localhost. Please use Gallery/File selection or switch to HTTPS.',
        );
      }
      return PhotoResult.error('Failed to capture photo: ${e.toString()}');
    }
  }

  /// Selects an image from the device gallery or browser file picker.
  Future<PhotoResult> chooseFromGallery({
    double maxWidth = 1600,
    double maxHeight = 1600,
    int imageQuality = 85,
  }) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );

      if (file == null) {
        return PhotoResult.cancelled();
      }

      return await _processPickedFile(file);
    } on PlatformException catch (e) {
      return PhotoResult.error(_formatPlatformError(e, isCamera: false));
    } catch (e) {
      return PhotoResult.error('Failed to select image from gallery: ${e.toString()}');
    }
  }

  /// Resets or removes the currently selected photo.
  PhotoResult removeSelectedPhoto() {
    return PhotoResult.removed();
  }

  /// Uploads profile photo to the authenticated backend endpoint.
  Future<String> uploadProfilePhoto(String dataUriOrBase64, {ApiClient? client}) async {
    final activeClient = client ?? api;
    if (activeClient == null) {
      throw Exception('ApiClient is required to upload profile photo');
    }

    final res = await activeClient.post('/auth/profile/photo', body: {
      'photo': dataUriOrBase64,
    });

    if (res is Map && res['photoUrl'] != null) {
      return res['photoUrl'] as String;
    }
    throw Exception(res?['message']?.toString() ?? 'Failed to upload profile photo');
  }

  /// Removes profile photo from the authenticated backend endpoint.
  Future<void> deleteProfilePhoto({ApiClient? client}) async {
    final activeClient = client ?? api;
    if (activeClient == null) {
      throw Exception('ApiClient is required to remove profile photo');
    }

    await activeClient.delete('/auth/profile/photo');
  }

  /// Reads bytes, validates file size (5MB) and format (JPEG/PNG/WEBP), and constructs Data URI.
  Future<PhotoResult> _processPickedFile(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        return PhotoResult.error('Selected file is empty');
      }

      if (bytes.length > maxFileSizeBytes) {
        final sizeMb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
        return PhotoResult.error(
          'Image size ($sizeMb MB) exceeds the maximum allowed limit of 5 MB. Please select a smaller photo.',
        );
      }

      final rawName = file.name.isNotEmpty
          ? file.name
          : (file.path.isNotEmpty ? file.path.split(RegExp(r'[\\/]')).last : '');
      final mimeType = _detectImageMime(bytes, rawName);
      if (mimeType == null) {
        return PhotoResult.error(
          'Unsupported image format. Please select a JPEG, PNG, or WebP photo.',
        );
      }

      final base64Str = base64Encode(bytes);
      final dataUri = 'data:$mimeType;base64,$base64Str';

      return PhotoResult(
        bytes: bytes,
        dataUri: dataUri,
        mimeType: mimeType,
        fileName: rawName.isNotEmpty ? rawName : ("photo." + (mimeType == "image/jpeg" ? "jpg" : (mimeType == "image/png" ? "png" : "webp"))),
        sizeBytes: bytes.length,
      );
    } catch (e) {
      return PhotoResult.error('Failed to read image data: ${e.toString()}');
    }
  }

  /// Detects MIME type by inspecting true magic bytes.
  static String? _detectImageMime(Uint8List bytes, String? name) {
    // JPEG: FF D8 FF
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return 'image/png';
    }

    // WEBP: "RIFF" .... "WEBP"
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }

    // Fallback based on extension if headers match common subtypes
    if (name != null) {
      final lower = name.toLowerCase();
      if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
      if (lower.endsWith('.png')) return 'image/png';
      if (lower.endsWith('.webp')) return 'image/webp';
    }

    return null;
  }

  /// Formats user-friendly error messages from platform exceptions.
  static String _formatPlatformError(PlatformException e, {required bool isCamera}) {
    final code = e.code.toLowerCase();
    final msg = (e.message ?? '').toLowerCase();

    if (code.contains('permission') ||
        code.contains('denied') ||
        msg.contains('permission') ||
        msg.contains('denied')) {
      return isCamera
          ? 'Camera permission was denied. Please allow camera access in your device or browser settings.'
          : 'Photo gallery permission was denied. Please allow photo library access in your device settings.';
    }

    if (code.contains('not_available') || code.contains('unavailable') || msg.contains('not available')) {
      return isCamera
          ? 'Camera is not available on this device.'
          : 'Photo gallery is not available on this device.';
    }

    if (kIsWeb && (code.contains('security') || msg.contains('secure'))) {
      return 'Camera access requires a secure HTTPS connection or localhost in the browser.';
    }

    return e.message ?? (isCamera ? 'Camera access failed' : 'Gallery access failed');
  }

  /// Displays the required bottom sheet with:
  /// 1. Take Photo
  /// 2. Choose from Gallery
  /// 3. Cancel (and Remove Photo if already present)
  static Future<PhotoSourceAction?> showPhotoSourceSheet(
    BuildContext context, {
    bool hasExistingPhoto = false,
  }) {
    return showModalBottomSheet<PhotoSourceAction>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Theme.of(context).cardColor,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF702632).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_a_photo_outlined, size: 20, color: Color(0xFF702632)),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Select Profile Photo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1C1917),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 16),
                ListTile(
                  leading: const Icon(Icons.photo_camera_rounded, color: Color(0xFF702632)),
                  title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Use device or browser camera', style: TextStyle(fontSize: 12)),
                  onTap: () => Navigator.pop(ctx, PhotoSourceAction.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF702632)),
                  title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Pick existing image from storage', style: TextStyle(fontSize: 12)),
                  onTap: () => Navigator.pop(ctx, PhotoSourceAction.gallery),
                ),
                if (hasExistingPhoto)
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed),
                    title: const Text('Remove Photo', style: TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Reset to default avatar placeholder', style: TextStyle(fontSize: 12)),
                    onTap: () => Navigator.pop(ctx, PhotoSourceAction.remove),
                  ),
                const SizedBox(height: 4),
                ListTile(
                  leading: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                  title: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
                  onTap: () => Navigator.pop(ctx, PhotoSourceAction.cancel),
                ),
              ],
              ),
            ),
          ),
        );
      },
    );
  }
}
