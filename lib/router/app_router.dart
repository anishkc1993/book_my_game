import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_constants.dart';
import '../features/auth/presentation/pages/home_page.dart';
import '../features/auth/presentation/pages/otp_verification_page.dart';
import '../features/auth/presentation/pages/phone_input_page.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/analytics/presentation/pages/admin_analytics_page.dart';
import '../features/booking/presentation/pages/admin_booking_page.dart';
import '../features/booking/presentation/pages/booking_page.dart';
import '../features/booking/presentation/pages/slot_management_page.dart';
import '../features/leaderboard/presentation/pages/leaderboard_page.dart';

class AppRouter {
  final AuthProvider authProvider;

  AppRouter({required this.authProvider});

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
    ];

    final isOnAuthRoute = authRoutes.contains(currentPath);

    if (isAuthenticated && isOnAuthRoute) {
      return RoutePaths.home;
    }

    if (!isAuthenticated && !isOnAuthRoute) {
      return RoutePaths.phoneInput;
    }

    if (!isAuthenticated && currentPath == RoutePaths.splash) {
      return RoutePaths.phoneInput;
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
      ];
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.surface,
              colorScheme.primaryContainer.withOpacity(0.3),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                ),
              );
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Container
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.tertiary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.sports_esports_rounded,
                    size: 60,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 32),

                // App Name (hidden per user request, just showing loading)
                Text(
                  'Loading...',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 48),

                // Loading Indicator
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: colorScheme.primary,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
