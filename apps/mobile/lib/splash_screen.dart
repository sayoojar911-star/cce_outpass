import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'main.dart';
import 'theme/app_theme.dart';
import 'widgets/physical_id_card_login.dart';

/// Design tokens specifically crafted for the institutional startup screen.
class SplashTokens {
  SplashTokens._();

  static const Color background = Color(0xFFF4F1E8); // Clean warm ivory
  static const Color forestGreen = Color(0xFF0A2A20); // British Racing Green
  static const Color antiqueGold = Color(0xFFB69A65); // Warm antique gold
  static const Color goldBright = Color(0xFFD4B37F);
  static const Color darkSlate = Color(0xFF0F2620);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE2DAC8);

  static const String fontName = 'Manrope';
  static const List<String> fontFallbacks = ['Segoe UI', 'Helvetica Neue', 'Arial', 'sans-serif'];
}

/// Fallback vector painter rendering the official CCE shield crest.
/// Guarantees crisp high-DPI rendering even if asset loading is delayed.
class CceOfficialLogoPainter extends CustomPainter {
  const CceOfficialLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 512.0;
    canvas.save();
    canvas.scale(scale, scale);

    // Outer rounded background container
    final bgRect = const Rect.fromLTWH(0, 0, 512, 512);
    final bgRRect = RRect.fromRectAndRadius(bgRect, const Radius.circular(128));
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF020617), Color(0xFF002B49), Color(0xFF0F172A)],
        stops: [0.0, 0.5, 1.0],
      ).createShader(bgRect);
    canvas.drawRRect(bgRRect, bgPaint);

    final goldShader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFCD34D), Color(0xFFD97706)],
    ).createShader(bgRect);

    // Outer shield outline
    final outerPath = Path()
      ..moveTo(256, 70)
      ..lineTo(390, 120)
      ..lineTo(390, 250)
      ..cubicTo(390, 340, 320, 410, 256, 442)
      ..cubicTo(192, 410, 122, 340, 122, 250)
      ..lineTo(122, 120)
      ..close();

    final outerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeJoin = StrokeJoin.round
      ..shader = goldShader;
    canvas.drawPath(outerPath, outerPaint);

    // Inner shield fill
    final innerPath = Path()
      ..moveTo(256, 110)
      ..lineTo(356, 150)
      ..lineTo(356, 245)
      ..cubicTo(356, 315, 304, 372, 256, 398)
      ..cubicTo(208, 372, 156, 315, 156, 245)
      ..lineTo(156, 150)
      ..close();

    final innerPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0x99002B49);
    canvas.drawPath(innerPath, innerPaint);

    // Keyhole / Pass Symbol
    final circlePaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = goldShader;
    canvas.drawCircle(const Offset(256, 220), 36, circlePaint);

    final keyholeBase = Path()
      ..moveTo(236, 245)
      ..lineTo(220, 320)
      ..lineTo(292, 320)
      ..lineTo(276, 245)
      ..close();
    canvas.drawPath(keyholeBase, circlePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Logo widget that prefers the official PNG asset with zero-flicker vector fallback.
class CceCollegeLogo extends StatelessWidget {
  const CceCollegeLogo({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/cce_logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return CustomPaint(
            size: Size(size, size),
            painter: const CceOfficialLogoPainter(),
          );
        },
      ),
    );
  }
}

/// Painter rendering the visible, thin, elegant suspension rope extending
/// upwards beyond the top edge of the viewport with a hidden pivot above the screen.
///
/// Features:
/// - 2.8px core rope in Deep British Racing Green (`SplashTokens.forestGreen`)
/// - Spiral braided Antique Gold (`SplashTokens.antiqueGold`) weave accents
/// - Soft ambient shadow for physical realism against the warm ivory background
/// - Precision metallic crimp ferrule flush against the card's top edge
/// - Hidden pivot off-screen (y < 0) ensuring NO hooks, clips, or attachments are visible
class SuspendedRopePainter extends CustomPainter {
  const SuspendedRopePainter({
    required this.pivot,
    required this.cardTopCenter,
    required this.ropeOpacity,
    this.zoomProgress = 0.0,
  });

  /// The suspension pivot point. Positioned strictly above the viewport (y < 0).
  final Offset pivot;

  /// The exact top-center attachment coordinate on the student ID card.
  final Offset cardTopCenter;

  /// Overall opacity of the rope (fades in as card drops, fades out as card zooms).
  final double ropeOpacity;

  /// Progress of the final zoom transition into login (0.0 settled -> 1.0 full login).
  final double zoomProgress;

  @override
  void paint(Canvas canvas, Size size) {
    if (ropeOpacity <= 0.001) return;

    // During zoom into login, translate rope upward into the ceiling as it fades
    final yOffset = -zoomProgress * 180.0;
    final startPoint = Offset(pivot.dx, pivot.dy + yOffset);
    final endPoint = Offset(cardTopCenter.dx, cardTopCenter.dy + yOffset);

    final totalVec = endPoint - startPoint;
    final distance = totalVec.distance;
    if (distance <= 0.5) return;

    final unitVec = totalVec / distance;
    final normal = Offset(-unitVec.dy, unitVec.dx);

    canvas.save();

    // 1. Soft Ambient Shadow (casts depth onto the warm ivory canvas)
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12 * ropeOpacity)
      ..strokeWidth = 3.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    canvas.drawLine(
      startPoint + const Offset(1.5, 2.5),
      endPoint + const Offset(1.5, 2.5),
      shadowPaint,
    );

    // 2. Main Rope Core (Deep British Racing Green #0A2A20)
    final ropeCorePaint = Paint()
      ..color = SplashTokens.forestGreen.withValues(alpha: ropeOpacity)
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    canvas.drawLine(startPoint, endPoint, ropeCorePaint);

    // 3. Braided Antique Gold Weave Accent Stitches (every 7 px along rope)
    final goldBraidPaint = Paint()
      ..color = SplashTokens.antiqueGold.withValues(alpha: 0.85 * ropeOpacity)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const stitchInterval = 7.0;
    final stitchCount = (distance / stitchInterval).floor();
    for (int i = 1; i < stitchCount; i++) {
      final center = startPoint + unitVec * (i * stitchInterval);
      final p1 = center - normal * 1.3 - unitVec * 1.2;
      final p2 = center + normal * 1.3 + unitVec * 1.2;
      canvas.drawLine(p1, p2, goldBraidPaint);
    }

    // 4. Subtle Specular Highlight along edge
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.20 * ropeOpacity)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      startPoint - normal * 0.7,
      endPoint - normal * 0.7,
      highlightPaint,
    );

    // 5. Metallic Crimp Ferrule at card connection point
    // Clean, flush golden brass ferrule securing the rope to the card top edge.
    // Explicitly NOT a hook, loop, pivot, or hanging mechanism.
    final ferruleCenter = endPoint + const Offset(0, 1.5);
    final ferruleRect = Rect.fromCenter(
      center: ferruleCenter,
      width: 4.8,
      height: 5.5,
    );
    final ferruleRRect = RRect.fromRectAndRadius(ferruleRect, const Radius.circular(1.0));
    final ferrulePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE2C48E), Color(0xFFC09B52), Color(0xFF8A6B32)],
      ).createShader(ferruleRect)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(ferruleRRect, ferrulePaint);

    final ferruleBorder = Paint()
      ..color = const Color(0xFF6B511E).withValues(alpha: ropeOpacity)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(ferruleRRect, ferruleBorder);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SuspendedRopePainter oldDelegate) {
    return oldDelegate.pivot != pivot ||
        oldDelegate.cardTopCenter != cardTopCenter ||
        oldDelegate.ropeOpacity != ropeOpacity ||
        oldDelegate.zoomProgress != zoomProgress;
  }
}

/// Evaluated state of the card under the physical laws of Newtonian gravity and pendulum motion.
class CardPhysicsState {
  const CardPhysicsState({
    required this.topCenter,
    required this.angle,
    required this.ropeOpacity,
    required this.zoomProgress,
    required this.cardOpacity,
  });

  final Offset topCenter;
  final double angle;
  final double ropeOpacity;
  final double zoomProgress;
  final double cardOpacity;
}

/// Classical physics simulation of a suspended college ID card with true gravity-based
/// fall, momentum transfer, damped pendulum oscillation, and smooth zoom settling.
class CardPhysicsSimulation {
  CardPhysicsSimulation({
    required this.pivot,
    required this.restingTopCenter,
    this.initialDropHeight = 560.0,
    this.gravity = 2600.0, // px/s²
    this.dampingFactor = 3.2,
  });

  final Offset pivot;
  final Offset restingTopCenter;
  final double initialDropHeight;
  final double gravity;
  final double dampingFactor;

  double get pendulumLength => (restingTopCenter.dy - pivot.dy).abs();
  double get omegaN => math.sqrt(gravity / math.max(100.0, pendulumLength));

  CardPhysicsState evaluate(double t) {
    // Stage 1: Official College Logo Reveal (0.00 -> 0.22)
    if (t < 0.22) {
      return CardPhysicsState(
        topCenter: Offset(pivot.dx, pivot.dy - 100.0),
        angle: 0.0,
        ropeOpacity: 0.0,
        zoomProgress: 0.0,
        cardOpacity: 0.0,
      );
    }

    // Stage 2: Gravity-based Falling under Newtonian acceleration (0.22 -> 0.44)
    if (t < 0.44) {
      final normT = ((t - 0.22) / 0.22).clamp(0.0, 1.0);
      // Parabolic Newtonian displacement under gravity: s = 1/2 * g * t^2
      final fallProgress = Curves.easeInQuad.transform(normT);
      final currentY = (restingTopCenter.dy - initialDropHeight) + (initialDropHeight * fallProgress);

      final ropeFadeIn = (normT / 0.25).clamp(0.0, 1.0);

      return CardPhysicsState(
        topCenter: Offset(pivot.dx, currentY),
        angle: 0.0,
        ropeOpacity: ropeFadeIn,
        zoomProgress: 0.0,
        cardOpacity: normT,
      );
    }

    // Stage 3: Damped Pendulum Oscillation (0.44 -> 0.72)
    // Downward momentum converts into angular displacement at taut rope catch:
    if (t < 0.72) {
      final swingProgress = ((t - 0.44) / 0.28).clamp(0.0, 1.0);
      // Damped harmonic oscillator: theta(tau) = theta_0 * e^(-gamma * tau) * sin(omega * tau)
      const initialAngle = 0.105; // ~6.0 degrees initial angular displacement
      final decay = math.exp(-dampingFactor * swingProgress * 2.8);
      final angle = initialAngle * decay * math.sin(swingProgress * 3.0 * math.pi);

      // Arc kinematics around hidden pivot:
      final arcX = pendulumLength * math.sin(angle);
      final arcY = pendulumLength * (math.cos(angle) - 1.0);

      final currentTopCenter = Offset(
        pivot.dx + arcX,
        restingTopCenter.dy + arcY,
      );

      return CardPhysicsState(
        topCenter: currentTopCenter,
        angle: angle,
        ropeOpacity: 1.0,
        zoomProgress: 0.0,
        cardOpacity: 1.0,
      );
    }

    // Stage 4: Continuous Zoom & Morph into Full Viewport (0.72 -> 1.00)
    // Pendulum settled to 0 degrees, card smoothly enlarges towards viewer
    final zoomT = ((t - 0.72) / 0.28).clamp(0.0, 1.0);
    final easedZoom = Curves.easeInOutCubic.transform(zoomT);

    // Rope pulls upward into ceiling and fades out cleanly
    final ropeFade = (1.0 - (zoomT / 0.45)).clamp(0.0, 1.0);

    return CardPhysicsState(
      topCenter: restingTopCenter,
      angle: 0.0,
      ropeOpacity: ropeFade,
      zoomProgress: easedZoom,
      cardOpacity: 1.0,
    );
  }
}

/// Redesigned Animated Startup Screen & Continuous Login Transition for CCE Outpass.
///
/// Features:
/// 1. Opening Logo (0.00 -> 0.22): Authentic Christ College of Engineering emblem fades in
///    and scales gracefully on #F4F1E8 warm ivory background.
/// 2. Single ID Card Gravity Drop (0.22 -> 0.44): Physical ID card enters attached to visible rope.
/// 3. Physics Pendulum Swing (0.44 -> 0.72): Natural harmonic oscillation around hidden pivot.
/// 4. Continuous Zoom (0.72 -> 1.00): ID card smoothly enlarges into full comfortable reading size.
/// 5. Live Functional Login (0.98+): Interactive login directly on the physical ID card!
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.appState,
    this.repaintKey,
  });

  final AppState appState;
  final GlobalKey? repaintKey;

  /// Global flag to ensure intro animation only plays on fresh launch.
  static bool hasPlayedStartup = false;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );

    widget.appState.addListener(_onAppStateChanged);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        SplashScreen.hasPlayedStartup = true;
      }
    });

    if (SplashScreen.hasPlayedStartup) {
      _controller.value = 1.0;
    } else {
      _controller.forward();
    }

    _startParallelTasks();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableMotion || SplashScreen.hasPlayedStartup) {
      _controller.value = 1.0;
      SplashScreen.hasPlayedStartup = true;
    }
  }

  void _onAppStateChanged() {
    if (widget.appState.loggedIn && mounted && !_hasNavigated) {
      _hasNavigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 350),
            pageBuilder: (context, anim, secAnim) => const RootRouter(),
            transitionsBuilder: (context, animation, _, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        );
      });
    }
  }

  Future<void> _startParallelTasks() async {
    try {
      if (!widget.appState.loggedIn) {
        await widget.appState.tryAutoLogin();
      }
    } catch (e) {
      debugPrint('[SplashScreen] Auto-login error: $e');
    } finally {
      if (mounted) {
        if (widget.appState.loggedIn) {
          _onAppStateChanged();
        }
      }
    }
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onAppStateChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: widget.repaintKey,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onDoubleTap: () {
          setState(() {
            SplashScreen.hasPlayedStartup = false;
            _controller.reset();
            _controller.forward();
          });
        },
        child: Scaffold(
          backgroundColor: SplashTokens.background,
          body: SafeArea(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = _controller.value;

                // 1. Stage 1: Official Logo Reveal (0.00 -> 0.22)
                double logoOpacity = 1.0;
                double logoScale = 1.0;
                if (t < 0.14) {
                  final fadeT = (t / 0.14).clamp(0.0, 1.0);
                  logoOpacity = Curves.easeOut.transform(fadeT);
                  logoScale = 0.92 + (0.08 * Curves.easeOutCubic.transform(fadeT));
                } else if (t <= 0.18) {
                  logoOpacity = 1.0;
                  logoScale = 1.0;
                } else if (t <= 0.24) {
                  final fadeOutT = ((t - 0.18) / 0.06).clamp(0.0, 1.0);
                  logoOpacity = 1.0 - Curves.easeIn.transform(fadeOutT);
                  logoScale = 1.0;
                } else {
                  logoOpacity = 0.0;
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final screenW = constraints.maxWidth;
                    final screenH = constraints.maxHeight;

                    // Target full readable card dimensions
                    const targetHeight = 540.0;

                    // Resting card position centered in viewport
                    final restingCardTop = math.max(20.0, (screenH - targetHeight) / 2.0);
                    final pivotX = screenW / 2.0;
                    // Hidden pivot point: strictly off-screen above viewport top (y < 0)
                    const pivotY = -240.0;

                    final simulation = CardPhysicsSimulation(
                      pivot: const Offset(0, pivotY) + Offset(pivotX, 0),
                      restingTopCenter: Offset(pivotX, restingCardTop),
                    );

                    final physics = simulation.evaluate(t);

                    final isCompact = physics.zoomProgress < 0.5;

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // A. Stage 1: Centered Official Logo Reveal
                        if (t <= 0.24)
                          Center(
                            child: Opacity(
                              opacity: logoOpacity.clamp(0.0, 1.0),
                              child: Transform.scale(
                                scale: logoScale,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CceCollegeLogo(size: 96),
                                    const SizedBox(height: 18),
                                    const Text(
                                      'CCE OUTPASS',
                                      style: TextStyle(
                                        fontFamily: SplashTokens.fontName,
                                        fontFamilyFallback: SplashTokens.fontFallbacks,
                                        color: SplashTokens.forestGreen,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 2.0,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'CHRIST COLLEGE OF ENGINEERING',
                                      style: TextStyle(
                                        fontFamily: SplashTokens.fontName,
                                        fontFamilyFallback: SplashTokens.fontFallbacks,
                                        color: SplashTokens.forestGreen,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    const Text(
                                      'AUTONOMOUS • IRINJALAKUDA',
                                      style: TextStyle(
                                        fontFamily: SplashTokens.fontName,
                                        fontFamilyFallback: SplashTokens.fontFallbacks,
                                        color: SplashTokens.antiqueGold,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 2.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        // B. Stages 2-5: Physical College ID Card Login
                        if (t >= 0.22)
                          Center(
                            child: SingleChildScrollView(
                              physics: t >= 0.96
                                  ? const ClampingScrollPhysics()
                                  : const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s16,
                                vertical: AppSpacing.s24,
                              ),
                              child: Transform.translate(
                                offset: Offset(
                                  physics.topCenter.dx - pivotX,
                                  physics.topCenter.dy - restingCardTop,
                                ),
                                child: Transform.rotate(
                                  angle: physics.angle,
                                  alignment: Alignment.topCenter,
                                  child: Opacity(
                                    opacity: physics.cardOpacity.clamp(0.0, 1.0),
                                    child: PhysicalIdCardLogin(
                                      interactive: t >= 0.96,
                                      compactMode: isCompact,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // C. Visible Thin Elegant Suspension Rope with Hidden Pivot
                        // Extends upwards beyond top edge of viewport (pivotY = -240.0)
                        // Visibly connects to top-center of card with flush metallic crimp ferrule
                        if (physics.ropeOpacity > 0.001)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                size: Size(screenW, screenH),
                                painter: SuspendedRopePainter(
                                  pivot: Offset(pivotX, pivotY),
                                  cardTopCenter: physics.topCenter,
                                  ropeOpacity: physics.ropeOpacity,
                                  zoomProgress: physics.zoomProgress,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
