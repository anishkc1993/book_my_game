import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/theme_provider.dart';
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/get_current_user_usecase.dart';
import 'features/auth/domain/usecases/send_otp_usecase.dart';
import 'features/auth/domain/usecases/sign_out_usecase.dart';
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
import 'router/app_router.dart';

class InjectionContainer {
  static final InjectionContainer _instance = InjectionContainer._internal();
  factory InjectionContainer() => _instance;
  InjectionContainer._internal();

  late final firebase_auth.FirebaseAuth _firebaseAuth;
  late final FirebaseFirestore _firestore;
  late final SharedPreferences _sharedPreferences;

  late final AuthRemoteDataSource _authRemoteDataSource;
  late final AuthRepository _authRepository;

  late final SendOtpUseCase _sendOtpUseCase;
  late final VerifyOtpUseCase _verifyOtpUseCase;
  late final GetCurrentUserUseCase _getCurrentUserUseCase;
  late final SignOutUseCase _signOutUseCase;

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

    // Providers
    authProvider = AuthProvider(
      sendOtpUseCase: _sendOtpUseCase,
      verifyOtpUseCase: _verifyOtpUseCase,
      getCurrentUserUseCase: _getCurrentUserUseCase,
      signOutUseCase: _signOutUseCase,
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

    // Router
    appRouter = AppRouter(authProvider: authProvider);
  }
}

final injector = InjectionContainer();
