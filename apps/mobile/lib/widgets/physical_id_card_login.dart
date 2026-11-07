import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_client.dart';
import '../app_state.dart';
import '../async_action_helper.dart';
import '../splash_screen.dart' show CceCollegeLogo;
import '../student_registration_screen.dart';

/// Design tokens specifically tailored for the physical college ID card login.
class IdCardTokens {
  IdCardTokens._();

  // British Racing Green institutional palette
  static const Color racingGreenDark = Color(0xFF09261D);
  static const Color racingGreenPrimary = Color(0xFF0D3326);
  static const Color racingGreenLight = Color(0xFF144537);

  // Antique Gold accents
  static const Color antiqueGold = Color(0xFFB69A65);
  static const Color goldBright = Color(0xFFD4B37F);
  static const Color goldBorder = Color(0xFFC5A56B);

  // Matte PVC Card Surface
  static const Color pvcSurfaceTop = Color(0xFFFFFFFF);
  static const Color pvcSurfaceMid = Color(0xFFFCFAF5);
  static const Color pvcSurfaceBottom = Color(0xFFF7F4EB);
  static const Color pvcBorder = Color(0xFFE2DAC8);

  // Typography Colors
  static const Color textDark = Color(0xFF0A2A20);
  static const Color textMuted = Color(0xFF5A6B64);
  static const Color textSlate = Color(0xFF4A5C55);

  static const String fontName = 'Manrope';
  static const List<String> fontFallbacks = ['Segoe UI', 'Helvetica Neue', 'Arial', 'sans-serif'];
}

/// Simulated diagonal specular light sheen on laminated matte PVC surface.
class CardSpecularSheenPainter extends CustomPainter {
  const CardSpecularSheenPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment(-1.2, -1.2),
        end: Alignment(1.2, 1.2),
        colors: [
          Color(0x18FFFFFF),
          Color(0x06FFFFFF),
          Colors.transparent,
          Color(0x0CFFFFFF),
        ],
        stops: [0.0, 0.35, 0.55, 1.0],
      ).createShader(rect);

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Realistic physical college identity card containing the interactive login interface.
///
/// Features:
/// - Dark British Racing Green institutional header with official CCE emblem
/// - Multi-layered matte PVC card body with contact shadows and realistic thickness
/// - Initial State: "WELCOME BACK", "Your campus, one pass away.", +91 mobile input, "SEND OTP" button
/// - OTP State: Transforms inside the SAME card to "OTP VERIFICATION", 6-digit PIN input, "VERIFY & SIGN IN", resend countdown
/// - Bottom Strip: "CCE OUTPASS • DIGITAL CAMPUS PASS"
/// - No hardcoded student details (Nidhin Raj, CCE23CS071 removed)
class PhysicalIdCardLogin extends StatefulWidget {
  const PhysicalIdCardLogin({
    super.key,
    this.interactive = true,
    this.compactMode = false,
    this.scale = 1.0,
    this.onAuthenticated,
    this.initialMobile,
  });

  /// Whether the form inputs and buttons respond to user taps and typing.
  final bool interactive;

  /// Rendered in compact mode during falling and swinging animation.
  final bool compactMode;

  /// Overall scale multiplier for zoom transition.
  final double scale;

  /// Callback executed when OTP verification and authentication succeed.
  final VoidCallback? onAuthenticated;

  /// Optional initial mobile number.
  final String? initialMobile;

  @override
  State<PhysicalIdCardLogin> createState() => _PhysicalIdCardLoginState();
}

class _PhysicalIdCardLoginState extends State<PhysicalIdCardLogin> {
  final _mobileController = TextEditingController();
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();

  bool _otpSent = false;
  bool _busy = false;
  String? _error;
  int _resendCooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.initialMobile != null) {
      _mobileController.text = widget.initialMobile!;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mobileController.dispose();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 30);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
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

  AppState get _state => AppStateScope.of(context);

  String _normalizedMobile() => normalizeMobilePhone(_mobileController.text);

  Future<void> _sendOtp() async {
    if (_busy) return;
    final mobile = _normalizedMobile();
    if (!RegExp(r'^\d{10}$').hasMatch(mobile)) {
      setState(() => _error = 'Please enter a valid 10-digit mobile number');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final ok = await AsyncActionHelper.run(
      context,
      action: () async {
        await _state.sendOtp(mobile);
      },
      onError: (err) {
        if (mounted) setState(() => _error = err);
      },
      onFinally: () {
        if (mounted) setState(() => _busy = false);
      },
    );

    if (ok && mounted) {
      setState(() {
        _otpSent = true;
        _otpController.clear();
      });
      _startCooldown();
      // Focus OTP field after layout update
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _otpFocusNode.requestFocus();
      });
    }
  }

  Future<void> _verifyOtp() async {
    if (_busy) return;
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Please enter the complete 6-digit OTP code');
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
        await _state.verifyOtpAndLogin(mobile, code);
      },
      onError: (err) {
        if (mounted) setState(() => _error = err);
      },
      onFinally: () {
        if (mounted) setState(() => _busy = false);
      },
    );

    if (ok && mounted) {
      widget.onAuthenticated?.call();
    }
  }

  void _changeNumber() {
    setState(() {
      _otpSent = false;
      _otpController.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double cardWidth = widget.compactMode ? 300.0 : 380.0;
    final double cardMinHeight = widget.compactMode ? 460.0 : 540.0;

    return IgnorePointer(
      ignoring: !widget.interactive,
      child: Container(
        width: cardWidth,
        constraints: BoxConstraints(minHeight: cardMinHeight),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              IdCardTokens.pvcSurfaceTop,
              IdCardTokens.pvcSurfaceMid,
              IdCardTokens.pvcSurfaceBottom,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
          border: Border.all(
            color: IdCardTokens.pvcBorder,
            width: 1.2,
          ),
          boxShadow: [
            // Deep ambient occlusion shadow giving 3D physical elevation
            BoxShadow(
              color: IdCardTokens.racingGreenDark.withValues(alpha: 0.18),
              blurRadius: 32,
              spreadRadius: 2,
              offset: const Offset(0, 16),
            ),
            // Contact shadow defining the 0.76mm PVC card edge
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Stack(
            children: [
              // Subtle Specular PVC Sheen
              const Positioned.fill(
                child: CustomPaint(
                  painter: CardSpecularSheenPainter(),
                ),
              ),

              // Card Structure (Header, Body, Bottom Strip)
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCardHeader(),
                  _buildCardBody(),
                  _buildCardBottomStrip(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Dark British Racing Green Header with Official CCE Crest
  Widget _buildCardHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            IdCardTokens.racingGreenDark,
            IdCardTokens.racingGreenPrimary,
            IdCardTokens.racingGreenLight,
          ],
          stops: [0.0, 0.55, 1.0],
        ),
        border: Border(
          bottom: BorderSide(
            color: IdCardTokens.antiqueGold,
            width: 2.2,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Authentic CCE Logo inside gold-accented white crest frame
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: IdCardTokens.goldBright,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(2.5),
            child: const CceCollegeLogo(size: 38),
          ),
          const SizedBox(width: 12),
          // Institutional Name & Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'CHRIST COLLEGE OF ENGINEERING',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: IdCardTokens.fontName,
                    fontFamilyFallback: IdCardTokens.fontFallbacks,
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'AUTONOMOUS • IRINJALAKUDA',
                  style: TextStyle(
                    fontFamily: IdCardTokens.fontName,
                    fontFamilyFallback: IdCardTokens.fontFallbacks,
                    color: IdCardTokens.goldBright,
                    fontSize: 8.0,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Card Body hosting the Interactive Login & OTP Verification Form
  Widget _buildCardBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.04, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: _otpSent ? _buildOtpState() : _buildPhoneState(),
      ),
    );
  }

  /// Initial Phone Entry State
  Widget _buildPhoneState() {
    return Column(
      key: const ValueKey('phone_state'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Security Portal Badge
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
            decoration: BoxDecoration(
              color: IdCardTokens.racingGreenDark.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: IdCardTokens.antiqueGold.withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            child: const Text(
              'INSTITUTIONAL LOGIN PORTAL',
              style: TextStyle(
                fontFamily: IdCardTokens.fontName,
                fontFamilyFallback: IdCardTokens.fontFallbacks,
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                color: IdCardTokens.racingGreenDark,
                letterSpacing: 1.3,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Welcome Back Heading
        const Text(
          'WELCOME BACK',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: IdCardTokens.fontName,
            fontFamilyFallback: IdCardTokens.fontFallbacks,
            color: IdCardTokens.textDark,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 4),

        // Subtitle
        const Text(
          'Your campus, one pass away.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: IdCardTokens.fontName,
            fontFamilyFallback: IdCardTokens.fontFallbacks,
            color: IdCardTokens.textMuted,
            fontSize: 12.0,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 20),

        // Mobile Number Input Field with +91 Country Code Badge
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFAF8F3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFD8CEBD),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              // +91 Country Code Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0x0C0A2A20),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(9),
                    bottomLeft: Radius.circular(9),
                  ),
                  border: Border(
                    right: BorderSide(
                      color: Color(0xFFD8CEBD),
                      width: 1.0,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 16,
                      color: IdCardTokens.racingGreenDark.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      '+91',
                      style: TextStyle(
                        fontFamily: IdCardTokens.fontName,
                        fontFamilyFallback: IdCardTokens.fontFallbacks,
                        fontWeight: FontWeight.w800,
                        color: IdCardTokens.textDark,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Digits Input
              Expanded(
                child: TextField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  onSubmitted: (_) => _sendOtp(),
                  style: const TextStyle(
                    fontFamily: IdCardTokens.fontName,
                    fontFamilyFallback: IdCardTokens.fontFallbacks,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: IdCardTokens.textDark,
                    letterSpacing: 1.0,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Enter 10-digit number',
                    hintStyle: TextStyle(
                      fontFamily: IdCardTokens.fontName,
                      fontFamilyFallback: IdCardTokens.fontFallbacks,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.black38,
                      letterSpacing: 0.4,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Error Feedback
        if (_error != null) ...[
          const SizedBox(height: 10),
          _buildErrorBanner(_error!),
        ],

        const SizedBox(height: 16),

        // SEND OTP Button
        Container(
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              colors: [
                IdCardTokens.racingGreenDark,
                IdCardTokens.racingGreenLight,
              ],
            ),
            border: Border.all(
              color: IdCardTokens.antiqueGold,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: IdCardTokens.racingGreenDark.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _busy ? null : _sendOtp,
              child: Center(
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: IdCardTokens.goldBright,
                        ),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'SEND OTP',
                            style: TextStyle(
                              fontFamily: IdCardTokens.fontName,
                              fontFamilyFallback: IdCardTokens.fontFallbacks,
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: IdCardTokens.goldBright,
                            size: 16,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Registration Link
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'New student? ',
              style: TextStyle(
                fontFamily: IdCardTokens.fontName,
                fontFamilyFallback: IdCardTokens.fontFallbacks,
                color: IdCardTokens.textMuted,
                fontSize: 12.5,
              ),
            ),
            InkWell(
              onTap: _busy
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const StudentRegistrationScreen(),
                        ),
                      );
                    },
              child: const Text(
                'Create an account',
                style: TextStyle(
                  fontFamily: IdCardTokens.fontName,
                  fontFamilyFallback: IdCardTokens.fontFallbacks,
                  color: IdCardTokens.racingGreenDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// OTP Verification State inside the SAME card
  Widget _buildOtpState() {
    final mobileDisplay = _mobileController.text.trim();

    return Column(
      key: const ValueKey('otp_state'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Two-factor badge
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
            decoration: BoxDecoration(
              color: IdCardTokens.racingGreenDark.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: IdCardTokens.antiqueGold.withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            child: const Text(
              'TWO-FACTOR AUTHENTICATION',
              style: TextStyle(
                fontFamily: IdCardTokens.fontName,
                fontFamilyFallback: IdCardTokens.fontFallbacks,
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                color: IdCardTokens.racingGreenDark,
                letterSpacing: 1.3,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Heading
        const Text(
          'OTP VERIFICATION',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: IdCardTokens.fontName,
            fontFamilyFallback: IdCardTokens.fontFallbacks,
            color: IdCardTokens.textDark,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 4),

        // Mobile notice
        Text(
          'Enter the 6-digit code sent to +91 $mobileDisplay',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: IdCardTokens.fontName,
            fontFamilyFallback: IdCardTokens.fontFallbacks,
            color: IdCardTokens.textMuted,
            fontSize: 12.0,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 18),

        // 6-digit OTP Code Field
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFFAF8F3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFD8CEBD),
              width: 1.2,
            ),
          ),
          child: TextField(
            controller: _otpController,
            focusNode: _otpFocusNode,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onSubmitted: (_) => _verifyOtp(),
            style: const TextStyle(
              fontFamily: IdCardTokens.fontName,
              fontFamilyFallback: IdCardTokens.fontFallbacks,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 10.0,
              color: IdCardTokens.textDark,
            ),
            decoration: const InputDecoration(
              hintText: '••••••',
              hintStyle: TextStyle(
                letterSpacing: 8.0,
                color: Colors.black26,
                fontSize: 20,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 11),
            ),
          ),
        ),

        // Error Feedback
        if (_error != null) ...[
          const SizedBox(height: 10),
          _buildErrorBanner(_error!),
        ],

        const SizedBox(height: 16),

        // VERIFY & SIGN IN Button
        Container(
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              colors: [
                IdCardTokens.racingGreenDark,
                IdCardTokens.racingGreenLight,
              ],
            ),
            border: Border.all(
              color: IdCardTokens.antiqueGold,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: IdCardTokens.racingGreenDark.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _busy ? null : _verifyOtp,
              child: Center(
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: IdCardTokens.goldBright,
                        ),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: IdCardTokens.goldBright,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'VERIFY & SIGN IN',
                            style: TextStyle(
                              fontFamily: IdCardTokens.fontName,
                              fontFamilyFallback: IdCardTokens.fontFallbacks,
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Bottom Actions: Change Number & Resend OTP
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: _busy ? null : _changeNumber,
              child: const Text(
                '← Change number',
                style: TextStyle(
                  fontFamily: IdCardTokens.fontName,
                  fontFamilyFallback: IdCardTokens.fontFallbacks,
                  color: IdCardTokens.racingGreenDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
              ),
            ),
            InkWell(
              onTap: (_busy || _resendCooldown > 0) ? null : _sendOtp,
              child: Text(
                _resendCooldown > 0
                    ? 'Resend OTP (${_resendCooldown}s)'
                    : 'Resend OTP',
                style: TextStyle(
                  fontFamily: IdCardTokens.fontName,
                  fontFamilyFallback: IdCardTokens.fontFallbacks,
                  color: _resendCooldown > 0
                      ? Colors.grey
                      : IdCardTokens.antiqueGold,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Error Banner Widget
  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEECEB),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFF5A4A0), width: 0.8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFD32F2F), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: IdCardTokens.fontName,
                fontFamilyFallback: IdCardTokens.fontFallbacks,
                color: Color(0xFFC62828),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bottom Strip of the Physical ID Card
  Widget _buildCardBottomStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: IdCardTokens.racingGreenDark,
        border: Border(
          top: BorderSide(
            color: IdCardTokens.antiqueGold,
            width: 1.5,
          ),
        ),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'CCE OUTPASS',
                style: TextStyle(
                  fontFamily: IdCardTokens.fontName,
                  fontFamilyFallback: IdCardTokens.fontFallbacks,
                  color: Colors.white,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: IdCardTokens.antiqueGold,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'DIGITAL CAMPUS PASS',
                style: TextStyle(
                  fontFamily: IdCardTokens.fontName,
                  fontFamilyFallback: IdCardTokens.fontFallbacks,
                  color: IdCardTokens.goldBright,
                  fontSize: 8.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
