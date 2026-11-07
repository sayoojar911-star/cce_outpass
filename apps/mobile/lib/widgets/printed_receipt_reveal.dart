import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../util/printer_sound_helper.dart';

/// Precomputed static decorations, matrices, and styles to avoid per-frame allocations.
abstract final class _ReceiptRevealStyles {
  // Precomputed 3D perspective transforms
  static final Matrix4 printerPerspective = Matrix4.identity()
    ..setEntry(3, 2, 0.001)
    ..rotateX(0.18);

  // Printer body gradients (Physical Dark Charcoal POS-80)
  static const LinearGradient printerGradientDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF383331), // Top specular face
      Color(0xFF292524), // Mid bevel transition (Charcoal #292524)
      Color(0xFF1C1917), // Front face
      Color(0xFF141211), // Deep bottom rim
    ],
    stops: [0.0, 0.35, 0.70, 1.0],
  );

  static const LinearGradient printerGradientLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF443E3B), // Top specular face
      Color(0xFF292524), // Mid bevel transition (Charcoal #292524)
      Color(0xFF1C1917), // Front face
      Color(0xFF141211), // Deep bottom rim
    ],
    stops: [0.0, 0.35, 0.70, 1.0],
  );

  // Precomputed printer drop shadows (rendered once on static printer shell)
  static const List<BoxShadow> printerShadowsDark = [
    BoxShadow(
      color: Color(0xC0000000),
      blurRadius: 28,
      spreadRadius: 2,
      offset: Offset(0, 14),
    ),
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> printerShadowsLight = [
    BoxShadow(
      color: Color(0x8C000000),
      blurRadius: 28,
      spreadRadius: 2,
      offset: Offset(0, 14),
    ),
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  // Bevel specular highlight line
  static const LinearGradient specularHighlightGradient = LinearGradient(
    colors: [
      Color(0x00FFFFFF),
      Color(0x66FFFFFF),
      Color(0x00FFFFFF),
    ],
  );

  // Thermal paper sheen gradients (Cream #FAF6F0)
  static const LinearGradient paperGradientDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF24201F),
      Color(0xFF1E1A19),
      Color(0xFF24201F),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient paperGradientLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFAF6F0), // Cream paper #FAF6F0
      Color(0xFFF7F2E8),
      Color(0xFFFAF6F0),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  // Precomputed paper shadows
  static const List<BoxShadow> paperShadowsDark = [
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 18,
      spreadRadius: 1,
      offset: Offset(0, 8),
    ),
  ];
  static const List<BoxShadow> paperShadowDark = paperShadowsDark;

  static const List<BoxShadow> paperShadowsLight = [
    BoxShadow(
      color: Color(0x17000000),
      blurRadius: 18,
      spreadRadius: 1,
      offset: Offset(0, 8),
    ),
  ];
  static const List<BoxShadow> paperShadowLight = paperShadowsLight;

  // Warm light spill from printer slot lip
  static const BoxDecoration warmLightSpillDecoration = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0x4AF59E0B), // Warm amber glow
        Color(0x18F59E0B),
        Color(0x00F59E0B),
      ],
      stops: [0.0, 0.5, 1.0],
    ),
  );

  // Print-head glint specular line
  static const BoxDecoration printHeadGlintDecoration = BoxDecoration(
    gradient: LinearGradient(
      colors: [
        Color(0x00FFFFFF),
        Color(0x73FFFFFF),
        Color(0x00FFFFFF),
      ],
    ),
  );

  // Slot decoration
  static final BoxDecoration slotCavityDecoration = BoxDecoration(
    color: const Color(0xFF050608),
    borderRadius: BorderRadius.circular(4),
    border: Border.all(
      color: const Color(0xFA000000),
      width: 1.4,
    ),
    boxShadow: const [
      BoxShadow(
        color: Color(0xF2000000),
        blurRadius: 6,
        offset: Offset(0, 3),
      ),
      BoxShadow(
        color: Color(0x1AFFFFFF),
        blurRadius: 1,
        offset: Offset(0, -0.8),
      ),
    ],
  );
}

/// Custom painter for the zig-zag torn bottom edge of physical thermal paper.
class _ZigZagTornEdgePainter extends CustomPainter {
  const _ZigZagTornEdgePainter({
    required this.color,
    required this.shadowColor,
  });

  final Color color;
  final Color shadowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = shadowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();
    path.moveTo(0, 0);

    const toothWidth = 8.0;
    const toothDepth = 4.5;
    final teethCount = (size.width / toothWidth).ceil();

    for (int i = 0; i < teethCount; i++) {
      final x1 = i * toothWidth + (toothWidth / 2);
      final y1 = toothDepth;
      final x2 = (i + 1) * toothWidth;
      final y2 = 0.0;
      path.lineTo(x1, y1);
      path.lineTo(x2, y2);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);

    final edgePath = Path();
    edgePath.moveTo(0, 0);
    for (int i = 0; i < teethCount; i++) {
      final x1 = i * toothWidth + (toothWidth / 2);
      final y1 = toothDepth;
      final x2 = (i + 1) * toothWidth;
      final y2 = 0.0;
      edgePath.lineTo(x1, y1);
      edgePath.lineTo(x2, y2);
    }
    canvas.drawPath(edgePath, shadowPaint);
  }

  @override
  bool shouldRepaint(covariant _ZigZagTornEdgePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.shadowColor != shadowColor;
  }
}

/// Custom painter for thermal printer ventilation louvers / grille.
class _PrinterVentGrillePainter extends CustomPainter {
  const _PrinterVentGrillePainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    const slotCount = 9;
    final slotWidth = size.width / slotCount;
    final slotHeight = size.height;

    final recessPaint = Paint()
      ..color = const Color(0xA6000000)
      ..style = PaintingStyle.fill;

    final highlightPaint = Paint()
      ..color = isDark ? const Color(0x1FFFFFFF) : const Color(0x33FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (int i = 0; i < slotCount; i++) {
      final x = i * slotWidth + 3.0;
      final w = slotWidth - 6.0;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 0, w, slotHeight),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(rect, recessPaint);
      canvas.drawLine(
        Offset(x, slotHeight + 0.8),
        Offset(x + w, slotHeight + 0.8),
        highlightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PrinterVentGrillePainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

/// Subtle paper noise grain painter cached within RepaintBoundary (Polish 2).
class _PaperGrainPainter extends CustomPainter {
  const _PaperGrainPainter({required this.isDark});
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? const Color(0x08FFFFFF) : const Color(0x08000000)
      ..strokeWidth = 1.0;

    // Deterministic pseudo-random grain stippling (zero runtime allocations)
    for (double y = 0; y < size.height; y += 14.0) {
      final shift = ((y.toInt() * 73) % 19).toDouble();
      for (double x = shift; x < size.width; x += 18.0) {
        canvas.drawPoints(ui.PointMode.points, [Offset(x, y)], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PaperGrainPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

/// Reusable Receipt Printer Reveal Animation Wrapper
///
/// Features:
/// - ONE smooth continuous feed driven by Curves.easeInOutCubic (zero stepped stops, zero plateaus)
/// - Continuous mechanical vibration on printer shell (~0.5px sine derived from controller)
/// - Continuous thermal paper emerge, paper curl flattening as feed extends, and zig-zag torn edge
/// - Status LED (pulsing amber during feed -> solid emerald green on completion)
/// - Polish: Warm light spill, paper grain, print-head glint, perforation reveal, tear-off moment, completion shine
/// - Precomputed static decorations & separate RepaintBoundaries for printer and paper
/// - Zero setState inside animation loop; pauses QR countdown timer during feed
/// - Single AnimationController, 60fps on web, tap-to-skip, replay on demand, reduced motion support
class PrintedReceiptReveal extends StatefulWidget {
  const PrintedReceiptReveal({
    super.key,
    required this.child,
    this.outpassId,
    this.printEventId,
    this.status,
    this.initialPrint = true,
    this.onComplete,
    this.printerLabel = 'CCE THERMAL POS-80',
  });

  final Widget child;
  final String? outpassId;
  final String? printEventId;
  final String? status;
  final bool initialPrint;
  final VoidCallback? onComplete;
  final String printerLabel;

  /// Tracks which distinct printing event identifiers have already executed in this session.
  static final Set<String> _sessionPrintedEventIds = <String>{};

  /// Helper to generate separate event keys for Event 1 (Receipt) and Event 2 (Approved Pass)
  static String receiptEventKey(String requestId) => 'RECEIPT_$requestId';
  static String issuanceEventKey(String passId, {String? timestamp}) =>
      'ISSUANCE_$passId${timestamp != null ? "_$timestamp" : ""}';

  /// Check if a specific print event has already executed in this session
  static bool hasPrintedEvent(String eventId) {
    if (_sessionPrintedEventIds.contains(eventId)) return true;
    final bare = eventId.replaceFirst('RECEIPT_', '').replaceFirst('ISSUANCE_', '');
    return _sessionPrintedEventIds.contains(bare);
  }

  /// Mark a specific print event as completed in this session
  static void markEventPrinted(String eventId) =>
      _sessionPrintedEventIds.add(eventId);

  /// Clear a specific event from session memory so it can be replayed on demand
  static void clearEvent(String eventId) =>
      _sessionPrintedEventIds.remove(eventId);

  /// Reset session memory
  static void resetSessionMemory() => _sessionPrintedEventIds.clear();

  /// Backward compatible aliases for passes
  static bool hasPrintedInSession(String passId) =>
      _sessionPrintedEventIds.contains(passId) ||
      _sessionPrintedEventIds.contains('RECEIPT_$passId') ||
      _sessionPrintedEventIds.contains('ISSUANCE_$passId');

  static void markPrintedInSession(String passId) =>
      _sessionPrintedEventIds.add(passId);

  static void clearPassFromSession(String passId) {
    _sessionPrintedEventIds.remove(passId);
    _sessionPrintedEventIds.remove('RECEIPT_$passId');
    _sessionPrintedEventIds.remove('ISSUANCE_$passId');
  }

  @override
  State<PrintedReceiptReveal> createState() => PrintedReceiptRevealState();
}

class PrintedReceiptRevealState extends State<PrintedReceiptReveal>
    with SingleTickerProviderStateMixin {
  String? get effectiveEventId => widget.printEventId ?? widget.outpassId;
  late final AnimationController _controller;
  late final Animation<double> _feedAnimation;
  late final Animation<double> _expandAnimation;
  late final Animation<double> _printerExitAnimation;
  late final Animation<double> _shineAnimation;

  bool _isCompleted = false;
  bool _hapticTriggeredTear = false;
  bool _soundEnabled = PrinterSoundHelper.isSoundEnabledSync;

  // Staging Intervals in the single 3.5s controller:
  // - 0.00 -> 0.80 : Smooth, continuous paper feed driven by Curves.easeInOutCubic
  // - 0.72 -> 1.00 : Overlapped receipt expand (smooth width/padding transition)
  // - 0.75 -> 1.00 : Overlapped printer exit (slides up & fades)
  // - 0.78 -> 0.85 : Mechanical tear-off micro-jolt & LED switches to Emerald Green
  // - 0.86 -> 0.98 : Diagonal completion shine sweep (< 600ms)
  static const double _feedCompletionThreshold = 0.80;
  static const double _tearStart = 0.78;
  static const double _tearEnd = 0.85;
  static const double _shineStart = 0.86;
  static const double _shineEnd = 0.98;

  @override
  void initState() {
    super.initState();

    final eventId = effectiveEventId;
    final alreadyPrinted =
        eventId != null && PrintedReceiptReveal.hasPrintedEvent(eventId);

    PrinterSoundHelper.isSoundEnabled().then((val) {
      if (mounted) setState(() => _soundEnabled = val);
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    // Continuous feed curve: Curves.easeInOutCubic (zero pauses, zero plateaus)
    _feedAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, _feedCompletionThreshold,
          curve: Curves.easeInOutCubic),
    );

    // Overlapping expand curve (starts at 0.72 while feed completes at 0.80)
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.72, 1.0, curve: Curves.easeInOutCubic),
    );

    // Overlapping printer exit curve (printer slides up & fades from 0.75 to 1.0)
    _printerExitAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.75, 1.0, curve: Curves.easeInCubic),
    );

    // Diagonal light sweep shine curve
    _shineAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(_shineStart, _shineEnd, curve: Curves.easeOutQuad),
    );

    _controller.addListener(_handleAnimationProgress);

    _controller.addStatusListener((animStatus) {
      if (animStatus == AnimationStatus.completed) {
        PrinterSoundHelper.stopPrinterSound();
        if (mounted) {
          setState(() {
            _isCompleted = true;
          });
          final id = effectiveEventId;
          if (id != null) {
            PrintedReceiptReveal.markEventPrinted(id);
          }
          _safeHapticFeedback();
          widget.onComplete?.call();
        }
      }
    });

    if (alreadyPrinted || !widget.initialPrint) {
      _isCompleted = true;
      _controller.value = 1.0;
    } else {
      _isCompleted = false;
      _controller.value = 0.0;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final reduceMotion =
            MediaQuery.maybeOf(context)?.disableAnimations ?? false;
        if (reduceMotion) {
          _controller.duration = const Duration(milliseconds: 1200);
        } else {
          _controller.duration = const Duration(milliseconds: 3500);
        }
        _safeHapticFeedback();
        PrinterSoundHelper.startPrinterSound(
          duration: _controller.duration!,
          enabled: _soundEnabled,
        );
        _controller.forward(from: 0.0);
      });
    }
  }

  void _handleAnimationProgress() {
    // Haptic feedback at tear-off completion on supported devices
    final t = _controller.value;
    if (t >= _tearStart && !_hapticTriggeredTear) {
      _hapticTriggeredTear = true;
      _safeHapticFeedback();
    }
  }

  void _safeHapticFeedback() {
    try {
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        HapticFeedback.lightImpact();
      }
    } catch (_) {}
  }

  /// Triggers full replay of the 3D receipt machine animation
  void replay() {
    final id = effectiveEventId;
    if (id != null) {
      PrintedReceiptReveal.clearEvent(id);
    }
    _hapticTriggeredTear = false;
    setState(() {
      _isCompleted = false;
    });
    _controller.reset();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _controller.duration = reduceMotion
        ? const Duration(milliseconds: 1200)
        : const Duration(milliseconds: 3500);
    _safeHapticFeedback();
    PrinterSoundHelper.startPrinterSound(
      duration: _controller.duration!,
      enabled: _soundEnabled,
    );
    _controller.forward(from: 0.0);
  }

  void _skipAnimation() {
    if (_isCompleted) return;
    PrinterSoundHelper.stopPrinterSound();
    _controller.stop();
    _controller.value = 1.0;
    setState(() {
      _isCompleted = true;
    });
    final id = effectiveEventId;
    if (id != null) {
      PrintedReceiptReveal.markEventPrinted(id);
    }
    _safeHapticFeedback();
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    PrinterSoundHelper.stopPrinterSound();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Once finished or skipped, return the clean final widget without ANY transform, clip, or opacity
    if (_isCompleted || _controller.value >= 1.0) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: widget.child,
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final maxReceiptWidth =
            math.min(totalWidth - 32, 460.0).clamp(280.0, 460.0);
        final printerWidth =
            math.min(totalWidth - 20, 440.0).clamp(300.0, 440.0);
        final printingPaperWidth = printerWidth - 36.0;

        return GestureDetector(
          onTap: _skipAnimation,
          behavior: HitTestBehavior.translucent,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
              physics: const NeverScrollableScrollPhysics(),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, staticChild) {
                  final t = _controller.value;
                  final feedT = _feedAnimation.value;
                  final expandT = _expandAnimation.value;
                  final printerExitT = _printerExitAnimation.value;

                  final isFeeding = t < _feedCompletionThreshold;
                  final isTearJolt = t >= _tearStart && t < _tearEnd;
                  final isDone = t >= _tearStart;

                  // Continuous fine vibration on printer shell (~0.35px sine derived from controller)
                  final jitterY = isFeeding
                      ? (math.sin(t * 80.0 * math.pi) * 0.35)
                      : 0.0;
                  final jitterX = isFeeding
                      ? (math.cos(t * 40.0 * math.pi) * 0.25)
                      : 0.0;

                  // Mechanical tear-off micro-jolt (Polish 7)
                  final double tearJoltY;
                  if (isTearJolt) {
                    final tearP = ((t - _tearStart) / (_tearEnd - _tearStart))
                        .clamp(0.0, 1.0);
                    tearJoltY = math.sin(tearP * math.pi) * 2.0;
                  } else {
                    tearJoltY = 0.0;
                  }

                  // Printer translation & opacity (slides up & fades from 0.75 to 1.0)
                  final totalPrinterOpacity =
                      (1.0 - printerExitT).clamp(0.0, 1.0);
                  final totalPrinterOffsetY =
                      (-60.0 * printerExitT) + jitterY + tearJoltY;

                  // Smooth paper dimensions transition (slot width -> final full width)
                  final currentPaperWidth = printingPaperWidth +
                      (maxReceiptWidth - printingPaperWidth) * expandT;

                  // Polish 5: Paper curl perspective that smoothly flattens as it emerges
                  final paperCurlAngle =
                      (1.0 - expandT) * (-0.05 * (1.0 - feedT));

                  // Polish 1: Warm light spill opacity
                  final lightSpillOpacity =
                      (1.0 - feedT).clamp(0.0, 1.0) * (1.0 - expandT);

                  // Contact shadow opacity under the slot lip
                  final contactShadowOpacity = (1.0 - expandT).clamp(0.0, 1.0);

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // -------------------------------------------------------
                      // 1. CHUNKY 3D THERMAL PRINTER MACHINE
                      // -------------------------------------------------------
                      if (totalPrinterOpacity > 0.005)
                        Transform.translate(
                          offset: Offset(jitterX, totalPrinterOffsetY),
                          child: Opacity(
                            opacity: totalPrinterOpacity,
                            child: RepaintBoundary(
                              child: _build3DPrinterBody(
                                isDark: isDark,
                                printerWidth: printerWidth,
                                isFeeding: isFeeding,
                                isDone: isDone,
                                printerLabel: widget.printerLabel,
                                t: t,
                                soundEnabled: _soundEnabled,
                                onToggleSound: () {
                                  final next = !_soundEnabled;
                                  setState(() => _soundEnabled = next);
                                  PrinterSoundHelper.setSoundEnabled(next);
                                },
                              ),
                            ),
                          ),
                        ),

                      // -------------------------------------------------------
                      // 2. EMERGING & EXPANDING THERMAL RECEIPT PAPER
                      // -------------------------------------------------------
                      Transform.translate(
                        offset: Offset(0, -12.0 * (1.0 - expandT)),
                        child: Transform(
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateX(paperCurlAngle),
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: currentPaperWidth,
                            child: Stack(
                              clipBehavior: Clip.hardEdge,
                              children: [
                                // Physical paper clipped continuously to feed emergence
                                ClipRect(
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    heightFactor: expandT > 0.0
                                        ? 1.0
                                        : feedT.clamp(0.001, 1.0),
                                    child: RepaintBoundary(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: isDark
                                              ? _ReceiptRevealStyles
                                                  .paperGradientDark
                                              : _ReceiptRevealStyles
                                                  .paperGradientLight,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          boxShadow: isDark
                                              ? _ReceiptRevealStyles
                                                  .paperShadowDark
                                              : _ReceiptRevealStyles
                                                  .paperShadowLight,
                                        ),
                                        child: Stack(
                                          children: [
                                            // Polish 2: Cached Paper Grain Texture
                                            Positioned.fill(
                                              child: IgnorePointer(
                                                child: CustomPaint(
                                                  painter: _PaperGrainPainter(
                                                      isDark: isDark),
                                                ),
                                              ),
                                            ),

                                            // Static outpass content passed from parent
                                            staticChild ?? const SizedBox(),

                                            // Polish 3: Thermal burn-in edge contrast settling
                                            if (expandT < 0.95 && feedT > 0.02)
                                              Positioned(
                                                bottom: 0,
                                                left: 0,
                                                right: 0,
                                                height: 18,
                                                child: IgnorePointer(
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        begin: Alignment
                                                            .topCenter,
                                                        end: Alignment
                                                            .bottomCenter,
                                                        colors: [
                                                          Colors.transparent,
                                                          (isDark
                                                                  ? Colors.black
                                                                  : Colors
                                                                      .white)
                                                              .withValues(
                                                                  alpha: 0.15),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),

                                            // Polish 8: Completion Shine light sweep (<600ms)
                                            if (_shineAnimation.value > 0.01 &&
                                                _shineAnimation.value < 0.99)
                                              Positioned.fill(
                                                child: IgnorePointer(
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                      gradient: LinearGradient(
                                                        begin: Alignment(
                                                            -2.0 +
                                                                4.0 *
                                                                    _shineAnimation
                                                                        .value,
                                                            -1.0),
                                                        end: Alignment(
                                                            -1.0 +
                                                                4.0 *
                                                                    _shineAnimation
                                                                        .value,
                                                            1.0),
                                                        colors: [
                                                          Colors.transparent,
                                                          Colors.white
                                                              .withValues(
                                                                  alpha: 0.28),
                                                          Colors.transparent,
                                                        ],
                                                        stops: const [
                                                          0.0,
                                                          0.5,
                                                          1.0
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Polish 1: Warm light spill from slot lip
                                if (lightSpillOpacity > 0.01)
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    height: 28,
                                    child: IgnorePointer(
                                      child: Opacity(
                                        opacity: lightSpillOpacity,
                                        child: Container(
                                          decoration: _ReceiptRevealStyles
                                              .warmLightSpillDecoration,
                                        ),
                                      ),
                                    ),
                                  ),

                                // Soft contact shadow under the printer slot lip
                                if (contactShadowOpacity > 0.01 && feedT > 0.03)
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    height: 22,
                                    child: IgnorePointer(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.black.withValues(
                                                  alpha: 0.60 *
                                                      contactShadowOpacity),
                                              Colors.black.withValues(
                                                  alpha: 0.20 *
                                                      contactShadowOpacity),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                // Polish 4: Print-head glint specular line
                                if (expandT < 0.90 && feedT > 0.04)
                                  Positioned(
                                    top: 1,
                                    left: 10,
                                    right: 10,
                                    height: 1.5,
                                    child: IgnorePointer(
                                      child: Opacity(
                                        opacity: (1.0 - expandT)
                                            .clamp(0.0, 1.0) *
                                            0.7,
                                        child: Container(
                                          decoration: _ReceiptRevealStyles
                                              .printHeadGlintDecoration,
                                        ),
                                      ),
                                    ),
                                  ),

                                // Zig-zag torn edge at bottom during feed
                                if (expandT < 0.95 && feedT > 0.08)
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    height: 6,
                                    child: IgnorePointer(
                                      child: CustomPaint(
                                        size: Size(currentPaperWidth, 6),
                                        painter: _ZigZagTornEdgePainter(
                                          color: isDark
                                              ? const Color(0xFF1E293B)
                                              : const Color(0xFFFCFBF8),
                                          shadowColor: const Color(0x40000000),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // User helper hint during print feed
                      if (!isDone)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Opacity(
                            opacity: (0.45 + (math.sin(t * 8.0) * 0.25))
                                .clamp(0.2, 0.8),
                            child: const Text(
                              'Printing pass · Tap anywhere to skip',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the 3D-styled thermal receipt printer machine
  Widget _build3DPrinterBody({
    required bool isDark,
    required double printerWidth,
    required bool isFeeding,
    required bool isDone,
    required String printerLabel,
    required double t,
    required bool soundEnabled,
    required VoidCallback onToggleSound,
  }) {
    return Transform(
      transform: _ReceiptRevealStyles.printerPerspective,
      alignment: Alignment.topCenter,
      child: Container(
        width: printerWidth,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: isDark
              ? _ReceiptRevealStyles.printerGradientDark
              : _ReceiptRevealStyles.printerGradientLight,
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.22 : 0.30),
            width: 1.2,
          ),
          boxShadow: isDark
              ? _ReceiptRevealStyles.printerShadowsDark
              : _ReceiptRevealStyles.printerShadowsLight,
        ),
        child: Stack(
          children: [
            // Top specular highlight line along the bevel rim
            const Positioned(
              top: 1.5,
              left: 20,
              right: 20,
              height: 1.5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: _ReceiptRevealStyles.specularHighlightGradient,
                ),
              ),
            ),

            // Internal machine elements
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Surface: Brand Label, Vent Grille, FEED Button, LED, Sound Toggle
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      // Brand & Model Header with Burgundy accent
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF702632).withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFFAF6F0).withValues(alpha: 0.3),
                                width: 0.8,
                              ),
                            ),
                            child: const Icon(
                              Icons.print_rounded,
                              size: 14,
                              color: Color(0xFFFAF6F0),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            printerLabel,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: Color(0xFFFAF6F0),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),

                      // Right Controls: Vent Louvers + Feed Button + LED + Sound Toggle
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Recessed vent grille
                          SizedBox(
                            width: 50,
                            height: 10,
                            child: CustomPaint(
                              painter:
                                  _PrinterVentGrillePainter(isDark: isDark),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Small tactile FEED button with subtle Burgundy accent
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(
                                colors: [Color(0xFF702632), Color(0xFF481C25)],
                              ),
                              border: Border.all(
                                color: const Color(0x3DFFFFFF),
                                width: 0.8,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x99000000),
                                  blurRadius: 3,
                                  offset: Offset(0, 1.5),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0x33FFFFFF),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Power / Status LED Pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: const Color(0x80000000),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0x1FFFFFFF),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildStatusLed(
                                    isFeeding: isFeeding,
                                    isDone: isDone,
                                    t: t),
                                const SizedBox(width: 5),
                                Text(
                                  isFeeding
                                      ? 'FEED'
                                      : (isDone ? 'READY' : 'STANDBY'),
                                  style: TextStyle(
                                    fontSize: 9.0,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                    color: isFeeding
                                        ? const Color(0xFFFBBF24)
                                        : (isDone
                                            ? const Color(0xFF34D399)
                                            : Colors.white60),
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Accessible Sound ON / OFF toggle button (persisted, default ON)
                          Tooltip(
                            message: soundEnabled
                                ? 'Mute printer audio'
                                : 'Enable printer audio',
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: onToggleSound,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: soundEnabled
                                        ? const Color(0xFF702632)
                                            .withValues(alpha: 0.75)
                                        : const Color(0x66000000),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: soundEnabled
                                          ? const Color(0xFFFAF6F0)
                                              .withValues(alpha: 0.4)
                                          : const Color(0x1FFFFFFF),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        soundEnabled
                                            ? Icons.volume_up_rounded
                                            : Icons.volume_off_rounded,
                                        size: 11,
                                        color: soundEnabled
                                            ? const Color(0xFFFAF6F0)
                                            : Colors.white54,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        soundEnabled ? 'SND' : 'MUTE',
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.bold,
                                          color: soundEnabled
                                              ? const Color(0xFFFAF6F0)
                                              : Colors.white54,
                                          fontFamily: 'monospace',
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
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Front Face: Deep Dark Recessed Slot with Inner Shadow
                  Container(
                    width: printerWidth - 36,
                    height: 14,
                    decoration: _ReceiptRevealStyles.slotCavityDecoration,
                    child: Center(
                      child: Container(
                        width: printerWidth - 44,
                        height: 2.2,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Status LED: Pulsing amber while feeding -> Solid Emerald Green when finished
  Widget _buildStatusLed({
    required bool isFeeding,
    required bool isDone,
    required double t,
  }) {
    final Color ledColor;
    final double ledOpacity;

    if (isFeeding) {
      ledColor = const Color(0xFFF59E0B); // Amber
      ledOpacity = 0.45 + (math.sin(t * 38.0) * 0.55).abs();
    } else if (isDone) {
      ledColor = const Color(0xFF10B981); // Solid Emerald Green
      ledOpacity = 1.0;
    } else {
      ledColor = const Color(0xFF94A3B8); // Muted standby
      ledOpacity = 0.5;
    }

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ledColor.withValues(alpha: ledOpacity),
        boxShadow: [
          BoxShadow(
            color: ledColor.withValues(
                alpha: isFeeding ? 0.85 : (isDone ? 0.70 : 0.20)),
            blurRadius: isFeeding ? 6 : (isDone ? 5 : 2),
            spreadRadius: isFeeding || isDone ? 1 : 0,
          ),
        ],
      ),
    );
  }
}
