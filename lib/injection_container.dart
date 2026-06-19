import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/theme_provider.dart';
import 'features/analytics/data/datasources/analytics_remote_datasource.dart';
import 'features/analytics/data/repositories/analytics_repository_impl.dart';
import 'features/analytics/domain/repositories/analytics_repository.dart';
import 'features/analytics/presentation/providers/analytics_provider.dart';
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/get_current_user_usecase.dart';
import 'features/auth/domain/usecases/send_email_link_usecase.dart';
import 'features/auth/domain/usecases/send_otp_usecase.dart';
import 'features/auth/domain/usecases/sign_out_usecase.dart';
import 'features/auth/domain/usecases/verify_email_link_usecase.dart';
import 'features/auth/domain/usecases/verify_otp_usecase.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/booking/data/datasources/booking_remote_datasource.dart';
import 'features/booking/data/repositories/booking_repository_impl.dart';
import 'features/booking/domain/repositories/booking_repository.dart';
import 'features/booking/presentation/providers/booking_provider.dart';
import 'features/leaderboard/data/datasources/leaderboard_remote_datasource.dart';
import 'features/leaderboard/data/repositories/leaderboard_repository_impl.dart';
import 'features/leaderboard/domain/repositories/leaderboard_repository.dart';
import 'features/leaderboard/presentation/providers/leaderboard_provider.dart';
import 'features/turf/data/datasources/turf_remote_datasource.dart';
import 'features/turf/data/repositories/turf_repository_impl.dart';
import 'features/turf/domain/repositories/turf_repository.dart';
import 'features/turf/presentation/providers/turf_provider.dart';
import 'features/academy/data/datasources/academy_remote_datasource.dart';
import 'features/academy/data/repositories/academy_repository_impl.dart';
import 'features/academy/domain/repositories/academy_repository.dart';
import 'features/academy/presentation/providers/academy_provider.dart';
import 'features/monthly_plans/data/datasources/monthly_plan_remote_datasource.dart';
import 'features/monthly_plans/data/repositories/monthly_plan_repository_impl.dart';
import 'features/monthly_plans/domain/repositories/monthly_plan_repository.dart';
import 'features/monthly_plans/presentation/providers/monthly_plan_provider.dart';
import 'features/tournaments/data/datasources/tournament_remote_datasource.dart';
import 'features/tournaments/data/repositories/tournament_repository_impl.dart';
import 'features/tournaments/domain/repositories/tournament_repository.dart';
import 'features/tournaments/presentation/providers/tournament_provider.dart';
import 'features/concessions/data/datasources/concession_remote_datasource.dart';
import 'features/concessions/data/repositories/concession_repository_impl.dart';
import 'features/concessions/domain/repositories/concession_repository.dart';
import 'features/concessions/presentation/providers/concession_provider.dart';
import 'router/app_router.dart';

class InjectionContainer {
  static final InjectionContainer _instance = InjectionContainer._internal();
  factory InjectionContainer() => _instance;
  InjectionContainer._internal();

  late final firebase_auth.FirebaseAuth _firebaseAuth;
  late final FirebaseFirestore _firestore;
  late final SharedPreferences _sharedPreferences;
  SharedPreferences get sharedPreferences => _sharedPreferences;

  late final AuthRemoteDataSource _authRemoteDataSource;
  late final AuthRepository _authRepository;

  late final SendOtpUseCase _sendOtpUseCase;
  late final VerifyOtpUseCase _verifyOtpUseCase;
  late final GetCurrentUserUseCase _getCurrentUserUseCase;
  late final SignOutUseCase _signOutUseCase;
  late final SendEmailLinkUseCase _sendEmailLinkUseCase;
  late final VerifyEmailLinkUseCase _verifyEmailLinkUseCase;

  late final AuthProvider authProvider;
  late final ThemeProvider themeProvider;
  late final AppRouter appRouter;

  // Booking
  late final BookingRemoteDataSource _bookingRemoteDataSource;
  late final BookingRepository _bookingRepository;
  late final BookingProvider bookingProvider;

  // Leaderboard
  late final LeaderboardRemoteDataSource _leaderboardRemoteDataSource;
  late final LeaderboardRepository _leaderboardRepository;
  late final LeaderboardProvider leaderboardProvider;

  // Analytics
  late final AnalyticsRemoteDataSource _analyticsRemoteDataSource;
  late final AnalyticsRepository _analyticsRepository;
  late final AnalyticsProvider analyticsProvider;

  // Turf
  late final TurfRemoteDataSource _turfRemoteDataSource;
  late final TurfRepository _turfRepository;
  late final TurfProvider turfProvider;

  // Academy
  late final AcademyRemoteDataSource _academyRemoteDataSource;
  late final AcademyRepository _academyRepository;
  late final AcademyProvider academyProvider;

  // Monthly plans
  late final MonthlyPlanRemoteDataSource _monthlyPlanRemoteDataSource;
  late final MonthlyPlanRepository _monthlyPlanRepository;
  late final MonthlyPlanProvider monthlyPlanProvider;

  // Tournaments
  late final TournamentRemoteDataSource _tournamentRemoteDataSource;
  late final TournamentRepository _tournamentRepository;
  late final TournamentProvider tournamentProvider;

  // Concessions
  late final ConcessionRemoteDataSource _concessionRemoteDataSource;
  late final ConcessionRepository _concessionRepository;
  late final ConcessionProvider concessionProvider;

  Future<void> init() async {
    // External dependencies
    _firebaseAuth = firebase_auth.FirebaseAuth.instance;
    _firestore = FirebaseFirestore.instance;
    _sharedPreferences = await SharedPreferences.getInstance();

    // Data sources
    _authRemoteDataSource = AuthRemoteDataSourceImpl(
      firebaseAuth: _firebaseAuth,
      firestore: _firestore,
    );

    // Repositories
    _authRepository = AuthRepositoryImpl(
      remoteDataSource: _authRemoteDataSource,
    );

    // Use cases
    _sendOtpUseCase = SendOtpUseCase(_authRepository);
    _verifyOtpUseCase = VerifyOtpUseCase(_authRepository);
    _getCurrentUserUseCase = GetCurrentUserUseCase(_authRepository);
    _signOutUseCase = SignOutUseCase(_authRepository);
    _sendEmailLinkUseCase = SendEmailLinkUseCase(_authRepository);
    _verifyEmailLinkUseCase = VerifyEmailLinkUseCase(_authRepository);

    // Providers
    authProvider = AuthProvider(
      sendOtpUseCase: _sendOtpUseCase,
      verifyOtpUseCase: _verifyOtpUseCase,
      getCurrentUserUseCase: _getCurrentUserUseCase,
      signOutUseCase: _signOutUseCase,
      sendEmailLinkUseCase: _sendEmailLinkUseCase,
      verifyEmailLinkUseCase: _verifyEmailLinkUseCase,
      authRepository: _authRepository,
      prefs: _sharedPreferences,
    );

    themeProvider = ThemeProvider(prefs: _sharedPreferences);

    // Booking data sources
    _bookingRemoteDataSource = BookingRemoteDataSourceImpl(
      firestore: _firestore,
    );

    // Booking repositories
    _bookingRepository = BookingRepositoryImpl(
      remoteDataSource: _bookingRemoteDataSource,
    );

    // Booking provider
    bookingProvider = BookingProvider(
      repository: _bookingRepository,
    );

    // Leaderboard data sources
    _leaderboardRemoteDataSource = LeaderboardRemoteDataSourceImpl(
      firestore: _firestore,
      prefs: _sharedPreferences,
    );

    // Leaderboard repositories
    _leaderboardRepository = LeaderboardRepositoryImpl(
      remoteDataSource: _leaderboardRemoteDataSource,
    );

    // Leaderboard provider
    leaderboardProvider = LeaderboardProvider(
      repository: _leaderboardRepository,
    );

    // Analytics data sources
    _analyticsRemoteDataSource = AnalyticsRemoteDataSourceImpl(
      firestore: _firestore,
    );

    // Analytics repositories
    _analyticsRepository = AnalyticsRepositoryImpl(
      remoteDataSource: _analyticsRemoteDataSource,
    );

    // Analytics provider
    analyticsProvider = AnalyticsProvider(
      repository: _analyticsRepository,
    );

    // Turf data sources / repository / provider
    _turfRemoteDataSource = TurfRemoteDataSourceImpl(firestore: _firestore);
    _turfRepository = TurfRepositoryImpl(remoteDataSource: _turfRemoteDataSource);
    turfProvider = TurfProvider(repository: _turfRepository);

    // Academy data sources / repository / provider
    _academyRemoteDataSource =
        AcademyRemoteDataSourceImpl(firestore: _firestore);
    _academyRepository =
        AcademyRepositoryImpl(remoteDataSource: _academyRemoteDataSource);
    academyProvider = AcademyProvider(repository: _academyRepository);

    // Monthly plans data sources / repository / provider
    _monthlyPlanRemoteDataSource =
        MonthlyPlanRemoteDataSourceImpl(firestore: _firestore);
    _monthlyPlanRepository = MonthlyPlanRepositoryImpl(
        remoteDataSource: _monthlyPlanRemoteDataSource);
    monthlyPlanProvider =
        MonthlyPlanProvider(repository: _monthlyPlanRepository);

    // Tournaments data sources / repository / provider
    _tournamentRemoteDataSource =
        TournamentRemoteDataSourceImpl(firestore: _firestore);
    _tournamentRepository = TournamentRepositoryImpl(
        remoteDataSource: _tournamentRemoteDataSource);
    tournamentProvider =
        TournamentProvider(repository: _tournamentRepository);

    // Concessions data sources / repository / provider
    _concessionRemoteDataSource =
        ConcessionRemoteDataSourceImpl(firestore: _firestore);
    _concessionRepository = ConcessionRepositoryImpl(
        remoteDataSource: _concessionRemoteDataSource);
    concessionProvider =
        ConcessionProvider(repository: _concessionRepository);

    // Keep turfId in sync with the authenticated user across all providers
    // that read per-turf data.
    void syncTurf() {
      final tid = authProvider.user?.turfId;
      bookingProvider.setTurfId(tid);
      leaderboardProvider.setTurfId(tid);
      analyticsProvider.setTurfId(tid);
      monthlyPlanProvider.setTurfId(tid);
      tournamentProvider.setTurfId(tid);
      concessionProvider.setTurfId(tid);
    }
    syncTurf();
    authProvider.addListener(syncTurf);

    // Whenever bookings mutate (create / mark paid / status change / sweep),
    // invalidate analytics cache and force-refresh the leaderboard so the
    // dashboard + leaderboard reflect the change without manual refresh.
    bookingProvider.mutations.addListener(() {
      analyticsProvider.clearCache();
      analyticsProvider.fetchAnalytics(forceRefresh: true);
      leaderboardProvider.fetchLeaderboard(forceRefresh: true);
    });

    // Monthly-plan payments also affect dashboard revenue — same pattern.
    monthlyPlanProvider.mutations.addListener(() {
      analyticsProvider.clearCache();
      analyticsProvider.fetchAnalytics(forceRefresh: true);
    });

    // Tournament payments → dashboard revenue.
    tournamentProvider.mutations.addListener(() {
      analyticsProvider.clearCache();
      analyticsProvider.fetchAnalytics(forceRefresh: true);
    });

    // Concession sales → separate concession card on analytics.
    concessionProvider.mutations.addListener(() {
      analyticsProvider.clearCache();
      analyticsProvider.fetchAnalytics(forceRefresh: true);
    });

    // Router
    appRouter = AppRouter(authProvider: authProvider);
  }
}

final injector = InjectionContainer();
