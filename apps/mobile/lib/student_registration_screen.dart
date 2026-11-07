import 'dart:typed_data';
import 'services/photo_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

import 'api_client.dart';
import 'app_state.dart';
import 'async_action_helper.dart';
import 'theme/app_theme.dart';

/// Preset avatar options for the physical ID card photo.
/// Provides realistic high-resolution SVG/data-URI portraits so students
/// can select their photo or customize without external file dependencies.
class StudentAvatars {
  StudentAvatars._();

  static const List<Map<String, String>> presets = [
    {
      'id': 'avatar_1',
      'label': 'Male Student 1',
      'data':
          'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 140"><rect width="120" height="140" fill="%23e8ecf4"/><circle cx="60" cy="50" r="28" fill="%23c29b7a"/><path d="M32 46 C32 25 44 18 60 18 C76 18 88 25 88 46 C80 34 68 32 60 32 C52 32 40 34 32 46 Z" fill="%232c2523"/><path d="M22 140 C22 102 38 92 60 92 C82 92 98 102 98 140 Z" fill="%236B1D2F"/><polygon points="60,92 52,108 68,108" fill="%23ffffff"/><polygon points="60,108 55,140 65,140" fill="%23c5a059"/></svg>',
    },
    {
      'id': 'avatar_2',
      'label': 'Female Student 1',
      'data':
          'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 140"><rect width="120" height="140" fill="%23f7eef0"/><circle cx="60" cy="52" r="26" fill="%23d8ad88"/><path d="M28 50 C26 22 42 16 60 16 C78 16 94 22 92 50 C96 74 94 92 88 96 C84 76 86 52 82 40 C72 32 66 32 60 32 C54 32 48 32 38 40 C34 52 36 76 32 96 C26 92 24 74 28 50 Z" fill="%23221b18"/><path d="M22 140 C22 102 38 92 60 92 C82 92 98 102 98 140 Z" fill="%231a4731"/><polygon points="60,92 48,110 72,110" fill="%23ffffff"/></svg>',
    },
    {
      'id': 'avatar_3',
      'label': 'Male Student 2',
      'data':
          'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 140"><rect width="120" height="140" fill="%23edf2f7"/><circle cx="60" cy="50" r="27" fill="%23b88968"/><path d="M33 42 C33 22 45 16 60 16 C75 16 87 22 87 42 C79 32 69 30 60 30 C51 30 41 32 33 42 Z" fill="%231a1a1a"/><path d="M22 140 C22 102 38 92 60 92 C82 92 98 102 98 140 Z" fill="%231e3a8a"/><polygon points="60,92 52,112 68,112" fill="%23ffffff"/><polygon points="60,112 56,140 64,140" fill="%23b91c1c"/></svg>',
    },
    {
      'id': 'avatar_4',
      'label': 'Female Student 2',
      'data':
          'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 140"><rect width="120" height="140" fill="%23faf5ff"/><circle cx="60" cy="52" r="26" fill="%23e0b593"/><path d="M30 48 C28 20 44 15 60 15 C76 15 92 20 90 48 C94 70 92 90 86 96 C82 74 84 50 80 38 C70 30 65 30 60 30 C55 30 50 30 40 38 C36 50 38 74 34 96 C28 90 26 70 30 48 Z" fill="%23451a03"/><path d="M22 140 C22 102 38 92 60 92 C82 92 98 102 98 140 Z" fill="%23581c87"/><polygon points="60,92 50,110 70,110" fill="%23ffffff"/></svg>',
    },
  ];
}

/// Premium physical college ID card style student registration interface.
class StudentRegistrationScreen extends StatefulWidget {
  const StudentRegistrationScreen({super.key});

  @override
  State<StudentRegistrationScreen> createState() =>
      _StudentRegistrationScreenState();
}

class _StudentRegistrationScreenState extends State<StudentRegistrationScreen> {
  final PhotoService _photoService = PhotoService();
  Uint8List? _photoBytes;

  final _formKey = GlobalKey<FormState>();

  // Form Field Controllers
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _otpController = TextEditingController();
  final _rollNoController = TextEditingController();

  // Selections
  int? _selectedYear = 1; // Default to 1st Year (integer 1..4)
  String? _selectedDepartment;
  String? _selectedPhotoData = StudentAvatars.presets[0]['data']; // Default preset photo
  String? _photoLabel = StudentAvatars.presets[0]['label'];

  // OTP State
  bool _otpSent = false;
  bool _isPhoneVerified = false;
  String? _verifiedMobile;
  String? _idToken; // Verified Firebase token
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  // General State
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = AppStateScope.of(context);
      if (!state.isConfigLoaded) {
        state.loadConfig().then((_) {
          if (mounted && _selectedDepartment == null && state.departments.isNotEmpty) {
            setState(() {
              _selectedDepartment = state.departments.first['code'] as String?;
            });
          }
        });
      } else if (state.departments.isNotEmpty && _selectedDepartment == null) {
        setState(() {
          _selectedDepartment = state.departments.first['code'] as String?;
        });
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _nameController.dispose();
    _mobileController.dispose();
    _otpController.dispose();
    _rollNoController.dispose();
    super.dispose();
  }

  AppState get _state => AppStateScope.of(context);

  void _startCooldown() {
    setState(() => _resendCooldown = 30);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        t.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  String _normalizedMobile() => normalizeMobilePhone(_mobileController.text);

  Future<void> _sendOtp() async {
    if (_busy) return;
    final mobile = _normalizedMobile();
    if (!RegExp(r'^\d{10}$').hasMatch(mobile)) {
      setState(() => _error = 'Enter a valid 10-digit mobile number');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final ok = await AsyncActionHelper.run(
      context,
      action: () async {
        await _state.sendSignupOtp(mobile);
      },
      onError: (err) {
        debugPrint('[Registration Error]: $err');
        if (mounted) setState(() => _error = err);
      },
      onFinally: () {
        if (mounted) setState(() => _busy = false);
      },
    );

    if (ok && mounted) {
      setState(() => _otpSent = true);
      _startCooldown();
    }
  }

  Future<void> _verifyOtp() async {
    if (_busy) return;
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Please enter the 6-digit OTP');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final mobile = _normalizedMobile();

    final ok = await AsyncActionHelper.run(
      context,
      action: () async {
        final res = await _state.verifySignupOtp(mobile, code);
        _idToken = res['idToken'] as String? ?? 'test:$mobile';
        _verifiedMobile = mobile;
        _isPhoneVerified = true;
      },
      onError: (err) {
        debugPrint('[Registration Error]: $err');
        if (mounted) setState(() => _error = err);
      },
      onFinally: () {
        if (mounted) setState(() => _busy = false);
      },
    );

    if (ok && mounted) {
      setState(() {
        _otpSent = false;
        _error = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Mobile number verified successfully'),
          backgroundColor: Color(0xFF15803D),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openPhotoPicker() async {
    final action = await PhotoService.showPhotoSourceSheet(
      context,
      hasExistingPhoto: _selectedPhotoData != null,
    );

    if (action == null || action == PhotoSourceAction.cancel) return;

    if (action == PhotoSourceAction.remove) {
      setState(() {
        _selectedPhotoData = null;
        _photoBytes = null;
        _photoLabel = null;
      });
      return;
    }

    PhotoResult result;
    if (action == PhotoSourceAction.camera) {
      result = await _photoService.takePhoto();
    } else {
      result = await _photoService.chooseFromGallery();
    }

    if (result.isCancelled) return;

    if (result.error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error!),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (result.isSuccess && result.dataUri != null) {
      setState(() {
        _selectedPhotoData = result.dataUri;
        _photoBytes = result.bytes;
        _photoLabel = result.fileName ?? 'Selected Photograph';
        _error = null;
      });
    }
  }

  Widget _renderPhotoWidget(String photoData) {
    if (_photoBytes != null && _photoBytes!.isNotEmpty) {
      return Image.memory(_photoBytes!, fit: BoxFit.cover);
    }
    if (photoData.startsWith('data:image/svg')) {
      // Render custom portrait placeholder
      return Container(
        color: const Color(0xFFE8ECF4),
        child: const Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_box_rounded, size: 36, color: Color(0xFF702632)),
                SizedBox(height: 2),
                Text(
                  'STUDENT',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: Color(0xFF702632),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (photoData.startsWith('data:image/')) {
      try {
        final commaIdx = photoData.indexOf(',');
        if (commaIdx != -1) {
          final bytes = base64Decode(photoData.substring(commaIdx + 1));
          return Image.memory(bytes, fit: BoxFit.cover);
        }
      } catch (_) {}
    } else if (photoData.startsWith('http://') || photoData.startsWith('https://')) {
      return Image.network(
        photoData,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, size: 36),
      );
    }
    return const Icon(Icons.person, size: 48, color: Color(0xFF702632));
  }

  Future<void> _submitRegistration() async {
    if (_busy) return;

    // Validate form inputs
    if (!_formKey.currentState!.validate()) return;

    // 1. Verify Phone Check
    if (!_isPhoneVerified || _idToken == null) {
      setState(() => _error = 'Please complete mobile number OTP verification first');
      return;
    }

    // 2. Photo Check
    if (_selectedPhotoData == null || _selectedPhotoData!.trim().isEmpty) {
      setState(() => _error = 'Please upload or select a student photo for your ID card');
      return;
    }

    // 3. Department Check
    final dept = _selectedDepartment ??
        (_state.departments.isNotEmpty
            ? _state.departments.first['code'] as String
            : 'CSE');

    final name = _nameController.text.trim();
    final rollNo = _rollNoController.text.trim().toUpperCase();
    final year = _selectedYear ?? 1;

    setState(() {
      _busy = true;
      _error = null;
    });

    Map<String, dynamic>? result;
    final ok = await AsyncActionHelper.run(
      context,
      action: () async {
        result = await _state.registerStudent(
          idToken: _idToken!,
          name: name,
          rollNo: rollNo,
          year: year,
          department: dept,
          photo: _selectedPhotoData!,
        );
      },
      onError: (err) {
        debugPrint('[Registration Error]: $err');
        if (mounted) setState(() => _error = err);
      },
      onFinally: () {
        if (mounted) setState(() => _busy = false);
      },
    );

    if (ok && mounted && result != null) {
      _showRegistrationSuccessDialog(name, rollNo, dept, year);
    }
  }

  void _showRegistrationSuccessDialog(
      String name, String rollNo, String department, int year) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success Badge
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF15803D), width: 2),
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF15803D), size: 36),
                ),
                const SizedBox(height: AppSpacing.s16),
                Text(
                  'Registration Successful!',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF702632),
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.s4),
                const Text(
                  'Your student identity card has been issued with active outpass privileges.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.s24),

                // Physical ID Card Preview
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF6F0),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // ID Header
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFF702632),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Center(
                              child: Text(
                                'CCE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CHRIST COLLEGE OF ENGINEERING',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF702632),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  'STUDENT IDENTITY CARD',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF15803D)),
                            ),
                            child: const Text(
                              'VERIFIED',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      const Divider(height: 1, color: Color(0xFFE7E0D8)),
                      const SizedBox(height: AppSpacing.s12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Photo preview
                          Container(
                            width: 64,
                            height: 78,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFD4AF37)),
                              color: Colors.white,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: _selectedPhotoData != null
                                  ? _renderPhotoWidget(_selectedPhotoData!)
                                  : const Icon(Icons.person, size: 36),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s12),
                          // Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Color(0xFF292524),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Roll No: $rollNo',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF702632),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Dept: $department • Year $year',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.phone_android,
                                        size: 12, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      '+91 $_verifiedMobile',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.s24),

                // Continue to Dashboard Button
                PrimaryButton(
                  label: 'Continue to Student Dashboard →',
                  icon: Icons.dashboard_rounded,
                  onPressed: () {
                    Navigator.pop(ctx); // Close dialog
                    Navigator.pop(context); // Return from registration screen to RootRouter
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final departments = state.departments;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F3),
      appBar: AppBar(
        title: const Text('Student Registration'),
        backgroundColor: const Color(0xFF702632),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  // Physical ID Card Container
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBF7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE7E0D8), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Lanyard hole simulation
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(top: 10),
                            width: 44,
                            height: 7,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E0A12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey.shade400, width: 0.5),
                            ),
                          ),
                        ),

                        // ID Card Header Band
                        Container(
                          margin: const EdgeInsets.all(AppSpacing.s12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s16,
                            vertical: AppSpacing.s12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF702632),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD4AF37), width: 1),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.school_rounded,
                                    color: Color(0xFF702632),
                                    size: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'CHRIST COLLEGE OF ENGINEERING',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Irinjalakuda, Thrissur • Kerala 680125',
                                      style: TextStyle(
                                        color: Color(0xFFFAF6F0),
                                        fontSize: 10,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'OFFICIAL STUDENT IDENTITY CARD',
                                      style: TextStyle(
                                        color: Color(0xFFD4AF37),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ID Form Body
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.s24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Photo Section Row
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Photo Box
                                    GestureDetector(
                                      onTap: _openPhotoPicker,
                                      child: Container(
                                        width: 100,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _selectedPhotoData != null
                                                ? const Color(0xFF702632)
                                                : Colors.red.shade300,
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.05),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(10),
                                                child: _selectedPhotoData != null
                                                    ? _renderPhotoWidget(_selectedPhotoData!)
                                                    : const Icon(
                                                        Icons.add_a_photo_outlined,
                                                        size: 36,
                                                        color: Colors.grey,
                                                      ),
                                              ),
                                            ),
                                            Positioned(
                                              bottom: 0,
                                              left: 0,
                                              right: 0,
                                              child: Container(
                                                color: const Color(0xFF702632).withValues(alpha: 0.85),
                                                padding: const EdgeInsets.symmetric(vertical: 3),
                                                child: const Text(
                                                  'TAP PHOTO',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.8,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.s16),

                                    // Photo instructions & actions
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Student Photo',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Color(0xFF292524),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _photoLabel ?? 'No photo selected (Required)',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: _selectedPhotoData != null
                                                  ? const Color(0xFF15803D)
                                                  : Colors.red.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          OutlinedButton.icon(
                                            onPressed: _openPhotoPicker,
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFF702632),
                                              side: const BorderSide(color: Color(0xFF702632)),
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 6),
                                              visualDensity: VisualDensity.compact,
                                            ),
                                            icon: Icon(
                                              _selectedPhotoData != null
                                                  ? Icons.swap_horiz_rounded
                                                  : Icons.add_photo_alternate_outlined,
                                              size: 16,
                                            ),
                                            label: Text(
                                              _selectedPhotoData != null
                                                  ? 'Replace Photo'
                                                  : 'Choose Photo',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: AppSpacing.sectionGap),

                                // 1. Full Name
                                AppTextField(
                                  controller: _nameController,
                                  labelText: 'Full Name *',
                                  hintText: 'e.g. Rahul Sharma',
                                  prefixIcon: const Icon(Icons.person_outline),
                                  textCapitalization: TextCapitalization.words,
                                  validator: (val) {
                                    if (val == null || val.trim().length < 2) {
                                      return 'Please enter student full name';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: AppSpacing.fieldGap),

                                // 2. Mobile Number & Firebase OTP Section
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: AppTextField(
                                        controller: _mobileController,
                                        labelText: 'Mobile Number *',
                                        prefixText: '+91 ',
                                        prefixIcon: const Icon(Icons.phone_outlined),
                                        keyboardType: TextInputType.phone,
                                        enabled: !_isPhoneVerified && !_otpSent,
                                        validator: (val) {
                                          final clean = normalizeMobilePhone(val ?? '');
                                          if (!RegExp(r'^\d{10}$').hasMatch(clean)) {
                                            return '10-digit number';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    if (!_isPhoneVerified && !_otpSent) ...[
                                      const SizedBox(width: AppSpacing.s8),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF702632),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 14),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          onPressed: _busy ? null : _sendOtp,
                                          child: const Text('Send OTP',
                                              style: TextStyle(fontSize: 13)),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),

                                // OTP Sent Input Field
                                if (_otpSent && !_isPhoneVerified) ...[
                                  const SizedBox(height: AppSpacing.fieldGap),
                                  Container(
                                    padding: const EdgeInsets.all(AppSpacing.s12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFB45309)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.sms_outlined,
                                                color: Color(0xFFB45309), size: 18),
                                            const SizedBox(width: AppSpacing.s8),
                                            Text(
                                              'Enter OTP sent to +91 ${_normalizedMobile()}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFFB45309),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: AppSpacing.s8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: AppTextField(
                                                controller: _otpController,
                                                labelText: '6-digit OTP',
                                                keyboardType: TextInputType.number,
                                                maxLength: 6,
                                              ),
                                            ),
                                            const SizedBox(width: AppSpacing.s8),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF15803D),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 16, vertical: 14),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                              onPressed: _busy ? null : _verifyOtp,
                                              child: const Text('Verify'),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            TextButton(
                                              onPressed: () {
                                                setState(() {
                                                  _otpSent = false;
                                                  _otpController.clear();
                                                });
                                              },
                                              child: const Text('Change Number',
                                                  style: TextStyle(fontSize: 11)),
                                            ),
                                            TextButton(
                                              onPressed: (_busy || _resendCooldown > 0)
                                                  ? null
                                                  : _sendOtp,
                                              child: Text(
                                                _resendCooldown > 0
                                                    ? 'Resend in ${_resendCooldown}s'
                                                    : 'Resend OTP',
                                                style: const TextStyle(fontSize: 11),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Verified Mobile Indicator
                                if (_isPhoneVerified) ...[
                                  const SizedBox(height: AppSpacing.s8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF15803D)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check_circle_rounded,
                                            color: Color(0xFF15803D), size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Mobile Verified: +91 $_verifiedMobile',
                                            style: const TextStyle(
                                              color: Color(0xFF15803D),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            setState(() {
                                              _isPhoneVerified = false;
                                              _idToken = null;
                                              _verifiedMobile = null;
                                              _otpSent = false;
                                              _otpController.clear();
                                            });
                                          },
                                          child: const Text(
                                            'Change',
                                            style: TextStyle(
                                                fontSize: 11, color: Color(0xFF702632)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: AppSpacing.fieldGap),

                                // 3. College Roll Number (CCEXXXXXXX format)
                                AppTextField(
                                  controller: _rollNoController,
                                  labelText: 'College Roll Number *',
                                  hintText: 'CCE23CS042',
                                  helperText: 'Format: CCEXXXXXXX (e.g. CCE23CS042)',
                                  prefixIcon: const Icon(Icons.badge_outlined),
                                  textCapitalization: TextCapitalization.characters,
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Please enter roll number';
                                    }
                                    final clean = val.trim().toUpperCase();
                                    if (!RegExp(r'^CCE[A-Z0-9]{5,10}$').hasMatch(clean)) {
                                      return 'Must start with CCE followed by alphanumeric characters';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: AppSpacing.fieldGap),

                                // 4. Current Year of Study Dropdown
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Current Year of Study *',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF292524),
                                          ),
                                    ),
                                    const SizedBox(height: AppSpacing.s8),
                                    DropdownButtonFormField<int>(
                                      isExpanded: true,
                                      initialValue: _selectedYear,
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(Icons.calendar_today_outlined),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 12),
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 1, child: Text('1st Year')),
                                        DropdownMenuItem(value: 2, child: Text('2nd Year')),
                                        DropdownMenuItem(value: 3, child: Text('3rd Year')),
                                        DropdownMenuItem(value: 4, child: Text('4th Year')),
                                      ],
                                      onChanged: (val) => setState(() => _selectedYear = val),
                                      validator: (val) =>
                                          val == null ? 'Select current year of study' : null,
                                    ),
                                  ],
                                ),

                                const SizedBox(height: AppSpacing.fieldGap),

                                // 5. Department Dropdown
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Department *',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF292524),
                                          ),
                                    ),
                                    const SizedBox(height: AppSpacing.s8),
                                    DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      initialValue: _selectedDepartment ??
                                          (departments.isNotEmpty
                                              ? departments.first['code'] as String?
                                              : 'CSE'),
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(Icons.domain_outlined),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 12),
                                      ),
                                      items: departments.isNotEmpty
                                          ? departments.map<DropdownMenuItem<String>>((d) {
                                              final code = d['code'] as String;
                                              final name = d['name'] as String;
                                              return DropdownMenuItem<String>(
                                                value: code,
                                                child: Text(
                                                  '$name ($code)',
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              );
                                            }).toList()
                                          : const [
                                              DropdownMenuItem(
                                                value: 'CSE',
                                                child: Text('Computer Science and Engineering (CSE)'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'CSBS',
                                                child: Text('Computer Science and Business Systems (CSBS)'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'ECE',
                                                child: Text('Electronics and Communication (ECE)'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'EEE',
                                                child: Text('Electrical and Electronics (EEE)'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'ME',
                                                child: Text('Mechanical Engineering (ME)'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'CE',
                                                child: Text('Civil Engineering (CE)'),
                                              ),
                                            ],
                                      onChanged: (val) =>
                                          setState(() => _selectedDepartment = val),
                                      validator: (val) =>
                                          val == null ? 'Select department' : null,
                                    ),
                                  ],
                                ),

                                // Error display
                                if (_error != null) ...[
                                  const SizedBox(height: AppSpacing.s16),
                                  Container(
                                    padding: const EdgeInsets.all(AppSpacing.s12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.red.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.error_outline,
                                            color: Colors.red.shade700, size: 18),
                                        const SizedBox(width: AppSpacing.s8),
                                        Expanded(
                                          child: Text(
                                            _error!,
                                            style: TextStyle(
                                                color: Colors.red.shade700, fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: AppSpacing.sectionGap),

                                // Submit Registration Button
                                PrimaryButton(
                                  label: 'Complete Registration & Issue ID',
                                  icon: Icons.assignment_turned_in_rounded,
                                  loading: _busy,
                                  onPressed: _busy ? null : _submitRegistration,
                                ),

                                const SizedBox(height: AppSpacing.s16),

                                // Return to login link
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Already registered? ',
                                      style: TextStyle(fontSize: 13, color: Colors.grey),
                                    ),
                                    InkWell(
                                      onTap: () => Navigator.pop(context),
                                      child: const Text(
                                        'Sign in here',
                                        style: TextStyle(
                                          color: Color(0xFF702632),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
