import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:cce_outpass/services/photo_service.dart';
import 'package:cce_outpass/widgets/profile_photo_widget.dart';

// Test implementation of ImagePickerPlatform
class TestImagePickerPlatform extends ImagePickerPlatform {
  XFile? nextFile;
  PlatformException? throwException;
  ImageSource? lastSource;
  bool pickImageCalled = false;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    pickImageCalled = true;
    lastSource = source;
    if (throwException != null) {
      throw throwException!;
    }
    return nextFile;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestImagePickerPlatform testPlatform;

  setUp(() {
    testPlatform = TestImagePickerPlatform();
    ImagePickerPlatform.instance = testPlatform;
  });

  group('PhotoService Unit Tests', () {
    test('takePhoto successfully processes a valid JPEG image', () async {
      final service = PhotoService();
      // Valid JPEG header: FF D8 FF E0
      final jpegBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46]);
      testPlatform.nextFile = XFile.fromData(jpegBytes, name: 'student_camera.jpg', path: 'student_camera.jpg');

      final result = await service.takePhoto();

      expect(testPlatform.pickImageCalled, isTrue);
      expect(testPlatform.lastSource, ImageSource.camera);
      expect(result.isSuccess, isTrue);
      expect(result.mimeType, 'image/jpeg');
      expect(result.fileName, 'student_camera.jpg');
      expect(result.bytes, jpegBytes);
      expect(result.dataUri, startsWith('data:image/jpeg;base64,'));
    });

    test('chooseFromGallery successfully processes a valid PNG image', () async {
      final service = PhotoService();
      // Valid PNG header: 89 50 4E 47 0D 0A 1A 0A
      final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00]);
      testPlatform.nextFile = XFile.fromData(pngBytes, name: 'student_gallery.png', path: 'student_gallery.png');

      final result = await service.chooseFromGallery();

      expect(testPlatform.pickImageCalled, isTrue);
      expect(testPlatform.lastSource, ImageSource.gallery);
      expect(result.isSuccess, isTrue);
      expect(result.mimeType, 'image/png');
      expect(result.fileName, 'student_gallery.png');
      expect(result.dataUri, startsWith('data:image/png;base64,'));
    });

    test('chooseFromGallery successfully processes a valid WebP image', () async {
      final service = PhotoService();
      // Valid WebP header: 'RIFF' .... 'WEBP'
      final webpBytes = Uint8List.fromList([
        0x52, 0x49, 0x46, 0x46, // RIFF
        0x10, 0x00, 0x00, 0x00, // size
        0x57, 0x45, 0x42, 0x50, // WEBP
        0x56, 0x50, 0x38, 0x20, // VP8
      ]);
      testPlatform.nextFile = XFile.fromData(webpBytes, name: 'student.webp', path: 'student.webp');

      final result = await service.chooseFromGallery();

      expect(result.isSuccess, isTrue);
      expect(result.mimeType, 'image/webp');
    });

    test('returns cancelled result when user cancels photo picker', () async {
      final service = PhotoService();
      testPlatform.nextFile = null; // User tapped cancel

      final result = await service.takePhoto();

      expect(result.isCancelled, isTrue);
      expect(result.isSuccess, isFalse);
      expect(result.bytes, isNull);
    });

    test('rejects oversized images exceeding 5 MB limit', () async {
      final service = PhotoService();
      // 5 MB + 1 byte
      final oversizedBytes = Uint8List(5 * 1024 * 1024 + 1);
      // Fill header with JPEG magic bytes so it would otherwise be valid
      oversizedBytes[0] = 0xFF;
      oversizedBytes[1] = 0xD8;
      oversizedBytes[2] = 0xFF;
      testPlatform.nextFile = XFile.fromData(oversizedBytes, name: 'large_photo.jpg', path: 'large_photo.jpg');

      final result = await service.chooseFromGallery();

      expect(result.isSuccess, isFalse);
      expect(result.error, contains('exceeds the maximum allowed limit of 5 MB'));
    });

    test('rejects unsupported file formats (e.g. text/plain or arbitrary binary)', () async {
      final service = PhotoService();
      final textBytes = Uint8List.fromList(utf8.encode('Hello, this is not an image file!'));
      testPlatform.nextFile = XFile.fromData(textBytes, name: 'document.txt', path: 'document.txt');

      final result = await service.chooseFromGallery();

      expect(result.isSuccess, isFalse);
      expect(result.error, contains('Unsupported image format'));
    });

    test('handles camera permission denied platform exception gracefully', () async {
      final service = PhotoService();
      testPlatform.throwException = PlatformException(
        code: 'camera_access_denied',
        message: 'The user did not allow camera access',
      );

      final result = await service.takePhoto();

      expect(result.isSuccess, isFalse);
      expect(result.error, contains('Camera permission was denied'));
    });

    test('handles gallery permission denied platform exception gracefully', () async {
      final service = PhotoService();
      testPlatform.throwException = PlatformException(
        code: 'photo_access_denied',
        message: 'Photo access was denied',
      );

      final result = await service.chooseFromGallery();

      expect(result.isSuccess, isFalse);
      expect(result.error, contains('Photo gallery permission was denied'));
    });

    test('handles camera unavailable platform exception gracefully', () async {
      final service = PhotoService();
      testPlatform.throwException = PlatformException(
        code: 'camera_unavailable',
        message: 'Camera not available on device',
      );

      final result = await service.takePhoto();

      expect(result.isSuccess, isFalse);
      expect(result.error, contains('Camera is not available'));
    });

    test('removeSelectedPhoto returns clean removed result', () {
      final service = PhotoService();
      final result = service.removeSelectedPhoto();

      expect(result.bytes, isNull);
      expect(result.dataUri, isNull);
      expect(result.error, isNull);
      expect(result.isSuccess, isFalse);
      expect(result.isCancelled, isFalse);
    });
  });

  group('ProfilePhotoWidget & Bottom Sheet Widget Tests', () {
    testWidgets('renders placeholder and camera edit badge', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ProfilePhotoWidget(
                radius: 48,
                allowEdit: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ProfilePhotoWidget), findsOneWidget);
      // Placeholder icon inside avatar
      expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
      // Floating edit badge
      expect(find.byIcon(Icons.photo_camera_rounded), findsOneWidget);
    });

    testWidgets('shows loading spinner when isUploading is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ProfilePhotoWidget(
                radius: 48,
                isUploading: true,
                allowEdit: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('tapping widget opens bottom sheet with Take Photo, Choose from Gallery, Cancel', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ProfilePhotoWidget(
                radius: 48,
                allowEdit: true,
              ),
            ),
          ),
        ),
      );

      // Tap on the profile widget
      await tester.tap(find.byType(ProfilePhotoWidget));
      await tester.pumpAndSettle();

      // Verify bottom sheet appears with required options
      expect(find.text('Select Profile Photo'), findsOneWidget);
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Choose from Gallery'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      // Remove photo should NOT be present when there is no existing photo
      expect(find.text('Remove Photo'), findsNothing);
    });

    testWidgets('bottom sheet includes Remove Photo option when existing photo is present', (tester) async {
      final dummyPngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ProfilePhotoWidget(
                radius: 48,
                photoBytes: dummyPngBytes,
                allowEdit: true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ProfilePhotoWidget));
      await tester.pumpAndSettle();

      expect(find.text('Select Profile Photo'), findsOneWidget);
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Choose from Gallery'), findsOneWidget);
      expect(find.text('Remove Photo'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });
}
