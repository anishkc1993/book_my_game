import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/user_entity.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Stream<UserModel?> get authStateChanges;

  Future<UserModel?> getCurrentUser();

  Future<void> sendOtp({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required Function(UserModel user) onAutoVerified,
    int? resendToken,
  });

  Future<UserModel> verifyOtp({
    required String verificationId,
    required String otp,
  });

  Future<void> sendEmailLink({required String email});

  Future<UserModel> verifyEmailLink({
    required String email,
    required String emailLink,
  });

  bool isSignInWithEmailLink(String link);

  Future<void> signOut();

  Future<UserModel> saveUserToFirestore(UserModel user);

  Future<UserModel?> getUserFromFirestore(String uid);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  AuthRemoteDataSourceImpl({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<UserModel?> get authStateChanges {
    return _firebaseAuth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;

      final userModel = UserModel.fromFirebaseUser(user);
      // Try to get Firestore data for role/membership
      final firestoreUser = await getUserFromFirestore(user.uid);
      return firestoreUser ?? userModel;
    });
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;

    final userModel = UserModel.fromFirebaseUser(user);
    // Fetch Firestore data to get role and membership
    final firestoreUser = await getUserFromFirestore(user.uid);
    return firestoreUser ?? userModel;
  }

  @override
  Future<UserModel?> getUserFromFirestore(String uid) async {
    try {
      final docSnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();

      if (!docSnapshot.exists) return null;

      return UserModel.fromFirestore(docSnapshot);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> sendOtp({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required Function(UserModel user) onAutoVerified,
    int? resendToken,
  }) async {
    try {
      debugPrint('📱 sendOtp: Starting for $phoneNumber');
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: AppConstants.otpTimeoutSeconds),
        forceResendingToken: resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('📱 sendOtp: verificationCompleted called');
          try {
            final userCredential =
                await _firebaseAuth.signInWithCredential(credential);
            if (userCredential.user != null) {
              final userModel =
                  UserModel.fromFirebaseUser(userCredential.user!);
              // Save to Firestore and get merged user with role/membership
              final savedUser = await saveUserToFirestore(userModel);
              onAutoVerified(savedUser);
            }
          } catch (e) {
            debugPrint('❌ sendOtp: Auto verification error: $e');
            onError('Auto verification failed: ${e.toString()}');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('❌ sendOtp: verificationFailed: ${e.message}');
          onError(_mapAuthErrorToMessage(e));
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('✅ sendOtp: codeSent - verificationId=$verificationId');
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('⏰ sendOtp: codeAutoRetrievalTimeout');
        },
      );
      debugPrint('📱 sendOtp: verifyPhoneNumber completed');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ sendOtp: FirebaseAuthException: ${e.message}');
      throw AuthException(_mapAuthErrorToMessage(e));
    } catch (e) {
      debugPrint('❌ sendOtp: Exception: $e');
      throw AuthException(e.toString());
    }
  }

  @override
  Future<UserModel> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    try {
      debugPrint('🔐 verifyOtp: Starting verification');
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);
      debugPrint('🔐 verifyOtp: Firebase Auth successful');

      if (userCredential.user == null) {
        throw const AuthException('Verification failed');
      }

      final userModel = UserModel.fromFirebaseUser(userCredential.user!);
      debugPrint('🔐 verifyOtp: User model created, saving to Firestore...');
      // Save to Firestore and get merged user with role/membership
      final savedUser = await saveUserToFirestore(userModel);
      debugPrint('🔐 verifyOtp: Firestore save complete!');

      return savedUser;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ verifyOtp FirebaseAuthException: ${e.message}');
      throw AuthException(_mapAuthErrorToMessage(e));
    } catch (e) {
      debugPrint('❌ verifyOtp Error: $e');
      throw AuthException(e.toString());
    }
  }

  @override
  Future<void> sendEmailLink({required String email}) async {
    try {
      final actionCodeSettings = ActionCodeSettings(
        url: AppConstants.emailLinkUrl,
        handleCodeInApp: true,
        androidPackageName: 'com.example.book_my_game',
        androidInstallApp: true,
        androidMinimumVersion: '21',
      );
      await _firebaseAuth.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: actionCodeSettings,
      );
      debugPrint('📧 sendEmailLink: Link sent to $email');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ sendEmailLink: ${e.message}');
      throw AuthException(_mapAuthErrorToMessage(e));
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  @override
  Future<UserModel> verifyEmailLink({
    required String email,
    required String emailLink,
  }) async {
    try {
      debugPrint('📧 verifyEmailLink: Verifying for $email');
      final userCredential = await _firebaseAuth.signInWithEmailLink(
        email: email,
        emailLink: emailLink,
      );

      if (userCredential.user == null) {
        throw const AuthException('Email verification failed');
      }

      final userModel = UserModel.fromFirebaseUser(userCredential.user!);
      final savedUser = await saveUserToFirestore(userModel);
      debugPrint('📧 verifyEmailLink: Success for $email');
      return savedUser;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ verifyEmailLink: ${e.message}');
      throw AuthException(_mapAuthErrorToMessage(e));
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  @override
  bool isSignInWithEmailLink(String link) {
    return _firebaseAuth.isSignInWithEmailLink(link);
  }

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      throw AuthException('Failed to sign out: ${e.toString()}');
    }
  }

  @override
  Future<UserModel> saveUserToFirestore(UserModel user) async {
    try {
      debugPrint('📝 saveUserToFirestore: Starting for uid=${user.uid}');
      final userDoc =
          _firestore.collection(AppConstants.usersCollection).doc(user.uid);

      final docSnapshot = await userDoc.get();
      debugPrint('📝 saveUserToFirestore: Doc exists=${docSnapshot.exists}');

      UserModel resolvedUser;
      if (!docSnapshot.exists) {
        // Create new user with defaults (CUSTOMER, FREE)
        final data = user.toFirestore();
        debugPrint('📝 saveUserToFirestore: Creating new user with data=$data');
        await userDoc.set(data);
        debugPrint('📝 saveUserToFirestore: User created successfully!');
        resolvedUser = user;
      } else {
        // User exists - update timestamp and return merged data
        debugPrint('📝 saveUserToFirestore: Updating existing user');
        await userDoc.update(user.toFirestoreUpdate());
        resolvedUser = user.mergeWithFirestore(
            docSnapshot.data() as Map<String, dynamic>);
      }

      // Multi-tenant: if this user is an admin without a turfId, try to find
      // a turf where adminPhone == user.phone and link it.
      if (resolvedUser.role == UserRole.admin &&
          (resolvedUser.turfId == null || resolvedUser.turfId!.isEmpty) &&
          resolvedUser.phoneNumber != null) {
        final turfMatch = await _findTurfForPhone(resolvedUser.phoneNumber!);
        if (turfMatch != null) {
          debugPrint(
              '🏟️ Linking admin ${resolvedUser.uid} to turf ${turfMatch.$1} (${turfMatch.$2})');
          await userDoc.update({
            'turfId': turfMatch.$1,
            'turfName': turfMatch.$2,
          });
          resolvedUser = resolvedUser.copyWith(
            turfId: turfMatch.$1,
            turfName: turfMatch.$2,
          );
        }
      }

      return resolvedUser;
    } catch (e) {
      debugPrint('❌ saveUserToFirestore ERROR: $e');
      throw ServerException('Failed to save user: ${e.toString()}');
    }
  }

  /// Look up a turf where adminPhone matches the given phone.
  /// Returns (turfId, turfName) or null.
  Future<(String, String)?> _findTurfForPhone(String phone) async {
    try {
      final snapshot = await _firestore
          .collection('turfs')
          .where('adminPhone', isEqualTo: phone)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      final data = doc.data();
      return (doc.id, data['name'] as String);
    } catch (e) {
      debugPrint('⚠️ _findTurfForPhone failed: $e');
      return null;
    }
  }

  String _mapAuthErrorToMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'The phone number is invalid';
      case 'too-many-requests':
        return 'Too many requests. Please try again later';
      case 'operation-not-allowed':
        return 'Phone authentication is not enabled';
      case 'invalid-verification-code':
        return 'Invalid OTP code';
      case 'invalid-verification-id':
        return 'Invalid verification. Please request a new code';
      case 'session-expired':
        return 'Session expired. Please request a new code';
      default:
        return e.message ?? 'An error occurred';
    }
  }
}
