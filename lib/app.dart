import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/theme_provider.dart';
import 'features/analytics/presentation/providers/analytics_provider.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/booking/presentation/providers/booking_provider.dart';
import 'features/leaderboard/presentation/providers/leaderboard_provider.dart';
import 'injection_container.dart';

class BookMyGameApp extends StatelessWidget {
  const BookMyGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(
          value: injector.authProvider,
        ),
        ChangeNotifierProvider<ThemeProvider>.value(
          value: injector.themeProvider,
        ),
        ChangeNotifierProvider<BookingProvider>.value(
          value: injector.bookingProvider,
        ),
        ChangeNotifierProvider<LeaderboardProvider>.value(
          value: injector.leaderboardProvider,
        ),
        ChangeNotifierProvider<AnalyticsProvider>.value(
          value: injector.analyticsProvider,
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp.router(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            routerConfig: injector.appRouter.router,
          );
        },
      ),
    );
  }
}
