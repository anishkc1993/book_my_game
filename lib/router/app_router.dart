import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/pages/email_input_page.dart';
import '../features/auth/presentation/pages/home_page.dart';
import '../features/auth/presentation/pages/otp_verification_page.dart';
import '../features/auth/presentation/pages/phone_input_page.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/analytics/presentation/pages/admin_analytics_page.dart';
import '../features/analytics/presentation/pages/yearly_revenue_page.dart';
import '../features/analytics/presentation/pages/hourly_breakdown_page.dart';
import '../features/booking/presentation/pages/admin_booking_page.dart';
import '../features/booking/presentation/pages/booking_page.dart';
import '../features/booking/presentation/pages/regular_bookings_page.dart';
import '../features/booking/presentation/pages/slot_management_page.dart';
import '../features/turf/presentation/pages/turf_selection_page.dart';
import '../features/turf/presentation/pages/venue_location_page.dart';
import '../features/leaderboard/presentation/pages/leaderboard_page.dart';
import '../features/academy/presentation/pages/academy_players_page.dart';
import '../features/monthly_plans/presentation/pages/monthly_plans_page.dart';
import '../features/concessions/presentation/pages/concessions_page.dart';
import '../features/concessions/presentation/pages/concession_collections_page.dart';
import '../features/concessions/presentation/pages/concession_history_page.dart';
import '../features/auth/presentation/pages/more_actions_page.dart';

class AppRouter {
  final AuthProvider authProvider;

  AppRouter({required this.authProvider}) {
    _initDeepLinks();
  }

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  void _initDeepLinks() async {
    try {
      final initialLink = await _appLinks.getInitialLinkString();
      if (initialLink != null) {
        _handleIncomingLink(initialLink);
      }
    } catch (e) {
      debugPrint('AppRouter: error reading initial link: $e');
    }

    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) => _handleIncomingLink(uri.toString()),
      onError: (e) => debugPrint('AppRouter: deep link stream error: $e'),
    );
  }

  void _handleIncomingLink(String link) {
    if (FirebaseAuth.instance.isSignInWithEmailLink(link)) {
      debugPrint('AppRouter: Firebase email link received');
      authProvider.handleEmailLink(link);
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }

  late final GoRouter router = GoRouter(
    initialLocation: RoutePaths.splash,
    refreshListenable: authProvider,
    redirect: _redirect,
    routes: _routes,
  );

  String? _redirect(BuildContext context, GoRouterState state) {
    final isAuthenticated = authProvider.isAuthenticated;
    final isLoading = authProvider.status == AuthStatus.initial ||
        authProvider.status == AuthStatus.loading;
    final currentPath = state.matchedLocation;

    if (isLoading) {
      return null;
    }

    final authRoutes = [
      RoutePaths.splash,
      RoutePaths.phoneInput,
      RoutePaths.otpVerification,
      RoutePaths.emailInput,
    ];

    final isOnAuthRoute = authRoutes.contains(currentPath);

    if (!isAuthenticated && !isOnAuthRoute) {
      return RoutePaths.phoneInput;
    }

    if (!isAuthenticated && currentPath == RoutePaths.splash) {
      return RoutePaths.phoneInput;
    }

    if (isAuthenticated) {
      final user = authProvider.user;
      // After auth, any user without a turfId must pick one (admins are
      // auto-linked by phone in the data source; if that didn't find a turf,
      // we still route them here — they can contact support to be set up).
      final needsTurf = user != null && !user.hasTurf;
      final isOnSelectTurf = currentPath == RoutePaths.selectTurf;

      if (isOnAuthRoute) {
        return needsTurf ? RoutePaths.selectTurf : RoutePaths.home;
      }
      if (needsTurf && !isOnSelectTurf) {
        return RoutePaths.selectTurf;
      }
      // Don't block users with a turf from visiting /select-turf — they may
      // be switching to a different turf.
    }

    return null;
  }

  List<RouteBase> get _routes => [
        GoRoute(
          path: RoutePaths.splash,
          name: RouteNames.splash,
          builder: (context, state) => const SplashPage(),
        ),
        GoRoute(
          path: RoutePaths.phoneInput,
          name: RouteNames.phoneInput,
          builder: (context, state) => const PhoneInputPage(),
        ),
        GoRoute(
          path: RoutePaths.otpVerification,
          name: RouteNames.otpVerification,
          builder: (context, state) {
            final phoneNumber = state.extra as String? ?? '';
            return OtpVerificationPage(phoneNumber: phoneNumber);
          },
        ),
        GoRoute(
          path: RoutePaths.emailInput,
          name: RouteNames.emailInput,
          builder: (context, state) => const EmailInputPage(),
        ),
        GoRoute(
          path: RoutePaths.home,
          name: RouteNames.home,
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          path: RoutePaths.booking,
          name: RouteNames.booking,
          builder: (context, state) => const BookingPage(),
        ),
        GoRoute(
          path: RoutePaths.adminBooking,
          name: RouteNames.adminBooking,
          builder: (context, state) => const AdminBookingPage(),
        ),
        GoRoute(
          path: RoutePaths.leaderboard,
          name: RouteNames.leaderboard,
          builder: (context, state) => const LeaderboardPage(),
        ),
        GoRoute(
          path: RoutePaths.slotManagement,
          name: RouteNames.slotManagement,
          builder: (context, state) => const SlotManagementPage(),
        ),
        GoRoute(
          path: RoutePaths.adminAnalytics,
          name: RouteNames.adminAnalytics,
          builder: (context, state) => const AdminAnalyticsPage(),
        ),
        GoRoute(
          path: RoutePaths.regularBookings,
          name: RouteNames.regularBookings,
          builder: (context, state) => const RegularBookingsPage(),
        ),
        GoRoute(
          path: RoutePaths.selectTurf,
          name: RouteNames.selectTurf,
          builder: (context, state) => const TurfSelectionPage(),
        ),
        GoRoute(
          path: RoutePaths.venueLocation,
          name: RouteNames.venueLocation,
          builder: (context, state) => const VenueLocationPage(),
        ),
        GoRoute(
          path: RoutePaths.academy,
          name: RouteNames.academy,
          builder: (context, state) => const AcademyPlayersPage(),
        ),
        GoRoute(
          path: RoutePaths.monthlyPlans,
          name: RouteNames.monthlyPlans,
          builder: (context, state) => const MonthlyPlansPage(),
        ),
        GoRoute(
          path: RoutePaths.yearlyRevenue,
          name: RouteNames.yearlyRevenue,
          builder: (context, state) => const YearlyRevenuePage(),
        ),
        GoRoute(
          path: RoutePaths.concessions,
          name: RouteNames.concessions,
          builder: (context, state) => const ConcessionsPage(),
        ),
        GoRoute(
          path: RoutePaths.moreActions,
          name: RouteNames.moreActions,
          builder: (context, state) => const MoreActionsPage(),
        ),
        GoRoute(
          path: RoutePaths.hourlyBreakdown,
          name: RouteNames.hourlyBreakdown,
          builder: (context, state) => const HourlyBreakdownPage(),
        ),
        GoRoute(
          path: RoutePaths.concessionCollections,
          name: RouteNames.concessionCollections,
          builder: (context, state) => const ConcessionCollectionsPage(),
        ),
        GoRoute(
          path: RoutePaths.concessionHistory,
          name: RouteNames.concessionHistory,
          builder: (context, state) => const ConcessionHistoryPage(),
        ),
      ];
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
  // Drives the staged intro: mark scales in, pitch lines draw, wordmark
  // fades up, tagline fades in.
  late final AnimationController _intro;
  // Continuous loop for the radial glow + ball pulse + spinner.
  late final AnimationController _loop;
  // Slow controller that drives the bottom progress bar 0 → 1 over the
  // splash lifetime, then rolls over and cycles the status text.
  late final AnimationController _progress;
  late final AnimationController _spinner;

  late final Animation<double> _markScale;
  late final Animation<double> _markOpacity;
  late final Animation<double> _pitchDraw;
  late final Animation<double> _ballPulseIn;
  late final Animation<double> _wordmarkOpacity;
  late final Animation<Offset> _wordmarkSlide;
  late final Animation<double> _taglineOpacity;
  late final Animation<double> _footerOpacity;
  late final Animation<Offset> _footerSlide;
  late final Animation<double> _glowPulse;
  late final Animation<double> _ballPulseLoop;

  /// Rotating status messages — match the reference video order.
  static const _statusMessages = <String>[
    'Warming up the turf…',
    'Loading your bookings…',
    'Almost kickoff…',
  ];
  int _statusIndex = 0;

  @override
  void initState() {
    super.initState();

    _intro = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    _loop = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    )..repeat(reverse: true);
    // Spinner rotates once per second — separate non-reversing controller.
    _spinner = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    )..repeat();
    // Progress fills over ~5 s and loops — when it wraps, advance the
    // status message so the splash feels alive without needing real data.
    _progress = AnimationController(
      duration: const Duration(milliseconds: 5000),
      vsync: this,
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          setState(() {
            _statusIndex = (_statusIndex + 1) % _statusMessages.length;
          });
          _progress
            ..reset()
            ..forward();
        }
      });
    _progress.forward();

    // 0.00 - 0.45 → mark fades + scales in
    _markScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
      ),
    );
    _markOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
    );

    // 0.20 - 0.70 → pitch lines draw on
    _pitchDraw = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.20, 0.70, curve: Curves.easeOutCubic),
    );

    // 0.55 - 0.75 → ball appears with a tiny pop
    _ballPulseIn = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.55, 0.78, curve: Curves.easeOutBack),
    );

    // 0.55 - 0.85 → wordmark fades up
    _wordmarkOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.55, 0.85, curve: Curves.easeIn),
    );
    _wordmarkSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.55, 0.85, curve: Curves.easeOutCubic),
    ));

    // 0.75 - 1.00 → tagline fades in last
    _taglineOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.75, 1.0, curve: Curves.easeIn),
    );

    // 0.85 - 1.00 → bottom footer (spinner / status / progress / version)
    // slides up and fades in after everything else.
    _footerOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.85, 1.0, curve: Curves.easeIn),
    );
    _footerSlide = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.85, 1.0, curve: Curves.easeOutCubic),
    ));

    _glowPulse = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _loop, curve: Curves.easeInOut),
    );
    _ballPulseLoop = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _loop, curve: Curves.easeInOut),
    );

    _intro.forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    _spinner.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F08),
      body: SizedBox.expand(
        child: AnimatedBuilder(
          animation:
              Listenable.merge([_intro, _loop, _spinner, _progress]),
          builder: (context, _) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Radial glow background (subtle continuous pulse).
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.15),
                        radius: 0.85 * _glowPulse.value,
                        colors: [
                          AppColors.brandGreen
                              .withValues(alpha: 0.55 * _glowPulse.value),
                          AppColors.brandGreen.withValues(alpha: 0.05),
                          const Color(0xFF0A0F08),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),
                // Logo + wordmark stack.
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Opacity(
                      opacity: _markOpacity.value,
                      child: Transform.scale(
                        scale: _markScale.value,
                        child: _BmgPitchMark(
                          drawProgress: _pitchDraw.value,
                          ballScale: _ballPulseIn.value *
                              _ballPulseLoop.value,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SlideTransition(
                      position: _wordmarkSlide,
                      child: Opacity(
                        opacity: _wordmarkOpacity.value,
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontFamily: 'DM Sans',
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -1,
                              height: 1.0,
                            ),
                            children: [
                              TextSpan(text: 'BMG'),
                              TextSpan(
                                text: '.',
                                style: TextStyle(
                                  color: AppColors.limeAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Opacity(
                      opacity: _taglineOpacity.value,
                      child: const Text(
                        'BOOK MY GAME',
                        style: TextStyle(
                          color: Color(0xFFB8C2B0),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                  ],
                ),
                // ── Footer: spinner + status + progress bar + version ──
                Positioned(
                  left: 28,
                  right: 28,
                  bottom: 48,
                  child: SlideTransition(
                    position: _footerSlide,
                    child: Opacity(
                      opacity: _footerOpacity.value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Spinner + status text.
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _SplashSpinner(turns: _spinner.value),
                              const SizedBox(width: 10),
                              Text(
                                _statusMessages[_statusIndex],
                                style: const TextStyle(
                                  color: Color(0xFFE5ECE0),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Progress bar.
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: _progress.value,
                              minHeight: 4,
                              backgroundColor: const Color(0xFF1B2614),
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(
                                      AppColors.limeAccent),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Version line — JetBrains Mono is the design
                          // reference; fall back to system mono so the
                          // splash still renders without bundling a font.
                          const Text(
                            'v2.4.0 · Kathmandu Valley',
                            style: TextStyle(
                              color: Color(0xFF7C8C72),
                              fontSize: 10,
                              letterSpacing: 1.4,
                              fontFamily: 'monospace',
                              fontFeatures: [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Squircle "pitch" mark — rounded green tile with the futsal lines
/// drawing in (top + bottom border, halfway line, center circle, dot).
class _BmgPitchMark extends StatelessWidget {
  final double drawProgress; // 0..1, controls stroke draw-on
  final double ballScale;
  const _BmgPitchMark({
    required this.drawProgress,
    required this.ballScale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        color: AppColors.brandGreen,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.limeAccent.withValues(alpha: 0.45),
            blurRadius: 38,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: AppColors.brandGreen.withValues(alpha: 0.55),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _PitchPainter(
          progress: drawProgress,
          ballScale: ballScale,
        ),
      ),
    );
  }
}

class _PitchPainter extends CustomPainter {
  final double progress;
  final double ballScale;
  _PitchPainter({required this.progress, required this.ballScale});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = AppColors.limeAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = AppColors.limeAccent
      ..style = PaintingStyle.fill;

    final inset = 18.0;
    final rect = Rect.fromLTWH(inset, inset, size.width - inset * 2,
        size.height - inset * 2);

    // Three sequential draw stages — borders → centre line → centre circle.
    final t1 = (progress / 0.45).clamp(0.0, 1.0);
    final t2 = ((progress - 0.40) / 0.30).clamp(0.0, 1.0);
    final t3 = ((progress - 0.65) / 0.35).clamp(0.0, 1.0);

    // Stage 1 — pitch boundary as a rounded rectangle drawn perimeter-wise.
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    final borderPath = Path()..addRRect(rrect);
    _drawPathFraction(canvas, borderPath, stroke, t1);

    // Stage 2 — halfway line across the middle.
    final midY = rect.top + rect.height / 2;
    final halfwayPath = Path()
      ..moveTo(rect.left, midY)
      ..lineTo(rect.right, midY);
    _drawPathFraction(canvas, halfwayPath, stroke, t2);

    // Stage 3 — centre circle (concentric), drawn as a single arc.
    final center = rect.center;
    final radius = rect.width * 0.18;
    final circlePath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    _drawPathFraction(canvas, circlePath, stroke, t3);

    // Centre dot + ball — appear together with the circle.
    if (t3 > 0) {
      canvas.drawCircle(center, 2.5 * t3, fill);
      // Ball sits just above the centre line, scales in.
      final ballCenter = Offset(center.dx, center.dy - radius - 4);
      canvas.drawCircle(
        ballCenter,
        3.2 * ballScale * t3,
        fill,
      );
    }
  }

  /// Draw [path] up to [fraction] (0..1) using a PathMetric walk —
  /// gives the "drawing on" effect.
  void _drawPathFraction(
      Canvas canvas, Path path, Paint paint, double fraction) {
    if (fraction <= 0) return;
    if (fraction >= 1) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      final extracted = metric.extractPath(0, metric.length * fraction);
      canvas.drawPath(extracted, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PitchPainter old) =>
      old.progress != progress || old.ballScale != ballScale;
}

/// Small spinning ring next to the status text. [turns] is 0..1 from the
/// driving controller; multiplied to full rotations.
class _SplashSpinner extends StatelessWidget {
  final double turns;
  const _SplashSpinner({required this.turns});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: Transform.rotate(
        angle: turns * 2 * 3.14159265,
        child: CustomPaint(painter: _SpinnerPainter()),
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 1.5;
    final track = Paint()
      ..color = AppColors.limeAccent.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final arc = Paint()
      ..color = AppColors.limeAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);
    // ~240° lime arc that rotates with the parent Transform.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14 / 2,
      4.18,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
