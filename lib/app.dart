import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/analytics/presentation/providers/analytics_provider.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/booking/presentation/providers/booking_provider.dart';
import 'features/leaderboard/presentation/providers/leaderboard_provider.dart';
import 'features/turf/presentation/providers/turf_provider.dart';
import 'features/academy/presentation/providers/academy_provider.dart';
import 'features/monthly_plans/presentation/providers/monthly_plan_provider.dart';
import 'features/tournaments/presentation/providers/tournament_provider.dart';
import 'features/concessions/presentation/providers/concession_provider.dart';
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
        ChangeNotifierProvider<TurfProvider>.value(
          value: injector.turfProvider,
        ),
        ChangeNotifierProvider<AcademyProvider>.value(
          value: injector.academyProvider,
        ),
        ChangeNotifierProvider<MonthlyPlanProvider>.value(
          value: injector.monthlyPlanProvider,
        ),
        ChangeNotifierProvider<TournamentProvider>.value(
          value: injector.tournamentProvider,
        ),
        ChangeNotifierProvider<ConcessionProvider>.value(
          value: injector.concessionProvider,
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
            builder: (context, child) {
              final isDark =
                  Theme.of(context).brightness == Brightness.dark;
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? [
                            AppColors.darkBg,
                            const Color(0xFF080808),
                          ]
                        : [
                            AppColors.lightGradientTop,
                            AppColors.lightGradientBottom,
                          ],
                  ),
                ),
                child: child,
              );
            },
          );
        },
      ),
    );
  }
}
