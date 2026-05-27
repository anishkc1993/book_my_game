import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/turf_entity.dart';
import '../../domain/repositories/turf_repository.dart';

enum TurfListState { initial, loading, loaded, error }

class TurfProvider extends ChangeNotifier {
  final TurfRepository _repository;
  final FirebaseFirestore _firestore;

  TurfProvider({
    required TurfRepository repository,
    FirebaseFirestore? firestore,
  })  : _repository = repository,
        _firestore = firestore ?? FirebaseFirestore.instance;

  List<TurfEntity> _turfs = [];
  List<TurfEntity> get turfs => _turfs;

  TurfListState _state = TurfListState.initial;
  TurfListState get state => _state;

  String? _error;
  String? get error => _error;

  bool _saving = false;
  bool get saving => _saving;

  Future<void> loadActiveTurfs() async {
    _state = TurfListState.loading;
    _error = null;
    notifyListeners();
    try {
      _turfs = await _repository.listActiveTurfs();
      _state = TurfListState.loaded;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _state = TurfListState.error;
    }
    notifyListeners();
  }

  // ── Current turf (for the venue location screen) ─────────────────────────
  TurfEntity? _currentTurf;
  TurfEntity? get currentTurf => _currentTurf;

  bool _currentTurfLoading = false;
  bool get currentTurfLoading => _currentTurfLoading;

  Future<void> loadTurf(String turfId) async {
    _currentTurfLoading = true;
    notifyListeners();
    try {
      _currentTurf = await _repository.getTurf(turfId);
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _currentTurfLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveVenueDetails({
    required String turfId,
    String? venueName,
    String? street,
    String? cityArea,
    String? landmark,
    double? latitude,
    double? longitude,
    String? shareSlug,
  }) async {
    _saving = true;
    notifyListeners();
    try {
      await _repository.updateVenueDetails(
        turfId: turfId,
        venueName: venueName,
        street: street,
        cityArea: cityArea,
        landmark: landmark,
        latitude: latitude,
        longitude: longitude,
        shareSlug: shareSlug,
      );
      // Refresh local copy.
      _currentTurf = _currentTurf?.copyWith(
        venueName: venueName,
        street: street,
        cityArea: cityArea,
        landmark: landmark,
        latitude: latitude,
        longitude: longitude,
        shareSlug: shareSlug,
      );
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// Set the current user's selected turf (writes to users/{uid}).
  Future<bool> selectTurfForUser(String uid, TurfEntity turf) async {
    _saving = true;
    notifyListeners();
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .update({
        'turfId': turf.id,
        'turfName': turf.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}
